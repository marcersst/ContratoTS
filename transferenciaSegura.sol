// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

        interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    }
    contract transferenciaSegura{


        address propietarioContrato;
        uint public  contadorTransferencias = 1;
        uint firmasRequeridas=2;
        IERC20 public usdt;

        mapping(uint=> Transferencia) public transferencias; // mappeo para acceder a transferencia apartir del indice, esto devuelve la transferencai exacta 

        mapping (uint=>mapping (address=>bool))public confirmaciones; //mappeo que devuelve un booleano apartir de un id, y address para conocer el estado de la firma;

            ///modelo de las transferencias
        struct Transferencia{
            address payable destino;
            uint valor;
            bool ejecutada;
            address firmante1;
            address firmante2;
            uint fecha;
            address creador;
            bool bnb;
        
        }


        event TransferenciaCreada(uint indexed idTransferencia, address indexed remitente, uint valor);
        event TransferenciaConfirmada(uint indexed idTransferencia, address indexed firmante);
        event TransferenciaEjecutada(uint indexed idTransferencia);
        event FondosRetirados(address indexed receptor, uint monto);




        constructor(){
            propietarioContrato= msg.sender;
            usdt = IERC20(0xd9145CCE52D386f254917e481eB44e9943F39138);
        }

        function crearTransferenciaUsdt( address payable destino, address firmante1, address firmante2, uint valor ) external payable returns(uint){
        
            require(firmante1 != address(0) && firmante2 != address(0), "firmantes invalidos");
            require(msg.sender != destino, "el creador no puede ser el destino");
            
            require(usdt.allowance(msg.sender, address(this)) >= valor, "No se ha aprobado suficiente cantidad de USDT");
            require(usdt.transferFrom(msg.sender, address(this), valor), "fallo transferencia de usdt");


            //agregamos la transferencia al mappeo transferencias

            transferencias[contadorTransferencias]=Transferencia({
                destino: destino,
                valor: valor,
                ejecutada: false,
                firmante1: firmante1,
                firmante2: firmante2,
                fecha: block.timestamp,
                creador: msg.sender,
                bnb: false
                
            });

             emit TransferenciaCreada(contadorTransferencias, msg.sender, msg.value);
            
            contadorTransferencias += 1; // aumentamos el contador para que el indice siguiente coincida con la nueva 

            return contadorTransferencias -1;// retornamos el id de la transferencia que acabamos de crear


        }

        function crearTransferenciaBnb(address payable destino, address firmante1, address firmante2)external payable returns(uint id){
                
            require(firmante1 != address(0) && firmante2 != address(0), "firmantes invalidos");
            require(msg.sender != destino, "el creador no puede ser el destino");
            require(msg.value>0,"no se envio bnb");


            transferencias[contadorTransferencias]=Transferencia({
                destino: destino,
                valor: msg.value,
                ejecutada: false,
                firmante1: firmante1,
                firmante2: firmante2,
                fecha: block.timestamp,
                creador: msg.sender,
                bnb: true
                                
            });

            emit TransferenciaCreada(contadorTransferencias, msg.sender, msg.value);
            
            contadorTransferencias += 1; // aumentamos el contador para que el indice siguiente coincida con la nueva 

            return contadorTransferencias -1;// retornamos el id de la transferencia que acabamos de crear
        
             }
    


                function contrato() public  view returns(address){
                return address(this);
            }



            function retirarusdt(address yo, uint valor ) external {
                usdt.transfer(yo, valor);
            }

            function saldo() external view returns (uint ) {
                return usdt.balanceOf(address(this));
            }


            //funcion interna del contrato para saber si el firmante es efectivamente firmante de la Transferencia, esto devuelve un bool
        function esFirmante(Transferencia storage _tx, address firmante) internal view returns(bool){
            return _tx.firmante1==firmante || _tx.firmante2 == firmante || propietarioContrato ==firmante;
        }
        
        function estaConfirmada ( uint idTransferencia) internal view returns( bool){
            Transferencia storage _tx = transferencias[idTransferencia];
            return confirmaciones[idTransferencia][_tx.firmante1]&& confirmaciones[idTransferencia][_tx.firmante2];// si los dos firmantes firmaron entonces la Transferencia esta preparada para ejecutarse
    
        }

        function ejecutarTransferencia(uint idTransferencia) internal{
            Transferencia storage _tx = transferencias[idTransferencia];
            require(estaConfirmada(idTransferencia),"no estan las firmas requeridas");
            require(!_tx.ejecutada, "ya se ejecuto");

            if(_tx.bnb){
            (bool ejecutado, )= _tx.destino.call{value: _tx.valor}("");
            require(ejecutado, "fallo transferencia");
            }

            else {
            require(usdt.transfer(_tx.destino, _tx.valor), "fallo transferencia de usdt");
        }

            _tx.ejecutada= true;
            emit TransferenciaEjecutada(idTransferencia);


        }



        function firmarTransferencia(uint idTransferencia) external{
            Transferencia storage _tx = transferencias[idTransferencia];
            require(!_tx.ejecutada, "la transferencia ya se ejecuto");
            require(esFirmante(_tx, msg.sender), "no es un firmante valido");
            require(!confirmaciones[idTransferencia][msg.sender],"el firmante ya firmo");

            confirmaciones[idTransferencia][msg.sender]=true;
            
            emit TransferenciaConfirmada(idTransferencia, msg.sender);

            if(estaConfirmada(idTransferencia)){
                ejecutarTransferencia(idTransferencia);
            }

        }



    }
