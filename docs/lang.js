// 한국어/영어 전환. ?lang=en 이 있으면 그것을, 없으면 브라우저 언어를 따른다.
(function () {
  var param = new URLSearchParams(location.search).get("lang");
  var lang = param || ((navigator.language || "").toLowerCase().indexOf("ko") === 0 ? "ko" : "en");
  function apply(l) {
    document.documentElement.lang = l;
    document.querySelectorAll(".lang button").forEach(function (b) {
      b.setAttribute("aria-pressed", String(b.dataset.set === l));
    });
    document.querySelectorAll("nav a").forEach(function (a) {
      a.href = a.getAttribute("href").split("?")[0] + "?lang=" + l;
    });
  }
  document.addEventListener("DOMContentLoaded", function () {
    document.querySelectorAll(".lang button").forEach(function (b) {
      b.addEventListener("click", function () { apply(b.dataset.set); });
    });
    apply(lang === "en" ? "en" : "ko");
  });
})();
