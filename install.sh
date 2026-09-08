#!/bin/bash

# Controllo preventivo dei permessi di root
if [ "$EUID" -ne 0 ]; then
    echo "Errore: Esegui questo script usando sudo (es. sudo ./install.sh)"
    exit 1
fi

# Funzione per disegnare la barra data una percentuale reale (0-100)
disegna_barra() {
    local percentuale=$1
    local messaggio=$2
    local larghezza_max=20

    # Calcola quanti cancelletti corrispondono alla percentuale corrente
    local num_cancelletti=$(( percentuale * larghezza_max / 100 ))
    local spazi=$(( larghezza_max - num_cancelletti ))

    # Righe conformi a ShellCheck (SC2155)
    local barra_piena
    local barra_vuota
    barra_piena=$(printf "%${num_cancelletti}s" | tr ' ' '#')
    barra_vuota=$(printf "%${spazi}s" | tr ' ' ' ')

    # Stampa la stringa formattata con la percentuale vicina alla chiusura del blocco ]
    printf "\r%s [%s%s] %3d%%" "$messaggio" "$barra_piena" "$barra_vuota" "$percentuale"
}

echo "Installing the application..."

# Eseguiamo prima apt update nascondendone l'output (operazione preliminare veloce)
printf "Aggiornamento dei repository in corso..."
apt update > /dev/null 2>&1
printf "\rAggiornamento dei repository in corso... Fatto!\n"

# 1. Installazione dei pacchetti con analisi della percentuale reale
# Utilizziamo un descrittore di file per leggere riga per riga l'avanzamento di apt-get
# Nasconde il cursore del terminale
tput civis

messaggio_installazione="Download e installazione pacchetti"
disegna_barra 0 "$messaggio_installazione"

# Avvia l'installazione catturando lo stato del pacchetto
# Il comando 'stdbuf' garantisce che i dati vengano trasmessi immediatamente senza ritardi
while read -r linea; do
    # Cerca la stringa 'status: ' o 'dlstatus: ' generata da apt-get che contiene la percentuale
    if [[ "$linea" =~ status:.*:[[:space:]]*([0-9]+)\.[0-9]+: ]]; then
        perc="${BASH_REMATCH[1]}"
        disegna_barra "$perc" "$messaggio_installazione"
    elif [[ "$linea" =~ dlstatus:[0-9]+:([0-9]+\.[0-9]+): ]]; then
        # Gestisce la percentuale durante la fase di puro download dei singoli pacchetti
        # Converte il float in intero arrotondato per difetto
        perc_dl=$(echo "${BASH_REMATCH[1]}" | cut -d. -f1)
        # Il download rappresenta solo la prima parte, scaliamo la percentuale (es. max 40% del totale)
        perc=$(( perc_dl * 40 / 100 ))
        disegna_barra "$perc" "$messaggio_installazione"
    fi
done < <(stdbuf -oL apt-get install -y --log-status build-essential cmake libssl-dev \
          libcurl4-openssl-dev libjsoncpp-dev libboost-all-dev g++ git 2>/dev/null)

# Forza il completamento visivo al 100% una volta terminato il ciclo
disegna_barra 100 "$messaggio_installazione"
echo "" # Va a capo dopo la prima installazione


# 2. Configurazione comando di sistema (operazione quasi istantanea)
messaggio_mv="Configurazione comando di sistema  "
disegna_barra 0 "$messaggio_mv"
sleep 0.3

mv src/compile /usr/local/bin/ > /dev/null 2>&1

disegna_barra 100 "$messaggio_mv"
echo "" # Va a capo

# Ripristina il cursore del terminale
tput cnorm

echo "Installation complete!"