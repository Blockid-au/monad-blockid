// Stills for the Monad demo video (1920x1080). Site via local nginx (DNS-independent); chain cards from chain.py.
// Run: sudo docker run --rm --network host --ipc host --user $(id -u):$(id -g) -e HOME=/tmp -v $PWD:/w -w /w \
//        mcr.microsoft.com/playwright:v1.63.0-noble node capture.mjs
import { chromium } from "playwright";
const SITE = "http://monad.blockid.au";
const b = await chromium.launch({ args: ["--host-resolver-rules=MAP monad.blockid.au 127.0.0.1"] });
const c = await b.newContext({ viewport: { width: 1920, height: 1080 }, colorScheme: "light", locale: "en-AU" });
const p = await c.newPage();
const settle = async (ms = 1500) => { await p.evaluate(() => document.fonts && document.fonts.ready); await p.waitForTimeout(ms); };
const at = async (sel, off = 90) => { await p.evaluate(([s, o]) => { const e = document.querySelector(s); scrollTo(0, e.getBoundingClientRect().top + scrollY - o); }, [sel, off]); await settle(800); };
const shot = async (n) => { await p.screenshot({ path: `shots/${n}.png` }); console.log(n); };

await p.goto(SITE + "/deck/#1", { waitUntil: "networkidle" }); await settle(); await shot("s01-title");
const nSlides = await p.evaluate(() => document.querySelectorAll(".slide").length);
await p.goto(SITE + "/", { waitUntil: "networkidle" }); await settle(2500); await shot("s02-hero");
await at("#how"); await shot("s03-how");
await at("#update"); await shot("s04-update");
for (const s of ["approve", "distribute", "refused"]) {
  await p.goto("file:///w/chain-" + s + ".html", { waitUntil: "networkidle" }); await settle(); await shot("s0" + { approve: 5, distribute: 6, refused: 7 }[s] + "-" + s);
}
await p.goto(SITE + "/", { waitUntil: "networkidle" }); await settle(2500);
await at("#update"); await p.click("#verify-btn");
await p.getByText(/BatchDividend rounds paid/).waitFor({ timeout: 30000 }); await settle(800);
await at("#verify-out", 520); await shot("s08-verify");
await at("#why"); await shot("s09-why");
await at("#live", 60); await shot("s10-live");
await p.goto(SITE + "/deck/#" + nSlides, { waitUntil: "networkidle" }); await p.reload({ waitUntil: "networkidle" }); await settle(); await shot("s11-end");
await b.close();
