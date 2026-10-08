# BlockID Business Passport on Monad — Monad Metropolis 2026

Track 4: Trust, Identity & AI Infrastructure. Submission deadline 13 Oct 2026, 11:59 PM ET.

**Know the business you own:** on-chain share register, director-approved AI updates, and dividends paid to every
wallet in one transaction.

| | |
|---|---|
| Site | https://monad.blockid.au (served from [site/](../site)) |
| Deck | https://monad.blockid.au/deck/ · [PDF](../site/deck/BlockID-Business-Passport-Monad.pdf) |
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
- **BatchDividend:** `distribute(shareToken, payToken, amount, holders, resolutionRef)` pays every holder pro-rata in
  one transaction. Holders must be strictly ascending (no duplicates) and their balances must add up to total supply
  (nobody left out). Dust goes back to the payer. Each holder gets a `DividendPaid` event.

## Benchmark

`cd contracts && forge test --match-test bench -vv`

| Holders | Gas (one transaction) | Gas per holder |
|---|---|---|
| 10 | 531,295 | 53,129 |
| 50 | 1,799,327 | 35,986 |
| 200 | 6,555,767 | 32,778 |

For comparison, Merkle `claimFor` has a median of 91,765 gas per holder, plus 21,000 base gas per transaction. For
200 holders that is ≈ 22.6M gas over 200 transactions.

Prices on 8 Oct 2026, 23:43 UTC: Monad 102 gwei and MON US$0.0241; Ethereum 0.158 gwei and ETH US$2,476. At those
prices a 200-holder batch costs ≈ US$0.016 on Monad and ≈ US$2.56 on Ethereum L1. Monad charges the gas limit,
not the gas used.

## Monad testnet deploy

| | |
|---|---|
| Chain id | 10143 |
| RPC | https://testnet-rpc.monad.xyz (`monad_testnet` in [foundry.toml](../contracts/foundry.toml)) |
| Explorer | https://testnet.monadexplorer.com |
| Deployer / recorder | `0x2567Bb502ac840cF93957C60A410160a8cCb5ddf` (needs ≈ 2 MON) |
| Director (approver) | `0xC40052702B48631C26AD7c88b499bF230faCa21F` (the script tops it up) |

1. Fund the deployer with testnet MON.
2. Run `scripts/monad-demo.sh`. It runs [MonadPassport.s.sol](../contracts/script/MonadPassport.s.sol) in four steps:
   1. Deploy, then KYC and issue shares to 20 generated sample wallets, then record the update
      ([monad-update.json](../contracts/deployments/params/monad-update.json)).
   2. The director wallet approves the update.
   3. One transaction pays the dividend. `pay()` refuses unless `UpdateAnchor.verify` is true.
   4. Publish `site/monad-deploy.json`. The site then shows the addresses, transactions, gas and per-holder balances
      by itself.
3. Commit `site/monad-deploy.json` and `contracts/broadcast/MonadPassport.s.sol/10143/` as evidence.

Local dry run (port 8545 on this server is the BlockID EVM chain, so use another port):
`anvil --port 8645` and then
`RPC=http://127.0.0.1:8645 CHAIN_ID=31337 LOCAL_KEYS=1 ANVIL_KEY0=… ANVIL_KEY1=… scripts/monad-demo.sh`.
Tested on 8 Oct 2026: 20 holders paid in one transaction (847,344 gas), approval 46,182 gas.

## Built during the hackathon

- [x] Monad network config and deploy scripts
- [x] `UpdateAnchor.sol`, `BatchDividend.sol`, 15 new tests (52 in total), gas benchmark
- [x] End-to-end flow on a local chain
- [x] monad.blockid.au: pitch site (EN/VI), in-browser verification against Monad, live deploy data, deck, submission
      pack
- [ ] Contracts deployed to Monad testnet (waiting for testnet MON)
- [ ] Demo video (≤ 3 min; script on the submission page)
- [ ] Passkey sign-in screen for directors in the BlockID app

## Pre-existing foundation (disclose in the submission)

These were built in September 2026 and first shown at EAG Global Buildathon Sydney on 26 Sep 2026:

- `BlockIDShareToken`, `IdentityRegistry`, `DividendDistributor`, `CapTableAnchor`, `AgentProvenance`
- the BlockID web app and analysis pipeline (eth.blockid.au)

The Monad work is on branch `monad`, from 8 Oct 2026.
