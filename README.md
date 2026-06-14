# E-WPS

**The easiest way to crack WPS** wrapper Bash attorno a `wash` / `reaver` / `airodump-ng` per il testing del WPS su reti **proprie**.

> ⚠️ **Uso consentito SOLO su reti di tua proprietà o per cui hai un'autorizzazione
> scritta del proprietario.** L'accesso non autorizzato a reti altrui è un reato
> (in Italia art. 615-ter c.p. e normativa correlata). Lo strumento è pensato per
> auditing difensivo e scopi didattici.

---

## Contesto storico e stato della vulnerabilità

E-WPS nasce nel **2015**, all'epoca d'oro degli attacchi al WPS:

- **WPS PIN brute-force** (Stefan Viehböck, 2011): il PIN a 8 cifre viene validato
  in due metà da 4+3 cifre (+1 checksum), riducendo lo spazio di ricerca da 10^8 a
  ~11.000 tentativi. `reaver` automatizza questo attacco online.
- **Pixie Dust** (Dominique Bongard, 2014): attacco *offline* che sfrutta la scarsa
  entropia dei nonce E-S1/E-S2 in alcuni chipset (Ralink, Broadcom, Realtek),
  recuperando il PIN in pochi secondi da un singolo handshake (`reaver -K 1`).

**Oggi (2026) la finestra è in gran parte chiusa.** I router moderni mitigano o
eliminano entrambi gli attacchi:

- **AP lockout / rate-limiting**: dopo pochi PIN errati il WPS si blocca
  temporaneamente (in `airodump-ng --wps` compare lo stato `Locked`), rendendo il
  brute-force online impraticabile.
- **Entropia corretta**: i chipset vulnerabili a Pixie Dust hanno ricevuto firmware
  con nonce generati correttamente.
- **WPS disabilitato di default** o rimosso del tutto su molti modelli recenti.
- **WPA3 / SAE**, che non prevede il PIN WPS.

In pratica E-WPS resta utile per **verificare che il proprio AP non sia esposto**
(molti dispositivi IoT economici lo sono ancora), ma su un router moderno e
aggiornato l'attacco fallisce: è il risultato atteso, non un bug dello strumento.

---

## Il refactor (2015 → 2026)

La versione originale era scritta per Kali/Backtrack dell'epoca e oggi non parte più
su distro recenti (es. Fedora). Il refactor sistema compatibilità, robustezza e
affidabilità dello scan, mantenendo identico il flusso d'uso.

| Area | Versione 2015 | Versione 2026 |
|------|---------------|---------------|
| Rilevamento interfacce | `ifconfig \| grep wl` (deprecato/assente) | `iw dev` |
| Modalità monitor | `iwconfig … mode monitor` (deprecato/assente) | `iw dev … set type monitor` |
| Lettura stato/mode | `iwconfig` | `iw dev … info` |
| Check root | `if [ “$(id -u)” … ]` con **virgolette tipografiche** | `if [ "$(id -u)" … ]` ASCII corretto |
| Dipendenze | nessun controllo | check di `iw`, `ip`, `wash`, `reaver` + opzionali |
| Scan reti | `wash -i` → su driver come `ath9k_htc` resta **fermo su un canale** | `airodump-ng --wps` (channel hopping affidabile, colonna WPS/Locked) con fallback `wash -i … -C` (ignora FCS) |
| Processi interferenti | nessuna gestione | `kill_interfering`: `airmon-ng check kill` se presente, altrimenti `nmcli dev set … managed no` + `systemctl stop wpa_supplicant` |
| Validazione input | nessuna | regex su BSSID e canale |
| Uscita rapida | solo a fine ciclo | `exit` accettato anche al prompt del MAC |
| Qualità codice | `tput` ripetuti, variabili non quotate, `read` senza `-r` | helper colore, quoting, `read -r`, funzioni dedicate |
| Cambio MAC | inline | due varianti dedicate (vedi sotto) |

### Perché `airodump-ng --wps` al posto di `wash`

Il sintomo tipico — lista vuota o ferma su un solo canale pur essendoci reti WPS —
ha due cause combinate sugli adattatori Atheros USB (`ath9k_htc`):

1. **FCS**: il radiotap include il Frame Check Sequence e `wash` scarta i frame
   ritenendoli corrotti → `wash -C` (`--ignore-fcs`) lo risolve.
2. **Channel hopping inaffidabile** di `wash` su alcuni driver. `airodump-ng` hoppa
   in autonomia su tutti i canali 2.4 GHz e mostra versione WPS e stato `Locked`.

Per questo lo scanner predefinito è ora `airodump-ng --wps`, con `wash -C` come
fallback quando `aircrack-ng` non è installato.

---

## Requisiti

Obbligatori: `iw`, `ip` (iproute2), `wash` e `reaver` (pacchetto `reaver`).
Consigliati: `aircrack-ng` (fornisce `airodump-ng` e `airmon-ng`).
Opzionale: `macchanger` (solo per la variante con cambio MAC).

Esempio su Fedora:

```bash
sudo dnf install reaver aircrack-ng macchanger iw iproute
```

---

## Utilizzo

```bash
sudo ./e-wps.sh
```

Lo script:

1. elenca le interfacce WiFi e chiede quale usare (default `wlan0`);
2. (opzionale) libera l'interfaccia dai processi che la resettano;
3. attiva la modalità monitor;
4. avvia lo scan WPS (`airodump-ng --wps`); premi **Ctrl-C** per fermarlo;
5. chiede BSSID e canale del target e lancia `reaver -K 1` (Pixie Dust);
6. salva l'output in `CrackedWifi/<BSSID>` e ricomincia.

Al prompt del MAC scrivi `exit` per uscire.

### Varianti

| Script | Comportamento MAC |
|--------|-------------------|
| `e-wps.sh` | randomizza il MAC all'attivazione del monitor (richiede `macchanger`) |
| `e-wpsnomacchange.sh` | non modifica mai il MAC |

---

## License

Questo progetto è rilasciato sotto licenza **GNU General Public License v3.0
(GPL-3.0)**. Sei libero di usarlo, studiarlo, modificarlo e ridistribuirlo nei
termini della licenza. Il programma è fornito SENZA ALCUNA GARANZIA. Vedi il file
[`LICENSE`](LICENSE) o <https://www.gnu.org/licenses/gpl-3.0.html>.

## Author

[https://github.com/Leproide](https://github.com/Leproide)
