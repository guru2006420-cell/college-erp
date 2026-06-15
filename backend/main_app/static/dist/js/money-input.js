// Live thousands-grouping for whole-soʻm money inputs (marked [data-money]).
// The server strips the separators on submit (forms.GroupedNumberInput), so we
// only keep the displayed value grouped with commas as the admin types
// (e.g. "200000" -> "200,000"). Works on pre-filled values too.
(function () {
  function group(el) {
    var raw = (el.value || "").replace(/[^\d]/g, "");
    el.value = raw ? Number(raw).toLocaleString("en-US") : "";
  }

  function init() {
    document.querySelectorAll("input[data-money]").forEach(function (el) {
      if (el.dataset.moneyBound) return;
      el.dataset.moneyBound = "1";
      group(el); // format any value the server pre-filled
      el.addEventListener("input", function () {
        var start = el.selectionStart;
        var before = el.value.length;
        group(el);
        var after = el.value.length;
        if (start !== null) {
          el.selectionStart = el.selectionEnd = Math.max(0, start + (after - before));
        }
      });
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
