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

## Live on Monad testnet (deployed 8 Oct 2026)

| Contract / step | Address or transaction |
|---|---|
| ShareRegister · BlockIDShareToken | [0xf3156Ad6eA559096D4aF350b39984408c764698E](https://testnet.monadvision.com/address/0xf3156Ad6eA559096D4aF350b39984408c764698E) |
| IdentityRegistry | [0x6B96bcE8937e1416Ec1DAC4ADAdD71FE879F8e84](https://testnet.monadvision.com/address/0x6B96bcE8937e1416Ec1DAC4ADAdD71FE879F8e84) |
| UpdateAnchor | [0x112C26D5f5d602293f1a00029f5E375763e70282](https://testnet.monadvision.com/address/0x112C26D5f5d602293f1a00029f5E375763e70282) |
| BatchDividend | [0x8cbA8cda3E564A7B0866291061925e7B71f36252](https://testnet.monadvision.com/address/0x8cbA8cda3E564A7B0866291061925e7B71f36252) |
| mAUD (testnet stablecoin) | [0xC25d1C243530EB34708923F0D5E34C22386bB264](https://testnet.monadvision.com/address/0xC25d1C243530EB34708923F0D5E34C22386bB264) |
| 1 · AI-drafted update recorded | [0xc3e77ac0a0400a4d…](https://testnet.monadvision.com/tx/0xc3e77ac0a0400a4d9842a42cf93f3cc3c5a559a5db41e7b86da549ec947a5164) |
| 2 · Director approves (54,157 gas) | [0xc71205cc56044386…](https://testnet.monadvision.com/tx/0xc71205cc5604438655f68f038c352364ebce0b59f3acad8cd78e168d5f43799f) |
| 3 · Dividend to 20 holders, one transaction (1,494,099 gas) | [0xc4b28168800b675a…](https://testnet.monadvision.com/tx/0xc4b28168800b675a4b4e75f2d92189ed041d45b2c492227bd5ac8d5b2e478430) |

On Monad, the 20-holder payout was charged 1,494,099 gas at 105 gwei: 0.157 MON, about US$0.004. Monad charges the
gas limit and prices cold state access higher than Ethereum, so Monad costs are quoted from this measured transaction.
Extrapolated, 200 holders cost about 14.9M gas, about US$0.04, and about 400 holders fit in one 30M-gas transaction.
The whole run (deploy, issue, propose, approve, pay) cost about 1.46 MON.

## Benchmark (EVM gas, Foundry)

`cd contracts && forge test --match-test bench -vv`

| Holders | Gas (one transaction) | Gas per holder |
|---|---|---|
| 10 | 531,295 | 53,129 |
| 50 | 1,799,327 | 35,986 |
| 200 | 6,555,767 | 32,778 |

For comparison, Merkle `claimFor` has a median of 91,765 gas per holder, plus 21,000 base gas per transaction. For
200 holders that is ≈ 22.6M gas over 200 transactions.

Ethereum prices on 8 Oct 2026: 0.158 gwei and ETH US$2,476, so a 200-holder batch costs ≈ US$2.56 on L1, or
≈ US$160 at 10 gwei.

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
- [x] Contracts deployed to Monad testnet, with the full flow run on chain (see the table above)
- [ ] Demo video (≤ 3 min; script on the submission page)
- [ ] Passkey sign-in screen for directors in the BlockID app

## Pre-existing foundation (disclose in the submission)

These were built in September 2026 and first shown at EAG Global Buildathon Sydney on 26 Sep 2026:

- `BlockIDShareToken`, `IdentityRegistry`, `DividendDistributor`, `CapTableAnchor`, `AgentProvenance`
- the BlockID web app and analysis pipeline (eth.blockid.au)

The Monad work is on branch `monad`, from 8 Oct 2026.
