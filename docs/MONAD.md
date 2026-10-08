# BlockID Business Passport on Monad — Monad Metropolis 2026

Track 4: Trust, Identity & AI Infrastructure. Submission deadline 13 Oct 2026.

**Know the business you own:** on-chain share register, AI-verified director updates, and dividends to the wallet.

## Contracts

The submission text uses product names; the Solidity sources keep their existing names.

| Product name | Source | What it does |
|---|---|---|
| ShareRegister | [BlockIDShareToken.sol](../contracts/src/BlockIDShareToken.sol) + [IdentityRegistry.sol](../contracts/src/IdentityRegistry.sol) | Permissioned ERC-20 per share class. Transfers only between whitelisted (KYC'd) holders. Mirrors the company's legal register. |
| UpdateAnchor | [CapTableAnchor.sol](../contracts/src/CapTableAnchor.sol) + [AgentProvenance.sol](../contracts/src/AgentProvenance.sol) | AI agent proposes a content hash, a different human wallet approves, and only then is the update or cap table anchored. |
| DividendDistributor | [DividendDistributor.sol](../contracts/src/DividendDistributor.sol) | Pro-rata stablecoin dividend round (Merkle root), with gasless `claimFor` by a relayer. |

## Monad testnet

| | |
|---|---|
| Chain id | 10143 |
| RPC | https://testnet-rpc.monad.xyz (`monad_testnet` in [foundry.toml](../contracts/foundry.toml)) |
| Explorer | https://testnet.monadexplorer.com |
| Deployer | `0x2567Bb502ac840cF93957C60A410160a8cCb5ddf` |
| Human approver | `0xC40052702B48631C26AD7c88b499bF230faCa21F` |
| Relayer | `0x1B43f0d3297F79cE6c8BbA12F4FadFBE9112DA4a` |

### Deploy

1. Fund the deployer with testnet MON from the Monad faucet. The script sends a small gas top-up to the approver and
   relayer.
2. Run `scripts/monad-demo.sh`. It runs the same four-eyes flow as the HashKey Chain demo:
   propose (deploy and record the AI report hash) → a different wallet approves → execute (KYC, issue shares, anchor
   valuation and cap table, fund the dividend round) → the relayer submits gasless claims.
3. Addresses land in `contracts/deployments/out/monad-demo.json`, and the transaction hashes in `monad-txs.json`.

Contract addresses (fill in after deploy):

- ShareRegister (BlockIDShareToken): `0x…`
- UpdateAnchor (CapTableAnchor / AgentProvenance): `0x…` / `0x…`
- DividendDistributor: `0x…`

## Built during the hackathon

Only list what is committed on the `monad` branch, with dates. Judges check commits.

- [x] Monad testnet network config and deploy script (`scripts/monad-demo.sh`, `HskDemo.s.sol` output path configurable)
- [ ] Contracts deployed to Monad testnet (blocked: deployer needs testnet MON)
- [ ] DividendDistributor batch payout: one transaction, N holders, gas benchmark vs Sepolia
- [ ] UpdateAnchor v2: evidence-confidence score and auditor flags in the anchored event, plus indexer and shareholder feed
- [ ] Director approval with passkey / smart-account sign-in
- [ ] Shareholder view on eth.blockid.au reading from Monad
- [ ] Demo video (≤3 min) and README benchmark table
