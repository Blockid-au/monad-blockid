#!/usr/bin/env bash
# End-to-end TESTNET demo on Monad testnet (chain id 10143) — Monad Metropolis 2026, Track 4.
#   1) deployer (issuer service): deploy share register + UpdateAnchor + BatchDividend, KYC + issue shares to N
#      sample holder wallets, record the AI-drafted update (content hash + evidence confidence)        → Proposed
#   2) director (a DIFFERENT, human-held wallet): approve the update on-chain                           → Anchored
#   3) deployer: pay a pro-rata mAUD dividend to every holder in ONE transaction (refuses if not approved)
#   4) publish site/monad-deploy.json for https://monad.blockid.au (addresses, tx hashes, gas used)
# Keys: encrypted Foundry keystores (~/.foundry/keystores/blockid-{deployer,admin}); passwords in ~/.blockid/*.password.
# AI agents never touch these keys. Testnet only. Re-runnable: finished steps are skipped.
# Local dry run: anvil --port 8645 &  then  RPC=http://127.0.0.1:8645 CHAIN_ID=31337 LOCAL_KEYS=1 ANVIL_KEY0=.. ANVIL_KEY1=.. scripts/monad-demo.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/.foundry/bin:$PATH"
RPC="${RPC:-${MONAD_RPC_URL:-https://testnet-rpc.monad.xyz}}"
CHAIN_ID="${CHAIN_ID:-10143}"
EXPLORER="${MONAD_EXPLORER:-https://testnet.monadvision.com}"
KEYS="$HOME/.blockid"
OUT="$ROOT/contracts/deployments/out/monad-passport.json"
TXLOG="$ROOT/contracts/deployments/out/monad-txs.json"
UPDATE="$ROOT/contracts/deployments/params/monad-update.json"
SITE_JSON="$ROOT/site/monad-deploy.json"

if [[ -n ${LOCAL_KEYS:-} ]]; then   # anvil default accounts 0 and 1
  DEP_ARGS=(--private-key "${ANVIL_KEY0:?set ANVIL_KEY0}"); DIR_ARGS=(--private-key "${ANVIL_KEY1:?set ANVIL_KEY1}")
  DIRECTOR=$(cast wallet address "${ANVIL_KEY1}")
  TXLOG="$ROOT/contracts/deployments/out/local-txs.json"
  SITE_JSON="$ROOT/contracts/deployments/out/local-deploy.json"
else
  DEP_ARGS=(--account blockid-deployer --password-file "$KEYS/deployer.password")
  DIR_ARGS=(--account blockid-admin --password-file "$KEYS/admin.password")
  DIRECTOR=$(cat "$KEYS/admin.address")
fi
DEPLOYER=$(cast wallet address "${DEP_ARGS[@]}")

[[ $(cast chain-id --rpc-url "$RPC") == "$CHAIN_ID" ]] || { echo "RPC is not chain $CHAIN_ID"; exit 1; }
echo "== deployer $DEPLOYER balance: $(cast from-wei "$(cast balance "$DEPLOYER" --rpc-url "$RPC")") MON"
UPDATE_HASH=$(cast keccak "$(cat "$UPDATE")")
CONF=$(jq -r .evidence_confidence_bps "$UPDATE")
echo "== update hash (AI-drafted shareholder update): $UPDATE_HASH  confidence ${CONF} bps"
mkdir -p "$(dirname "$OUT")"; [[ -f $TXLOG ]] || echo '{}' > "$TXLOG"
logtx() { jq --arg k "$1" --arg v "$2" '. + {($k): $v}' "$TXLOG" > "$TXLOG.tmp" && mv "$TXLOG.tmp" "$TXLOG"; }
lasttx() { jq -r '[.transactions[] | select(.function != null and (.function | startswith($f)))] | last | .hash // empty' --arg f "$2" "$1"; }
gasof() { cast receipt "$1" gasUsed --rpc-url "$RPC"; }

cd "$ROOT/contracts"
BCAST="broadcast/MonadPassport.s.sol/$CHAIN_ID"
LOG="${TMPDIR:-/tmp}/monad-demo"
if [[ ! -f $OUT || $(jq -r .chainId "$OUT") != "$CHAIN_ID" ]]; then
  echo "== 1) deploy register, UpdateAnchor, BatchDividend; issue shares; record the AI-drafted update"
  forge test --offline >/dev/null && echo "   forge test: ok"
  DIRECTOR="$DIRECTOR" UPDATE_HASH="$UPDATE_HASH" UPDATE_CONFIDENCE_BPS="$CONF" \
    forge script script/MonadPassport.s.sol:MonadPassport --sig "deploy()" --rpc-url "$RPC" --broadcast --slow \
    "${DEP_ARGS[@]}" > "$LOG-deploy.log" 2>&1 || { tail -30 "$LOG-deploy.log"; exit 3; }
  grep -E 'UpdateAnchor|BatchDividend' "$LOG-deploy.log" || true
  logtx propose "$(lasttx "$BCAST/deploy-latest.json" 'propose(')"
else
  echo "== 1) already deployed ($OUT) — skipping"
fi

UA=$(jq -r .updateAnchor "$OUT"); ID=$(jq -r .updateId "$OUT")
if [[ $(cast call "$UA" "verify(uint256,bytes32)(bool)" "$ID" "$UPDATE_HASH" --rpc-url "$RPC") != true ]]; then
  echo "== 2) director $DIRECTOR approves update $ID"
  TX=$(cast send "$UA" "approve(uint256)" "$ID" --rpc-url "$RPC" "${DIR_ARGS[@]}" --json | jq -r .transactionHash)
  logtx approve "$TX"; echo "   tx $TX"
else
  echo "== 2) update $ID already anchored"
fi

BD=$(jq -r .batchDividend "$OUT")
if [[ $(cast call "$BD" "roundCount()(uint256)" --rpc-url "$RPC") == 0 ]]; then
  echo "== 3) one transaction pays every holder (guarded by UpdateAnchor.verify)"
  forge script script/MonadPassport.s.sol:MonadPassport --sig "pay()" --rpc-url "$RPC" --broadcast --slow \
    "${DEP_ARGS[@]}" > "$LOG-pay.log" 2>&1 || { tail -30 "$LOG-pay.log"; exit 4; }
  grep -E 'paid round' "$LOG-pay.log" || true
  logtx distribute "$(lasttx "$BCAST/pay-latest.json" 'distribute(')"
else
  echo "== 3) dividend round already paid"
fi

echo "== 4) publish $SITE_JSON"
DIST_TX=$(jq -r .distribute "$TXLOG")
TOKEN=$(jq -r .payToken "$OUT")
jq -n --slurpfile o "$OUT" --slurpfile t "$TXLOG" --slurpfile u "$UPDATE" \
  --arg exp "$EXPLORER" --arg rpc "$RPC" --arg gasDist "$(gasof "$DIST_TX")" --arg gasApprove "$(gasof "$(jq -r .approve "$TXLOG")")" \
  --arg at "$(date -u +%Y-%m-%dT%H:%MZ)" '
  $o[0] + {explorer: $exp, rpc: $rpc, publishedAt: $at, txs: $t[0], update: $u[0],
           gas: {distribute: ($gasDist|tonumber), approve: ($gasApprove|tonumber)}}' > "$SITE_JSON.tmp"
# per-holder balances after the payout, read from chain
jq -r '.holders[]' "$OUT" | while read -r H; do
  printf '{"account":"%s","shares":%s,"paid":%s}\n' "$H" \
    "$(cast call "$(jq -r .shareToken "$OUT")" "balanceOf(address)(uint256)" "$H" --rpc-url "$RPC" | awk '{print $1}')" \
    "$(cast call "$TOKEN" "balanceOf(address)(uint256)" "$H" --rpc-url "$RPC" | awk '{print $1}')"
done | jq -s . > "$SITE_JSON.holders"
jq --slurpfile h "$SITE_JSON.holders" '. + {holderBalances: $h[0]}' "$SITE_JSON.tmp" > "$SITE_JSON"
rm -f "$SITE_JSON.tmp" "$SITE_JSON.holders"; chmod 644 "$SITE_JSON"
echo "done → $(jq -r .gas.distribute "$SITE_JSON") gas for $(jq '.holders|length' "$SITE_JSON") holders in one transaction"
