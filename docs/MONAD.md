# BlockID Business Passport on Monad — Monad Metropolis 2026

Track 4: Trust, Identity & AI Infrastructure. Submission deadline 13 Oct 2026, 11:59 PM ET.

**Know the business you own:** on-chain share register, director-approved AI updates, and dividends paid to every
wallet in one transaction.

| | |
|---|---|
| Site | https://monad.blockid.au (served from [site/](../site)) |
| Deck | https://monad.blockid.au/deck/ · [PDF](../site/deck/BlockID-Business-Passport-Monad.pdf) |
| Demo video (2:30) | https://eth.blockid.au/deck/blockid-business-passport-monad-captions.mp4 |
| Submission fields (copy-ready) | https://monad.blockid.au/submission.html |

## Contracts

| Product name | Source | Status |
|---|---|---|
| ShareRegister | [BlockIDShareToken.sol](../contracts/src/BlockIDShareToken.sol) + [IdentityRegistry.sol](../contracts/src/IdentityRegistry.sol) | Pre-existing (Sep 2026) |
| UpdateAnchor | [UpdateAnchor.sol](../contracts/src/UpdateAnchor.sol) | **New for Monad** |
| BatchDividend | [BatchDividend.sol](../contracts/src/BatchDividend.sol) | **New for Monad** |
| Merkle dividends, cap-table anchor, agent provenance | DividendDistributor, CapTableAnchor, AgentProvenance | Pre-existing (Sep 2026) |

- **UpdateAnchor:** the issuer service (`RECORDER_ROLE`, never an AI agent) records an AI-drafted update: content
  hash, evidence confidence (bps), evidenced and missing claim counts. A director of that company approves it,
  either directly or with an EIP-712 signature relayed by anyone. The signature is checked with `SignatureChecker`,
  so ERC-1271 smart accounts (passkey / P256) work. The recorder can never approve its own draft. `verify(id, hash)`
  is true only for approved, unchanged content.
- **BatchDividend:** `distribute(shareToken, payToken, amount, holders, updateId)` pays every holder pro-rata in
  one transaction, only if `updateId` is a director-approved update of the company linked to `shareToken`
  (`setCompany`), and at most once per update; the update's content hash is stored as the round's resolution. Holders must be strictly ascending (no duplicates) and their balances must add up to total supply
  (nobody left out). Dust goes back to the payer. Each holder gets a `DividendPaid` event.

## Live on Monad testnet (deployed 9 Oct 2026)

| Contract / step | Address or transaction |
|---|---|
| ShareRegister · BlockIDShareToken | [0x05fa63890Fcafa445b33ADEaba088A77cbE51B22](https://testnet.monadvision.com/address/0x05fa63890Fcafa445b33ADEaba088A77cbE51B22) |
| IdentityRegistry | [0x47938329CF7Df5B28Dc5b2FEdb4cBE8357e2106F](https://testnet.monadvision.com/address/0x47938329CF7Df5B28Dc5b2FEdb4cBE8357e2106F) |
| UpdateAnchor | [0x43616f6cD253568e0112E6ffe73481bA715F04EA](https://testnet.monadvision.com/address/0x43616f6cD253568e0112E6ffe73481bA715F04EA) |
| BatchDividend | [0x9575De573b8b75eB8Df5b2040D61957353fd9cd9](https://testnet.monadvision.com/address/0x9575De573b8b75eB8Df5b2040D61957353fd9cd9) |
| mAUD (testnet stablecoin) | [0xF32BF09472A7C41857c5aF281cCbecc1e6631Ba7](https://testnet.monadvision.com/address/0xF32BF09472A7C41857c5aF281cCbecc1e6631Ba7) |
| 1 · AI-drafted update recorded | [0x9a23bd00fae6a0b3…](https://testnet.monadvision.com/tx/0x9a23bd00fae6a0b3837968b5daadbdc4a57efb4d45918945c144d273354e6c90) |
| 2 · Director approves (62,537 gas) | [0x35f1e1e46c143348…](https://testnet.monadvision.com/tx/0x35f1e1e46c1433486e9e1ea249c332e9c34de215a5d2cb8ba56f4c22cd01bb22) |
| 3 · Dividend to 20 holders, one transaction (1,627,025 gas) | [0x15ebe321aedbb0f9…](https://testnet.monadvision.com/tx/0x15ebe321aedbb0f987596dab4c936f9e3c08c36465b4b7b6ffb454954968c5f2) |
| 4 · Payout against unapproved update 1 — reverted on-chain (`UpdateNotApproved`) | [0xe719266cb99ed4f1…](https://testnet.monadvision.com/tx/0xe719266cb99ed4f159f782a3cbf0b7afae213bfef51b7cbc301444087fc4946f) |

The first deploy (8 Oct 2026) checked approval only in the script; it is kept as evidence in
[monad-passport-v1.json](../contracts/deployments/out/monad-passport-v1.json) and
[site/monad-deploy-v1.json](../site/monad-deploy-v1.json).

On Monad, the 20-holder payout was charged 1,627,025 gas at 105 gwei: 0.171 MON, about US$0.004. Monad charges the
gas limit and prices cold state access higher than Ethereum, so Monad costs are quoted from this measured transaction.
Extrapolated, 200 holders cost about 16.3M gas, about US$0.04, and about 350 holders fit in one 30M-gas transaction.
The whole run (deploy, issue, propose, approve, pay) cost about 1.6 MON.

## Benchmark (EVM gas, Foundry)

`cd contracts && forge test --match-test bench -vv`

| Holders | Gas (one transaction) | Gas per holder |
|---|---|---|
| 10 | 615,254 | 61,525 |
| 50 | 1,950,893 | 39,017 |
| 200 | 6,886,581 | 34,432 |

For comparison, Merkle `claimFor` has a median of 91,765 gas per holder, plus 21,000 base gas per transaction. For
200 holders that is ≈ 22.6M gas over 200 transactions.

Ethereum prices on 8 Oct 2026: 0.158 gwei and ETH US$2,476, so a 200-holder batch costs ≈ US$2.69 on L1, or
≈ US$170 at 10 gwei.

## Monad testnet deploy

| | |
|---|---|
| Chain id | 10143 |
| RPC | https://testnet-rpc.monad.xyz (`monad_testnet` in [foundry.toml](../contracts/foundry.toml)) |
| Explorer | https://testnet.monadvision.com |
| Deployer / recorder | `0x2567Bb502ac840cF93957C60A410160a8cCb5ddf` (needs ≈ 2 MON) |
| Director (approver) | `0xC40052702B48631C26AD7c88b499bF230faCa21F` (the script tops it up) |

1. Fund the deployer with testnet MON.
2. Run `scripts/monad-demo.sh`. It runs [MonadPassport.s.sol](../contracts/script/MonadPassport.s.sol) in four steps:
   1. Deploy, then KYC and issue shares to 20 generated sample wallets, then record the update
      ([monad-update.json](../contracts/deployments/params/monad-update.json)).
   2. The director wallet approves the update.
   3. One transaction pays the dividend. `BatchDividend` refuses unless the update is director-approved (`pay()` also checks first, for a clear message).
   4. Publish `site/monad-deploy.json`. The site then shows the addresses, transactions, gas and per-holder balances
      by itself.
3. Commit `site/monad-deploy.json` and `contracts/broadcast/MonadPassport.s.sol/10143/` as evidence.

Local dry run (port 8545 on this server is the BlockID EVM chain, so use another port):
`anvil --port 8645` and then
`RPC=http://127.0.0.1:8645 CHAIN_ID=31337 LOCAL_KEYS=1 ANVIL_KEY0=… ANVIL_KEY1=… scripts/monad-demo.sh`.
Tested on 9 Oct 2026: 20 holders paid in one transaction (924,022 gas).

## Built during the hackathon

- [x] Monad network config and deploy scripts
- [x] `UpdateAnchor.sol`, `BatchDividend.sol`, 22 new tests (59 in total), gas benchmark
- [x] Approval gate inside `BatchDividend` (approved update, same company, once per update); recorder can never be a
      director; signatures bound to the director. Redeployed 9 Oct 2026, unapproved payout reverted on-chain
- [x] End-to-end flow on a local chain
- [x] monad.blockid.au: pitch site (EN/VI), in-browser verification against Monad, live deploy data, deck, submission
      pack
- [x] Contracts deployed to Monad testnet, with the full flow run on chain (see the table above)
- [x] Demo video, 2:30: https://eth.blockid.au/deck/blockid-business-passport-monad-captions.mp4 (built by [docs/video/monad](video/monad/README.md))
- [ ] Passkey sign-in screen for directors in the BlockID app

## Pre-existing foundation (disclose in the submission)

These were built in September 2026 and first shown at EAG Global Buildathon Sydney on 26 Sep 2026:

- `BlockIDShareToken`, `IdentityRegistry`, `DividendDistributor`, `CapTableAnchor`, `AgentProvenance`
- the BlockID web app and analysis pipeline (eth.blockid.au)

The Monad work is on branch `monad`, from 8 Oct 2026.
