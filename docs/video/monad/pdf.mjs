// Deck PDF (one 1280x720 page per slide, print CSS in site/deck/index.html) → site/deck/BlockID-Business-Passport-Monad.pdf
import { chromium } from "playwright";
const b = await chromium.launch({ args: ["--host-resolver-rules=MAP monad.blockid.au 127.0.0.1"] });
const p = await b.newPage({ viewport: { width: 1280, height: 720 } });
await p.goto("http://monad.blockid.au/deck/", { waitUntil: "networkidle" });
await p.evaluate(() => document.fonts.ready); await p.waitForTimeout(1500);
await p.pdf({ path: "deck.pdf", width: "1280px", height: "720px", printBackground: true, preferCSSPageSize: true });
await b.close();
