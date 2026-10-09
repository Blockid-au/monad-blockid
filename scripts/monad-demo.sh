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
OUT_NAME=monad-passport.json
TXLOG="$ROOT/contracts/deployments/out/monad-txs.json"
UPDATE="$ROOT/contracts/deployments/params/monad-update.json"
SITE_JSON="$ROOT/site/monad-deploy.json"

if [[ -n ${LOCAL_KEYS:-} ]]; then   # anvil default accounts 0 and 1
  DEP_ARGS=(--private-key "${ANVIL_KEY0:?set ANVIL_KEY0}"); DIR_ARGS=(--private-key "${ANVIL_KEY1:?set ANVIL_KEY1}")
  DIRECTOR=$(cast wallet address "${ANVIL_KEY1}")
  TXLOG="$ROOT/contracts/deployments/out/local-txs.json"; OUT_NAME=local-passport.json   # never touch the Monad record
  SITE_JSON="$ROOT/contracts/deployments/out/local-deploy.json"
else
  DEP_ARGS=(--account blockid-deployer --password-file "$KEYS/deployer.password")
  DIR_ARGS=(--account blockid-admin --password-file "$KEYS/admin.password")
  DIRECTOR=$(cat "$KEYS/admin.address")
fi
DEPLOYER=$(cast wallet address "${DEP_ARGS[@]}")
OUT="$ROOT/contracts/deployments/out/$OUT_NAME"

[[ $(cast chain-id --rpc-url "$RPC") == "$CHAIN_ID" ]] || { echo "RPC is not chain $CHAIN_ID"; exit 1; }
echo "== deployer $DEPLOYER balance: $(cast from-wei "$(cast balance "$DEPLOYER" --rpc-url "$RPC")") MON"
UPDATE_HASH=$(cast keccak "$(cat "$UPDATE")")
CONF=$(jq -r .evidence_confidence_bps "$UPDATE")
echo "== update hash (AI-drafted shareholder update): $UPDATE_HASH  confidence ${CONF} bps"
mkdir -p "$(dirname "$OUT")"; [[ -f $TXLOG ]] || echo '{}' > "$TXLOG"
logtx() { jq --arg k "$1" --arg v "$2" '. + {($k): $v}' "$TXLOG" > "$TXLOG.tmp" && mv "$TXLOG.tmp" "$TXLOG"; }
lasttx() { jq -r '[.transactions[] | select(.function != null and (.function | startswith($f)))] | last | .hash // empty' --arg f "$2" "$1"; }
need() { [[ -n $1 && $1 != null ]] || { echo "missing $2 transaction hash"; exit 6; }; }
gasof() { cast receipt "$1" gasUsed --rpc-url "$RPC"; }

cd "$ROOT/contracts"
BCAST="broadcast/MonadPassport.s.sol/$CHAIN_ID"
LOG="${TMPDIR:-/tmp}/monad-demo"
if [[ ! -f $OUT || $(jq -r .chainId "$OUT") != "$CHAIN_ID" ]]; then
  echo "== 1) deploy register, UpdateAnchor, BatchDividend; issue shares; record the AI-drafted update"
  forge test --offline >/dev/null || { echo "forge test failed — not deploying"; exit 2; }
  echo "   forge test: ok"
  rm -f "$OUT.pending"   # forge writes this during simulation; it only becomes $OUT once the broadcast succeeded
  PASSPORT_OUT="./deployments/out/$OUT_NAME.pending" DIRECTOR="$DIRECTOR" UPDATE_HASH="$UPDATE_HASH" UPDATE_CONFIDENCE_BPS="$CONF" \
    forge script script/MonadPassport.s.sol:MonadPassport --sig "deploy()" --rpc-url "$RPC" --broadcast --slow \
    "${DEP_ARGS[@]}" > "$LOG-deploy.log" 2>&1 || { tail -30 "$LOG-deploy.log"; exit 3; }
  mv "$OUT.pending" "$OUT"
  grep -E 'UpdateAnchor|BatchDividend' "$LOG-deploy.log" || true
  TX=$(lasttx "$BCAST/deploy-latest.json" 'propose('); need "$TX" propose; logtx propose "$TX"
else
  echo "== 1) already deployed ($OUT) — skipping"
fi

UA=$(jq -r .updateAnchor "$OUT"); ID=$(jq -r .updateId "$OUT"); BD=$(jq -r .batchDividend "$OUT")
for C in "$UA" "$BD"; do [[ $(cast code "$C" --rpc-url "$RPC") != 0x ]] || { echo "no contract at $C on chain $CHAIN_ID — delete $OUT and re-run"; exit 5; }; done
OK=$(cast call "$UA" "verify(uint256,bytes32)(bool)" "$ID" "$UPDATE_HASH" --rpc-url "$RPC")   # an RPC error aborts here
if [[ $OK != true ]]; then
  echo "== 2) director $DIRECTOR approves update $ID"
  TX=$(cast send "$UA" "approve(uint256)" "$ID" --rpc-url "$RPC" "${DIR_ARGS[@]}" --json | jq -r .transactionHash)
  need "$TX" approve; logtx approve "$TX"; echo "   tx $TX"
else
  echo "== 2) update $ID already anchored"
fi

RC=$(cast call "$BD" "roundCount()(uint256)" --rpc-url "$RPC")
if [[ $RC == 0 ]]; then
  echo "== 3) one transaction pays every holder (guarded by UpdateAnchor.verify)"
  PASSPORT_OUT="./deployments/out/$OUT_NAME" forge script script/MonadPassport.s.sol:MonadPassport --sig "pay()" --rpc-url "$RPC" --broadcast --slow \
    "${DEP_ARGS[@]}" > "$LOG-pay.log" 2>&1 || { tail -30 "$LOG-pay.log"; exit 4; }
  grep -E 'paid round' "$LOG-pay.log" || true
  TX=$(lasttx "$BCAST/pay-latest.json" 'distribute('); need "$TX" distribute; logtx distribute "$TX"
else
  echo "== 3) dividend round already paid"
fi

echo "== 4) publish $SITE_JSON"
DIST_TX=$(jq -r .distribute "$TXLOG")
APPROVE_TX=$(jq -r .approve "$TXLOG"); need "$DIST_TX" distribute; need "$APPROVE_TX" approve
GAS_DIST=$(gasof "$DIST_TX"); GAS_APPROVE=$(gasof "$APPROVE_TX")
TOKEN=$(jq -r .payToken "$OUT")
jq -n --slurpfile o "$OUT" --slurpfile t "$TXLOG" --slurpfile u "$UPDATE" \
  --arg exp "$EXPLORER" --arg rpc "$RPC" --arg gasDist "$GAS_DIST" --arg gasApprove "$GAS_APPROVE" \
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
