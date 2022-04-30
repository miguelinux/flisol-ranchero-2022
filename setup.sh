#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# SPDX-License-Identifier: GPL-3.0-or-later

ALUMNOS_CSV=""

die ()
{
    >&2 echo -e "${*}"
    exit 1
}

while [ -n "${1}" ]
do
    case "$1" in
        -d|--debug)
            set -x
        ;;
        -e|--error)
            set -e
        ;;
        *)
            ALUMNOS_CSV=$1
        ;;
    esac
    shift
done

if [ -z "${ALUMNOS_CSV}" ]
then
    die "No se proporcionó un archivo de alumnos"
fi

if [ ! -f "${ALUMNOS_CSV}" ]
then
    die "El archivo ${ALUMNOS_CSV} no existe"
fi

rm -rf wireguard/*
rm -f  wireguard/.server/peers.conf

num=101

while IFS= read -r alumno
do
    #passwd=$(echo ${alumno} | cut -f 3 -d " ")
    correo=$(echo ${alumno} | cut -f 2 -d ,)
    #HASH=$(echo ${correo} | sha256sum | cut -f 1 -d " ")
    HASH=${correo}
    dir_alum=wireguard/${HASH}
    archivo=wireguard/${HASH}/wg0.conf

    mkdir ${dir_alum}
    umask 077
    wg genkey | tee ${dir_alum}/privatekey | wg pubkey > ${dir_alum}/publickey

    prikey=$(< ${dir_alum}/privatekey)
    pubkey=$(< ${dir_alum}/publickey)
    serkey=$(< wireguard/.server/server.key.pub)
    ip=$(< wireguard/.server/ip)

    echo "[Interface]"             > ${archivo}
    echo "Address = 192.168.2.${num}/24" >> ${archivo}
    echo "PrivateKey = ${prikey}" >> ${archivo}
    echo "ListenPort = 51820"     >> ${archivo}
    echo "# PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE" >> ${archivo}
    echo "# PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE" >> ${archivo}
    echo ""                       >> ${archivo}
    echo "# Servidor Amazon"      >> ${archivo}
    echo "[Peer]"                 >> ${archivo}
    echo "PublicKey = ${serkey}"  >> ${archivo}
    echo "Endpoint = ${ip}:51820"      >> ${archivo}
    echo "AllowedIPs = 192.168.2.0/24" >> ${archivo}
    echo "PersistentKeepalive = 25"    >> ${archivo}

    echo ""                       >> wireguard/.server/peers.conf
    echo "# ${correo}"            >> wireguard/.server/peers.conf
    echo "[Peer]"                 >> wireguard/.server/peers.conf
    echo "PublicKey = ${pubkey}"  >> wireguard/.server/peers.conf
    echo "AllowedIPs = 192.168.2.${num}/32" >> wireguard/.server/peers.conf

    let "num=num+1"
    #gpg --symmetric --batch --yes --passphrase ${passwd} ${archivo}
    #gpg --symmetric --batch --yes --passphrase ${passwd} ${dir_alum}/privatekey
    #gpg --symmetric --batch --yes --passphrase ${passwd} ${dir_alum}/publickey

    #rm ${dir_alum}/privatekey ${dir_alum}/publickey
done < "${ALUMNOS_CSV}"

