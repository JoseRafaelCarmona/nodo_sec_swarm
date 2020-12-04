#! /bin/bash

function validacion(){
    if [ $1 != "0" ]; then
        echo "-->Mal";
        exit 1;
    fi
        echo '   OK';
}

function validarParams(){
    [[ ! $# -eq 2 ]] && { echo "Tu número de parámetros no es el correcto"; modoUso; exit 1; }
    comprobar_ping $1
    validar_punto_montaje $2
}

function modoUso(){
    echo 'Para ejecutar el script: nodo.sh IP-MANAGER PUNTO-MONTAJE'
    echo 'Ejemplo: ./nodo.sh 192.168.1.1 /dev/sda1'
}

function usuario_root(){
    if [ $EUID -eq 0 ]; then
        echo '   OK';
    else
        echo '   ERROR: Debes ser el usuario root';
        exit 1;
    fi
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

ip_master=$1
punto_montaje=$2
interface=$3

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
echo '-->Instalando keepalived'
chmod -R +x keepalived/
cd keepalived/ && bash ./install_keepalived.sh "$ip_master" "$interface"
echo "-->listo"