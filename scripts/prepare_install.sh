#!/bin/bash
TMPDIR="/var/tmp"
TFTPSRV="nucmgmt.home.taurus"
TFTPPATH="/srv/tftp"
localdata="cat ${HOME}/.local/.secret"
if [[ $# -ne 2 ]]; then
  echo "This script needs two arguments:"
  echo "$0 <hostname> <IP address>"
  echo "Please try again"
  exit 9
else
  srvname="$1"
  srvip="$2"
fi
postinst_file="${srvname}.postinst.sh"
cat >> ${TMPDIR}/${postinst_file} <<EOF
IP="${srvip}"
NM="255.255.255.0"
GW="192.168.1.1"
NS="192.168.1.6"
#NIC=$(/bin/nmcli dev | grep ethernet | awk '{print $1}')
NIC=$(/sbin/ip li sh | grep 'state UP' | head -1 | awk '{print $2}' | sed -e 's/://')
echo -e "auto lo ${NIC} \niface lo inet loopback\n\niface ${NIC} inet static\n\t address ${IP}\n\t netmask ${NM}\n\t gateway ${GW}\n\t dns-nameservers ${NS}" > /etc/network/interfaces
echo "${srvname}.home.taurus" > /etc/hostname

EOF

scp ${TMPDIR}/${postinst_file} ${TFTPSRV}:${TMPDIR}/${postinst_file}
ssh ${TFTPSRV} "sudo mv ${TMPDIR}/${postinst_file} ${TFTPPATH}/; sudo chown root:root ${TFTPPATH}/${postinst_file}; sudo chmod 755 ${TFTPPATH}/${postinst_file}; sudo ln -s ${TFTPPATH}/${postinst_file} ${TFTPPATH}/debian_postinst.sh"
ssh ${TFTPSRV} "/usr/bin/samba-tool dns add ${TFTPSRV} home.taurus ${srvname} A ${srvip} -U pstoopsadm --password \"${localdata}\""
oct4=$(echo ${IP} | tr "." " " | awk '{ print $4 }')
ssh ${TFTPSRV} "/usr/bin/samba-tool dns add ${TFTPSRV} 1.168.192.in-addr.arpa ${oct4} PTR ${srvname}.home.taurus -U pstoopsadm --password \"${localdata}\""