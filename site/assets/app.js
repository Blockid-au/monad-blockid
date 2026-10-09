// monad.blockid.au — language toggle, sample update, in-browser verification against Monad, live deploy data.
(function () {
  "use strict";
  const RPC = "https://testnet-rpc.monad.xyz";
  const EXPLORER = "https://testnet.monadvision.com";
  const SEL = { verify: "0x1d97ce31", roundCount: "0x127f0b3f", balanceOf: "0x70a08231" };

  // ------------------------------------------------------------------ Vietnamese copy (EN is in the HTML)
  const VI = {
    "nav.how": "Cách hoạt động", "nav.live": "Trên Monad", "nav.why": "Vì sao Monad", "nav.deck": "Deck", "nav.sub": "Bài nộp",
    "hero.h1": "Hiểu rõ doanh nghiệp <em>bạn sở hữu</em>.",
    "hero.lede": "Nếu bạn sở hữu 2% một công ty tư nhân, hôm nay bạn chỉ có một file PDF. Business Passport cho mọi cổ đông một sổ cổ đông trực tiếp trên Monad, bản cập nhật hằng tháng do AI soạn từ dữ liệu thật của công ty và được giám đốc phê duyệt, và cổ tức trả vào mọi ví trong một giao dịch.",
    "cta.live": "Xem trên Monad", "cta.deck": "Mở pitch deck", "cta.code": "Xem mã nguồn",
    "p.eyebrow": "Vấn đề", "p.h2": "Công ty tư nhân là lớp tài sản lớn nhất mà không ai nhìn vào được.",
    "p.sub": "Cổ đông thiên thần, nhân viên và gia đình cầm một tờ chứng nhận và chờ đợi. Riêng Úc có hàng triệu công ty tư nhân, sổ cổ đông nằm trong bảng tính đối chiếu thủ công.",
    "p1.h": "Không có sổ cổ đông trực tiếp", "p1.t": "Quyền sở hữu là một chứng nhận PDF và một bảng tính. Không ai kiểm tra được.",
    "p2.h": "Bản cập nhật khó tin", "p2.t": "Cập nhật đến khi nhà sáng lập nhớ ra. Nhà đầu tư không phân biệt được dữ liệu với quảng cáo.",
    "p3.h": "AI làm tệ hơn", "p3.t": "AI viết một bản cập nhật thuyết phục trong vài giây. Không có bằng chứng và người chịu trách nhiệm ký, đó chỉ là thêm nhiễu.",
    "p4.h": "Cổ tức chậm", "p4.t": "Chuyển khoản ngân hàng, chậm hàng tháng, từng người một.",
    "h.eyebrow": "Cách hoạt động trên Monad", "h.h2": "AI đề xuất. Giám đốc ký. Monad ghi nhận. Mọi cổ đông được trả.",
    "h.sub": "AI không bao giờ giữ khoá và không bao giờ chuyển tiền. Kết quả của AI chỉ trở thành hồ sơ cổ đông sau khi một người có tên phê duyệt, và hợp đồng cổ tức từ chối trả cho đến khi phê duyệt đó nằm trên chain.",
    "f1.who": "Công ty", "f1.b": "Kết nối dữ liệu", "f1.t": "Stripe, Xero, GA4, GitHub.",
    "f2.who": "Pipeline AI", "f2.b": "Soạn bản cập nhật", "f2.t": "Mỗi nhận định được đánh dấu có bằng chứng hoặc thiếu, kèm điểm tin cậy.",
    "f3.who": "Dịch vụ phát hành", "f3.b": "Ghi bản nháp", "f3.t": "<code>UpdateAnchor.propose</code>: hash nội dung, độ tin cậy, số lượng.",
    "f4.who": "Giám đốc (con người)", "f4.b": "Phê duyệt và ký", "f4.t": "Ví thường, hoặc ví smart account passkey qua EIP-712 + ERC-1271. Không được là người ghi.",
    "f5.who": "Monad", "f5.b": "Neo và trả tiền", "f5.t": "Sự kiện <code>UpdateAnchored</code>; <code>BatchDividend</code> trả mọi cổ đông trong một giao dịch.",
    "new": "Mới",
    "c1": "ERC-20 có cấp phép cho từng loại cổ phần (<code>BlockIDShareToken</code> + <code>IdentityRegistry</code>). Chỉ ví đã xác minh được giữ cổ phần. Phản chiếu sổ cổ đông pháp lý: bằng chứng sở hữu, không phải bán token.",
    "c2": "Bản cập nhật do AI soạn được ghi kèm điểm tin cậy bằng chứng và số nhận định có / thiếu bằng chứng; chỉ được neo khi giám đốc của công ty đó phê duyệt. Chữ ký từ ví EOA hoặc smart account ERC-1271; nonce và hạn chót chống phát lại.",
    "c3": "Một giao dịch do giám đốc công bố trả cổ tức stablecoin theo tỷ lệ cho mọi cổ đông. Hợp đồng kiểm tra danh sách đầy đủ, không trùng, khớp tổng cung. Sự kiện cho từng người là biên nhận thanh toán.",
    "u.eyebrow": "Cổ đông nhìn thấy gì", "u.h2": "Bản cập nhật cho thấy điều gì có dữ liệu chứng minh, điều gì chưa.",
    "u.sub": "Bản cập nhật mẫu của một công ty demo (dữ liệu thử, không phải khách hàng). Từng byte của nó được băm và neo trên Monad.",
    "u.conf": "Độ tin cậy bằng chứng",
    "v.h": "Tự kiểm tra", "v.t": "Trình duyệt của bạn tải bản cập nhật, băm (keccak256) và hỏi Monad xem giám đốc đã phê duyệt đúng nội dung đó chưa. Không cần tin máy chủ BlockID.",
    "v.btn": "Kiểm tra trên Monad",
    "l.eyebrow": "Trực tiếp trên Monad testnet", "l.h2": "Hợp đồng, giao dịch và số dư, đọc từ chain.",
    "l.pending": "Đang chờ deploy lên Monad testnet. Toàn bộ luồng đã chạy trọn vẹn trên chain cục bộ; địa chỉ sẽ hiện ở đây ngay khi script deploy xong.",
    "l.c": "Hợp đồng / bước", "l.wait": "Chờ deploy testnet", "l.a": "Địa chỉ hoặc giao dịch", "l.hold": "Cổ tức trả trong một giao dịch",
    "l.h1": "Ví cổ đông (mẫu)", "l.h2c": "Cổ phần", "l.h3": "Cổ tức (mAUD)", "l.none": "Hiện sau khi đợt cổ tức được trả trên Monad.",
    "w.eyebrow": "Vì sao Monad", "w.h2": "Trả mọi cổ đông trong một giao dịch, chỉ tốn vài cent trên Monad.",
    "w.sub": "Đo trên Monad testnet với hợp đồng đã deploy, và bằng Foundry để so sánh EVM.",
    "w.t0": "Đợt cổ tức", "w.t1": "Gas", "w.t2": "Giao dịch", "w.t3": "Chi phí", "w.r1": "20 cổ đông trên Monad testnet, đo thật", "w.r2": "200 cổ đông trên Monad, ngoại suy từ lần đo thật", "w.r4": "200 cổ đông với Merkle claim (gas EVM)",
    "w.r3": "200 cổ đông trên Ethereum L1, cùng hợp đồng (gas EVM)",
    "w.note": "Monad tính phí theo gas limit và định giá truy cập state lạnh cao hơn Ethereum, nên chi phí Monad lấy từ giao dịch thật trên Monad testnet (105 gwei). Gas EVM đo bằng Foundry (<code>forge test --match-test bench</code>). Giá ngày 8/10/2026: MON US$0,0241; ETH US$2.476 ở 0,158 gwei.",
    "w1.h": "Chi phí ổn định", "w1.t": "Dưới một cent cho 20 cổ đông, vài cent cho 200. Công ty nhỏ cũng trả hằng tháng và neo lại hằng tuần được.",
    "w2.h": "Block rộng", "w2.t": "Khoảng 400 cổ đông vừa một giao dịch (30M gas mỗi giao dịch), block 150M gas chứa nhiều đợt trả của nhiều công ty. Sổ lớn hơn chia lô hoặc dùng Merkle.",
    "w3.h": "Xác nhận nhanh", "w3.t": "Block dưới một giây: giám đốc thấy khoản trả được xác nhận ngay trên màn hình phê duyệt, cổ đông thấy ngay sau đó.",
    "t.eyebrow": "Vì sao Track 4", "t.h2": "Lớp tin cậy cho những gì công ty nói về chính mình.",
    "t1.h": "Xác nhận AI có người gác", "t1.t": "Kết quả AI chỉ thành hồ sơ sau khi một giám đốc có tên ký. Người ghi không bao giờ tự duyệt bản nháp của mình (bốn mắt, cưỡng chế trên chain).",
    "t2.h": "Ký bằng smart account", "t2.t": "Giám đốc duyệt bằng chữ ký EIP-712 kiểm qua ERC-1271, nên ví smart account passkey (P256 / WebAuthn) dùng được, không cần seed phrase. Ai cũng có thể chuyển tiếp.",
    "t3.h": "Danh tính của pháp nhân", "t3.t": "Sổ cổ đông ví đã xác minh phản chiếu sổ cổ đông thật của công ty, kèm hash điều lệ và báo cáo định giá trên chain.",
    "b.eyebrow": "Làm trong Metropolis", "b.h2": "Cái gì mới, cái gì có từ trước.",
    "b.new": "Mới cho Monad (nhánh <code>monad</code>)",
    "b1": "<code>UpdateAnchor.sol</code>: cập nhật do AI soạn, giám đốc phê duyệt, chữ ký EIP-712 / ERC-1271",
    "b2": "<code>BatchDividend.sol</code>: trả theo tỷ lệ trong một giao dịch, kiểm tra đầy đủ trên chain",
    "b3": "15 test Foundry mới (tổng 52) và benchmark gas ở trên",
    "b4": "<code>MonadPassport.s.sol</code> + <code>scripts/monad-demo.sh</code>: deploy, đề xuất, duyệt, trả, công bố",
    "b5": "Trang này, có kiểm tra ngay trong trình duyệt với Monad",
    "b6": "Đã deploy lên Monad testnet", "b7": "Màn hình đăng nhập passkey cho giám đốc trong app BlockID",
    "b.pre": "Nền tảng có từ trước (công bố)",
    "b.pret": "Xây trong tháng 9/2026, lần đầu trình diễn tại EAG Global Buildathon Sydney ngày 26/9: hợp đồng sổ cổ đông (<code>BlockIDShareToken</code>, <code>IdentityRegistry</code>), <code>DividendDistributor</code> Merkle, <code>CapTableAnchor</code>, <code>AgentProvenance</code>, cùng web app và pipeline phân tích BlockID tại eth.blockid.au. Toàn bộ lịch sử có trong repo; phần Monad nằm ở nhánh <code>monad</code> từ 8/10/2026.",
    "s.eyebrow": "Trạng thái thật", "s.h2": "Chúng tôi đang ở đâu hôm nay.",
    "s1.h": "Chỉ testnet", "s1.t": "Monad testnet, công ty demo, ví cổ đông mẫu được sinh tự động. Không phải chào bán chứng khoán.",
    "s2.h": "Chưa có người dùng thật", "s2.t": "Các công ty trong app BlockID là hồ sơ mẫu dựng từ thông tin công khai, không phải khách hàng. Pilot thật sẽ được tính riêng khi đăng ký.",
    "s3.h": "Tiếp theo", "s3.t": "Đăng nhập passkey cho giám đốc, bảng tin cổ đông lấy từ Monad, audit, rồi mainnet với các công ty pilot đầu tiên.",
    "tm.eyebrow": "Đội ngũ", "tm.h2": "Tự xây dựng, từ Sydney và TP. Hồ Chí Minh.",
    "tm1": "Đồng sáng lập & CEO. Sáng lập Vietnam Blockchain Corporation (2016) và Auschain Pty Ltd (Sydney). Cựu CTO; visa Global Talent Úc. <a href=\"https://au.linkedin.com/in/dovanlong\">LinkedIn</a>",
    "tm2": "Đồng sáng lập. Kinh nghiệm phía nhà đầu tư và thị trường vốn (Dragon Capital Group); University of Hawai'i Shidler College of Business. Sống tại Sydney. <a href=\"https://www.linkedin.com/in/tuantruong858/\">LinkedIn</a>",
    "k.eyebrow": "Liên kết", "k1": "Mã nguồn (MIT)", "k1b": "nhánh", "k2": "Pitch deck", "k3": "Video demo",
    "k3t": "Video demo Monad: quay sau khi deploy testnet.", "k3l": "Video giới thiệu sản phẩm (trước Monad, 5 phút)",
    "k4": "App BlockID", "k5": "Liên hệ",
    "legal": "Bản demo testnet. Không phải chào bán chứng khoán hay tư vấn tài chính."
  };
  const EN = {};
  let lang = "en";
  try { lang = localStorage.getItem("bp-lang") || "en"; } catch (e) { /* storage blocked */ }

  function applyLang() {
    document.documentElement.lang = lang;
    document.querySelectorAll("[data-i18n],[data-i18n-html]").forEach(function (el) {
      const key = el.getAttribute("data-i18n") || el.getAttribute("data-i18n-html");
      if (!(key in EN)) EN[key] = el.innerHTML;
      el.innerHTML = lang === "vi" && VI[key] ? VI[key] : EN[key];
    });
    const b = document.getElementById("lang");
    if (b) b.textContent = lang === "vi" ? "EN" : "VI";
  }
  const langBtn = document.getElementById("lang");
  if (langBtn) langBtn.addEventListener("click", function () {
    lang = lang === "vi" ? "en" : "vi";
    try { localStorage.setItem("bp-lang", lang); } catch (e) { /* ignore */ }
    applyLang(); renderUpdate(); renderLive();
  });
  const t = (en, vi) => (lang === "vi" ? vi : en);

  // ------------------------------------------------------------------ helpers
  const short = (a) => a.slice(0, 8) + "…" + a.slice(-6);
  const link = (kind, v) => `<a class="mono" href="${EXPLORER}/${kind}/${v}" target="_blank" rel="noopener">${short(v)}</a>`;
  const pad = (hex) => hex.replace(/^0x/, "").padStart(64, "0");
  async function call(to, data) {
    const r = await fetch(RPC, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_call", params: [{ to, data }, "latest"] })
    });
    const j = await r.json();
    if (j.error) throw new Error(j.error.message);
    return j.result;
  }
  const fmtUnits = (v, d) => (Number(BigInt(v)) / 10 ** d).toLocaleString(lang === "vi" ? "vi-VN" : "en-AU", { maximumFractionDigits: 2 });

  // ------------------------------------------------------------------ sample update
  let update = null, updateText = null, deploy = null;
  function renderUpdate() {
    if (!update) return;
    document.getElementById("u-company").textContent = update.company + " · " + update.period;
    document.getElementById("u-summary").textContent = update.summary;
    const pct = update.evidence_confidence_bps / 100;
    document.getElementById("u-conf").textContent = pct + "%";
    document.getElementById("u-meter").style.width = pct + "%";
    document.getElementById("u-claims").innerHTML = update.claims.map(function (c) {
      const ok = c.status === "evidenced";
      return `<li><span class="badge ${ok ? "ok" : "miss"}">${ok ? t("evidenced", "có bằng chứng") : t("missing", "thiếu")}</span>
        <div>${c.claim}<small>${c.source || t("No evidence connected — shown to shareholders as missing.", "Chưa có bằng chứng — cổ đông thấy là thiếu.")}</small></div></li>`;
    }).join("");
  }

  // ------------------------------------------------------------------ live deploy data
  function renderLive() {
    if (!deploy) return;
    const s = document.getElementById("live-status");
    s.removeAttribute("data-i18n");
    s.innerHTML = t(`Deployed on Monad testnet (chain ${deploy.chainId}). Published ${deploy.publishedAt}. Click any address to open it in the explorer.`,
      `Đã deploy trên Monad testnet (chain ${deploy.chainId}). Cập nhật ${deploy.publishedAt}. Bấm địa chỉ để mở trên explorer.`);
    const rows = [
      ["ShareRegister · BlockIDShareToken", link("address", deploy.shareToken)],
      ["IdentityRegistry", link("address", deploy.identityRegistry)],
      ["UpdateAnchor", link("address", deploy.updateAnchor)],
      ["BatchDividend", link("address", deploy.batchDividend)],
      ["mAUD (testnet stablecoin)", link("address", deploy.payToken)],
      [t("1 · AI-drafted update recorded", "1 · Ghi bản cập nhật do AI soạn"), link("tx", deploy.txs.propose)],
      [t("2 · Director approves", "2 · Giám đốc phê duyệt") + ` <span class="note">(${deploy.gas.approve.toLocaleString()} gas)</span>`, link("tx", deploy.txs.approve)],
      [t(`3 · Dividend to ${deploy.holders.length} holders, one transaction`, `3 · Cổ tức cho ${deploy.holders.length} cổ đông, một giao dịch`) +
        ` <span class="note">(${deploy.gas.distribute.toLocaleString()} gas)</span>`, link("tx", deploy.txs.distribute)]
    ];
    document.getElementById("live-rows").innerHTML = rows.map((r) => `<tr><td>${r[0]}</td><td>${r[1]}</td></tr>`).join("");
    document.getElementById("holder-rows").innerHTML = (deploy.holderBalances || []).map((h) =>
      `<tr><td>${link("address", h.account)}</td><td class="r">${Number(h.shares).toLocaleString()}</td><td class="r">${fmtUnits(h.paid, 6)}</td></tr>`).join("");
    const b = document.getElementById("b-deploy");
    if (b) b.classList.remove("todo");
    const chip = document.getElementById("chip-net");
    if (chip) { chip.classList.add("ok"); chip.textContent = t("Live on Monad testnet", "Đang chạy trên Monad testnet"); }
  }

  // ------------------------------------------------------------------ verify in the browser
  async function verify() {
    const out = document.getElementById("verify-out");
    const log = [];
    const say = (s) => { log.push(s); out.innerHTML = log.join("\n"); };
    out.innerHTML = "";
    try {
      const text = await (await fetch("monad-update.json", { cache: "no-store" })).text();
      // the deploy script hashes the file content without its trailing newline (shell `$(cat file)`)
      const hash = "0x" + keccak256(text.replace(/\n+$/, ""));
      say(t("keccak256(update) = ", "keccak256(bản cập nhật) = ") + hash);
      if (!deploy) {
        say(t("Not deployed to Monad yet — nothing to compare against.", "Chưa deploy lên Monad — chưa có gì để so."));
        return;
      }
      say(t("Asking Monad: UpdateAnchor.verify(", "Hỏi Monad: UpdateAnchor.verify(") + deploy.updateId + ", hash) …");
      const r = await call(deploy.updateAnchor, SEL.verify + pad(Number(deploy.updateId).toString(16)) + pad(hash));
      if (BigInt(r) === 1n) {
        say(`<span class="pass">✓ ${t("PASS — a director approved exactly this content on Monad.", "ĐẠT — giám đốc đã phê duyệt đúng nội dung này trên Monad.")}</span>`);
      } else {
        say(`<span class="fail">✗ ${t("FAIL — content differs from what was approved, or not approved.", "KHÔNG ĐẠT — nội dung khác bản đã duyệt, hoặc chưa được duyệt.")}</span>`);
      }
      const rc = await call(deploy.batchDividend, SEL.roundCount);
      say(t("BatchDividend rounds paid: ", "Số đợt cổ tức đã trả: ") + BigInt(rc).toString());
    } catch (e) {
      say(`<span class="fail">${t("Error", "Lỗi")}: ${e.message}</span>`);
    }
  }

  // ------------------------------------------------------------------ boot
  applyLang();
  fetch("monad-update.json", { cache: "no-store" }).then((r) => r.text()).then(function (txt) {
    updateText = txt; update = JSON.parse(txt); renderUpdate();
  }).catch(function () { /* section keeps placeholders */ });
  fetch("monad-deploy.json", { cache: "no-store" }).then(function (r) { return r.ok ? r.json() : null; })
    .then(function (d) { deploy = d; renderLive(); }).catch(function () { deploy = null; });
  const vb = document.getElementById("verify-btn");
  if (vb) vb.addEventListener("click", verify);
})();
