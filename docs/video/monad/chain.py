#!/usr/bin/env python3
"""Render the Monad transactions of the live demo as plain HTML cards for the video (chain-<step>.html).

Block explorers sit behind a bot check that headless browsers can't pass, so every value here is read from the Monad
testnet RPC with `cast` at build time: status, block, sender, gas, decoded events and the revert reason.
Input: site/monad-deploy.json. Run from this folder: python3 chain.py
"""
from __future__ import annotations

import html
import json
import os
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RPC = os.environ.get("RPC", "https://testnet-rpc.monad.xyz")
D = json.loads((ROOT / "site/monad-deploy.json").read_text())
CAST = [str(Path.home() / ".foundry/bin/cast")]

TOPICS = {
    "UpdateProposed(uint256,bytes32,bytes32,uint16,string)": "UpdateProposed",
    "UpdateAnchored(bytes32,uint256,bytes32,uint16,uint16,uint16,address)": "UpdateAnchored",
    "DividendPaid(uint256,address,uint256,uint256)": "DividendPaid",
    "RoundPaid(uint256,address,address,uint256,uint32,uint256,bytes32)": "RoundPaid",
    "Transfer(address,address,uint256)": "Transfer (mAUD)",
    "Approval(address,address,uint256)": "Approval (mAUD)",
}


def cast(*a: str) -> str:
    return subprocess.run(CAST + list(a) + ["--rpc-url", RPC], capture_output=True, text=True, check=True).stdout.strip()


def sig2topic() -> dict[str, str]:
    return {subprocess.run(CAST + ["keccak", s], capture_output=True, text=True, check=True).stdout.strip(): n
            for s, n in TOPICS.items()}


def short(a: str, n: int = 10) -> str:
    return a[:n] + "…" + a[-6:]


NAMES = {D["updateAnchor"].lower(): "UpdateAnchor", D["batchDividend"].lower(): "BatchDividend",
         D["director"].lower(): "Director wallet", D["operator"].lower(): "Issuer service"}


def who(a: str) -> str:
    n = NAMES.get(a.lower())
    return f"{short(a)} <b>{n}</b>" if n else short(a)


def receipt(tx: str) -> dict:
    return json.loads(cast("receipt", tx, "--json"))


def card(step: str, title: str, tx: str, extra: str = "") -> str:
    r = receipt(tx)
    t = sig2topic()
    events: dict[str, int] = {}
    for lg in r["logs"]:
        n = t.get(lg["topics"][0], "other")
        events[n] = events.get(n, 0) + 1
    ok = int(r["status"], 16) == 1
    gas = int(r["gasUsed"], 16)
    price = int(r["effectiveGasPrice"], 16)
    fee = gas * price / 1e18
    ev = " · ".join(f"{n} × {c}" if c > 1 else n for n, c in events.items()) or "none (reverted, no state change)"
    rows = [
        ("Transaction", f"<code>{tx}</code>"),
        ("Status", '<span class="ok">Success</span>' if ok else '<span class="bad">Reverted by the contract</span>'),
        ("Block", f"{int(r['blockNumber'], 16):,}"),
        ("From", who(r["from"])),
        ("To", who(r["to"])),
        ("Gas used", f"{gas:,} · fee {fee:.4f} MON"),
        ("Events", ev),
    ]
    body = "".join(f"<tr><th>{k}</th><td>{v}</td></tr>" for k, v in rows)
    return f"""<section><p class="step">{html.escape(step)}</p><h1>{html.escape(title)}</h1>
<table>{body}</table>{extra}</section>"""


def page(name: str, inner: str) -> None:
    (HERE / f"chain-{name}.html").write_text(f"""<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet">
<style>
body{{margin:0;background:#f7f7fb;font-family:Inter,sans-serif;color:#17172b;width:1920px;height:1080px;overflow:hidden}}
header{{height:84px;display:flex;align-items:center;gap:16px;padding:0 120px;background:#fff;border-bottom:1px solid #e4e4ee;font-size:22px}}
header b{{color:#6d4aff}} header span{{color:#6b6b80;font-size:20px}}
section{{padding:48px 120px}} .step{{color:#6d4aff;font-weight:600;letter-spacing:.08em;text-transform:uppercase;font-size:20px;margin:0}}
h1{{font-size:46px;margin:10px 0 30px}} table{{border-collapse:collapse;width:100%;background:#fff;border:1px solid #e4e4ee;border-radius:14px;font-size:24px}}
th{{text-align:left;width:230px;color:#6b6b80;font-weight:600;padding:16px 26px;border-bottom:1px solid #eee}}
td{{padding:16px 26px;border-bottom:1px solid #eee}} code{{font-size:21px}} .ok{{color:#0a8a4a;font-weight:700}} .bad{{color:#c0263a;font-weight:700}}
.note{{margin-top:22px;font-size:22px;color:#4b4b60}} .note code{{background:#efeefe;padding:2px 8px;border-radius:6px}}
</style></head><body><header><b>Monad testnet</b> chain 10143 <span>· read live from testnet-rpc.monad.xyz</span></header>
{inner}</body></html>""")


def main() -> None:
    tx = D["txs"]
    page("approve", card("Step 2 · director approval", "A director approves the AI-drafted update", tx["approve"],
                         '<p class="note">Signed by the director wallet, not the issuer service that recorded the draft. '
                         'Only now does <code>UpdateAnchor.verify(0, hash)</code> return true.</p>'))
    paid = [h for h in D.get("holderBalances", [])][:4]
    lines = "".join(f"<tr><td><code>{short(h['account'])}</code></td><td>{int(h['shares']):,} shares</td>"
                    f"<td>{int(h['paid']) / 1e6:,.2f} mAUD</td></tr>" for h in paid)
    page("distribute", card(
        "Step 3 · dividend", f"One transaction pays all {len(D['holders'])} holders", tx["distribute"],
        f'<table style="margin-top:22px;font-size:22px">{lines}<tr><td colspan="3" style="color:#6b6b80">… and '
        f'{len(D["holders"]) - len(paid)} more holders, each paid pro-rata in the same transaction</td></tr></table>'))
    page("refused", card(
        "Step 4 · the gate", "A payout against an unapproved update is refused", tx["refusedUnapproved"],
        '<p class="note">Update 1 was recorded but never approved by a director. <code>BatchDividend.distribute</code> '
        'checks UpdateAnchor itself and reverts with <code>UpdateNotApproved(1)</code>. No money moved.</p>'))


if __name__ == "__main__":
    main()
