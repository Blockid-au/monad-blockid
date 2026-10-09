#!/usr/bin/env bash
# Point monad.blockid.au at this VM on Cloudflare (proxied, same as eth.blockid.au), then issue the TLS cert.
# Token: CF_API_TOKEN in /etc/cf-ddns.env (needs Zone:DNS:Edit on blockid.au). Never printed.
# Waits (up to WAIT_MIN minutes) until the token is filled in, so it can run before the owner pastes it.
set -euo pipefail

ENV_FILE="${ENV_FILE:-/etc/cf-ddns.env}"
NAME="${NAME:-monad.blockid.au}"
WAIT_MIN="${WAIT_MIN:-360}"
API=https://api.cloudflare.com/client/v4

token_ok() {
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  [[ -n ${CF_API_TOKEN:-} && $CF_API_TOKEN != DAN_* ]] || return 1
  curl -fsS -H "Authorization: Bearer $CF_API_TOKEN" "$API/user/tokens/verify" | jq -e '.success' >/dev/null 2>&1
}

certify() {
  for ((j = 0; j < 40; j++)); do
    [[ -n $(dig +short "$NAME" @1.1.1.1) ]] && break
    sleep 15
  done
  certbot --nginx -d "$NAME" --non-interactive --agree-tos --redirect 2>&1 | tail -3
  echo "https status: $(curl -s -o /dev/null -w '%{http_code}' "https://$NAME/")"
}

# either a valid token appears (we create the record) or the owner adds the record by hand (we only certify)
for ((i = 0; i < WAIT_MIN * 2; i++)); do
  token_ok && break
  if [[ -n $(dig +short "$NAME" @1.1.1.1) ]]; then echo "DNS for $NAME added by hand"; certify; exit 0; fi
  sleep 30
done
token_ok || { echo "no valid CF_API_TOKEN in $ENV_FILE and no DNS record after $WAIT_MIN min"; exit 1; }
AUTH=(-H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json")

ZONE_ID=$(curl -fsS "${AUTH[@]}" "$API/zones?name=${CF_ZONE_NAME:-blockid.au}" | jq -r '.result[0].id')
[[ -n $ZONE_ID && $ZONE_ID != null ]] || { echo "zone not found (token lacks Zone:Read?)"; exit 1; }

# same target and proxy mode as the eth record
REF=$(curl -fsS "${AUTH[@]}" "$API/zones/$ZONE_ID/dns_records?type=A&name=eth.blockid.au" | jq '.result[0]')
IP=$(jq -r '.content // empty' <<<"$REF")
[[ -n $IP ]] || IP=$(curl -fsS -m 5 -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
PROXIED=$(jq -r '.proxied // true' <<<"$REF")

REC_ID=$(curl -fsS "${AUTH[@]}" "$API/zones/$ZONE_ID/dns_records?type=A&name=$NAME" | jq -r '.result[0].id // empty')
BODY=$(jq -n --arg n "$NAME" --arg c "$IP" --argjson p "$PROXIED" '{type:"A",name:$n,content:$c,ttl:1,proxied:$p}')
if [[ -n $REC_ID ]]; then
  curl -fsS -X PUT "${AUTH[@]}" "$API/zones/$ZONE_ID/dns_records/$REC_ID" --data "$BODY" | jq -e '.success' >/dev/null
else
  curl -fsS -X POST "${AUTH[@]}" "$API/zones/$ZONE_ID/dns_records" --data "$BODY" | jq -e '.success' >/dev/null
fi
echo "DNS: $NAME -> $IP (proxied=$PROXIED)"

certify
