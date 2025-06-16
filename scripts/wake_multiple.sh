#!/bin/sh

# ==================== CONFIGURACIÓN ====================
BROADCAST="192.168.255.255"
MACS_FILE="/usr/local/etc/wake_macs.txt"
BOT_TOKEN="TU_TOKEN"
CHAT_ID_1="TU_CODIGO1"   # Tecnico1
CHAT_ID_2="TU_CODIGO2"   # Tecnico2
FERIADO_API="https://date.nager.at/api/v3/PublicHolidays/$(date +%Y)/CL"
# =======================================================

hoy=$(date +%Y-%m-%d)

enviar_mensaje() {
    local MENSAJE="$1"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID_1" -d text="$MENSAJE" >/dev/null
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID_2" -d text="$MENSAJE" >/dev/null
}

# Verificar si hoy es feriado en Chile
es_feriado=$(curl -s "$FERIADO_API" | grep -c "\"date\":\"$hoy\"")

if [ "$es_feriado" -gt 0 ]; then
    mensaje="🚫 Hoy $hoy es feriado en Chile. Los PCs **NO** fueron encendidos. Verifique si corresponde."
    enviar_mensaje "$mensaje"
    exit 0
fi

enviar_mensaje "⚡ Encendiendo PCs del laboratorio. Fecha: $hoy"

# Encender todos los PCs (enviar paquetes WoL)
while IFS= read -r linea; do
    if [ -z "$linea" ] || echo "$linea" | grep -q "^#"; then
        continue
    fi

    MAC=$(echo "$linea" | cut -f1)
    wol -i $BROADCAST "$MAC"
done < "$MACS_FILE"

# Esperar 60 segundos antes de verificar
sleep 60

# Verificar si las IPs responden al ping
no_respondieron=""
while IFS= read -r linea; do
    if [ -z "$linea" ] || echo "$linea" | grep -q "^#"; then
        continue
    fi

    IP=$(echo "$linea" | grep -oE "#[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)" | awk '{print $2}')
    if [ -n "$IP" ]; then
        ping -c 1 -W 2 "$IP" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            no_respondieron="${no_respondieron}- $IP\n"
        fi
    fi
done < "$MACS_FILE"

# Enviar resultados
if [ -n "$no_respondieron" ]; then
    mensaje="⚠️ PCs que **NO** respondieron al encendido (posiblemente apagados):\n$no_respondieron"
else
    mensaje="✅ Todos los equipos respondieron correctamente al encendido."
fi

enviar_mensaje "$mensaje"
