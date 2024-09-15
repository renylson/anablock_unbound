#!/bin/bash
ANABLOCK_URL="https://api.anablock.net.br/domains/all?output=unbound"
ANABLOCK_FILE="/etc/unbound/anablock.conf"
REDIRECT_DOMAIN="anatel.infonetconect.com.br."
LOG_FILE="/var/log/unbound_anablock_update.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log "Iniciando atualização do anablock.conf..."

curl -s "$ANABLOCK_URL" -o "$ANABLOCK_FILE"
if [ $? -ne 0 ]; then
    log "Erro ao baixar o arquivo anablock.conf"
    exit 1
fi

log "Arquivo anablock.conf baixado com sucesso."

sed -i -r \
    -e 's/local-zone: "([^"]+)" always_nxdomain/local-zone: "\1" redirect/' \
    -e 's/^local-zone: "([^"]+)".*/&\nlocal-data: "\1 CNAME '"$REDIRECT_DOMAIN"'"/' \
    "$ANABLOCK_FILE"

if [ $? -eq 0 ]; then
    log "Configuração de redirecionamento aplicada com sucesso."
else
    log "Erro ao modificar o arquivo de configuração."
    exit 1
fi

systemctl restart unbound
if [ $? -eq 0 ]; then
    log "Unbound reiniciado com sucesso."
else
    log "Erro ao reiniciar o Unbound."
    exit 1
fi

log "Atualização concluída com sucesso."
