// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract transferenciasegura {
    using SafeERC20 for IERC20;

    address propietarioContrato;
    uint public contadorTransferencias = 1;
    uint firmasRequeridas = 2;
    IERC20 usdt = IERC20(0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0);
    bool estadoDePrueba = true;
    uint comisionesenUsdt;
    uint comisionesEnBnB;
    uint minimoEnBnb = 0.12 ether;
    
    mapping(uint => Transferencia) public transferencias;
    mapping(uint => mapping(address => bool)) public confirmaciones;

    struct Transferencia {
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

    constructor() {
        propietarioContrato = msg.sender;
    }

    function crearTransferenciaUsdt(address payable destino, address firmante1, address firmante2, uint valor) external payable returns(uint) {
        require(valor > 50, "el valor tiene que ser mayor a 50");
        require(firmante1 != address(0) && firmante2 != address(0), "firmantes invalidos");
        require(msg.sender != destino, "el creador no puede ser el destino");


        usdt.safeTransferFrom(msg.sender, address(this), valor);

        transferencias[contadorTransferencias] = Transferencia({
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
        
        contadorTransferencias += 1;

        return contadorTransferencias - 1;
    }

        function cambiarMinimo(uint minimo)external{
            require(msg.sender==propietarioContrato);
            minimoEnBnb=minimo;
        }


        function crearTransferenciaBnb(address payable destino, address firmante1, address firmante2)external payable returns(uint id){
                
            require(firmante1 != address(0) && firmante2 != address(0), "firmantes invalidos");
            require(msg.sender != destino, "el creador no puede ser el destino");
            require(msg.value>minimoEnBnb,"el minomo no se alcanzo");


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

            uint tarifa= (_tx.valor*1)/100;
            uint valorAEnviar= _tx.valor-tarifa;
            


            if(_tx.bnb){
            (bool ejecutado, )= _tx.destino.call{value: valorAEnviar}("");
            require(ejecutado, "fallo transferencia");
            comisionesEnBnB += tarifa;
             _tx.ejecutada= true;
            emit TransferenciaEjecutada(idTransferencia);
            }

            else {



            usdt.safeTransfer(_tx.destino, valorAEnviar);
            comisionesenUsdt+=tarifa;
             _tx.ejecutada= true;
            emit TransferenciaEjecutada(idTransferencia);
        }
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

        function forzarTransferencia (uint idTransferencia) external {
            require(msg.sender==propietarioContrato,"solo el propietario del contrato puede llamar a esta funcion");
            Transferencia storage _tx = transferencias[idTransferencia];

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

        function revertirTransferencia(uint idTransferencia) external{
            require(msg.sender==propietarioContrato,"solo el propietario del contrato puede llamar a esta funcion");

             Transferencia storage _tx = transferencias[idTransferencia];
            
            require(!_tx.ejecutada, "la transferencia ya esta ejecutada");

            if(_tx.bnb){
            (bool ejecutado, )= _tx.creador.call{value: _tx.valor}("");
            require(ejecutado, "fallo transferencia");
            _tx.ejecutada=true;
            }

            else {
            require(usdt.transfer(_tx.creador, _tx.valor), "fallo transferencia de usdt");
            _tx.ejecutada=true;
        }
        }


        function retirarUsdtoBnb(bool bnb ) external {
                require(estadoDePrueba,"ya termino el periodo de prueba, no se puede extraer fondos del contrato");
                require(msg.sender==propietarioContrato," solo el propietario del contrato puede llamar al contrato");
               if(bnb){
                uint balanceBnb= address(this).balance;
                require(balanceBnb>0,"no hay fondos para retirar");
                address payable destino = payable (msg.sender);
                destino.transfer(address(this).balance);
               }
               else{
                uint balanceUsdt = usdt.balanceOf(address(this));
                require(balanceUsdt>1, "no hay fondos para retirar");
                require(usdt.transfer(propietarioContrato, balanceUsdt),"fallo la extraccion de fondos");
               }
            }


        function retirarComisiones(bool bnb) external{
             require(msg.sender==propietarioContrato," solo el propietario del contrato puede llamar al contrato");

               if(bnb){
                require(comisionesEnBnB>0,"no hay comisiones para retirar");
                    (bool ejecutado, )= propietarioContrato.call{value: comisionesEnBnB}("");
                    require(ejecutado, "fallo transferencia");
                    }
               else{
                require(comisionesenUsdt>1, "no hay fondos para retirar");
                require(usdt.transfer(propietarioContrato, comisionesenUsdt),"fallo la extraccion de fondos");
               }

        }
    }
