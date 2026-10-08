  document.querySelectorAll(".field").forEach(function (f) {
    const box = f.querySelector(".box"), btn = f.querySelector(".copy"), cnt = f.querySelector(".count");
    if (cnt) cnt.textContent = box.innerText.length + " chars";
    btn.addEventListener("click", function () {
      navigator.clipboard.writeText(box.innerText).then(function () { btn.textContent = "Copied"; setTimeout(function () { btn.textContent = "Copy"; }, 1200); });
    });
  });
  fetch("monad-deploy.json", { cache: "no-store" }).then(function (r) { return r.ok ? r.json() : null; }).then(function (d) {
    if (!d) return;
    document.getElementById("addr").textContent =
      "ShareRegister (BlockIDShareToken) " + d.shareToken + " · UpdateAnchor " + d.updateAnchor +
      " · BatchDividend " + d.batchDividend + " · IdentityRegistry " + d.identityRegistry;
  }).catch(function () {});
