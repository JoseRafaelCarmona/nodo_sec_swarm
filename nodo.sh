#! /bin/bash

function validacion(){
    if [ $1 != "0" ]; then
        echo "-->Mal";
        exit 1;
    fi
        echo '   OK';
}

function validarParams(){
    [[ ! $# -eq 3 ]] && { echo "Tu número de parámetros no es el correcto"; modoUso; exit 1; }
    validar_punto_montaje $2
    validar_interface $3
}

function modoUso(){
    echo 'Para ejecutar el script: nodo.sh IP-MANAGER PUNTO-MONTAJE NUMERODE-NODO'
    echo 'Ejemplo: ./nodo.sh 192.168.1.1 /dev/sda1 2'
}

function usuario_root(){
    if [ $EUID -eq 0 ]; then
        echo '   OK';
    else
        echo '   ERROR: Debes ser el usuario root';
        exit 1;
    fi
}

function validar_interface(){
  ip add | grep -wom 1 $1
  validacion "$(echo $?)"
}

function validar_punto_montaje(){
    echo '-->Comprobando punto de montaje'
    fdisk -l | grep -w $1
    validacion $(echo $?)
}

function validar_os(){
    hostnamectl | grep -w Arch
    validacion $(echo $?)
}

function acceso_internet(){
    curl www.google.com >/dev/null 2>&1
    validacion $(echo $?)
}

function validar_docker(){
    docker --version > /dev/null
    validacion $(echo $?)
}

function permitir_root_login(){
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    systemctl restart sshd
    echo '   OK'
}

function conectarse_swarm(){
    DOCKER_SWARM=$(ssh root@$1 cat /root/.key_swarm)
    $DOCKER_SWARM
    echo '   OK'
}


function install_keepalived(){
         docker run -d --name keepalived --restart=always \
              --cap-add=NET_ADMIN --cap-add=NET_BROADCAST --cap-add=NET_RAW --net=host \
              -e KEEPALIVED_INTERFACE=$4 \
              -e KEEPALIVED_UNICAST_PEERS="#PYTHON2BASH:[$1,$2]" \
              -e KEEPALIVED_VIRTUAL_IPS=$3 \
              -e KEEPALIVED_PRIORITY=100 \
              osixia/keepalived
}

function keepalived(){
        IP_VIRTUAL=$(ssh root@$1 cat /root/.ip_virtual)
        IP_NODO=$(ssh root@$1 cat /root/.ip_nodo)
        install_keepalived $1 $IP_NODO $IP_VIRTUAL $2
}

ip_master=$1
punto_montaje=$2
interface=$3
nodo=$4

validarParams "$@"
echo '-->Comprobando si eres usuario root:'
usuario_root
echo '-->Comprobando sistema operativo'
validar_os
echo '-->Acceso a internet'
acceso_internet
echo '-->Comprobando docker'
validar_docker
echo '-->Permitir login ssh root'
permitir_root_login
echo '-->Conectanose a swarm'
conectarse_swarm $1
echo 'Iniciando la instalacion de ceph..'
chmod +x ceph/install_ceph.sh
chmod -R +x ceph/
cd ceph/ && bash ./install_ceph.sh "$ip_master" "$punto_montaje"
if [[ $nodo -eq 2 ]]; then
    echo '-->Instalando keepalived'
    keepalived "$ip_master" "$interface"
    echo "-->listo"
fi
