(function () {
  const slides = Array.from(document.querySelectorAll(".slide"));
  let i = Math.max(0, Math.min(slides.length - 1, (parseInt(location.hash.slice(1), 10) || 1) - 1));
  function fit() {
    const s = Math.min(window.innerWidth / 1280, window.innerHeight / 720);
    slides.forEach((el) => { el.style.transform = `translate(-50%, -50%) scale(${s})`; });
  }
  function show(n) {
    i = Math.max(0, Math.min(slides.length - 1, n));
    slides.forEach((el, k) => el.classList.toggle("on", k === i));
    document.getElementById("pos").textContent = `${i + 1} / ${slides.length}`;
    history.replaceState(null, "", `#${i + 1}`);
  }
  document.getElementById("prev").onclick = () => show(i - 1);
  document.getElementById("next").onclick = () => show(i + 1);
  document.addEventListener("keydown", (e) => {
    if (["ArrowRight", "PageDown", " "].includes(e.key)) { e.preventDefault(); show(i + 1); }
    if (["ArrowLeft", "PageUp"].includes(e.key)) { e.preventDefault(); show(i - 1); }
  });
  let x0 = null;
  document.addEventListener("touchstart", (e) => { x0 = e.touches[0].clientX; }, { passive: true });
  document.addEventListener("touchend", (e) => {
    if (x0 === null) return;
    const dx = e.changedTouches[0].clientX - x0;
    if (Math.abs(dx) > 40) show(i + (dx < 0 ? 1 : -1));
    x0 = null;
  });
  window.addEventListener("resize", fit);
  fit(); show(i);
  // tick the "live" item once the Monad deployment is published
  fetch("../monad-deploy.json", { cache: "no-store" }).then((r) => (r.ok ? r.json() : null)).then((d) => {
    if (d) document.getElementById("deck-deploy").classList.remove("todo");
  }).catch(() => {});
})();
