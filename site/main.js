(function () {
  var links = window.MYKOS_LINKS || {};

  // Wire every buy button to its store link, or mark it "Coming soon".
  document.querySelectorAll("[data-link]").forEach(function (el) {
    var url = links[el.getAttribute("data-link")];
    if (url) {
      el.href = url;
      el.target = "_blank";
      el.rel = "noopener";
    } else {
      el.removeAttribute("href");
      el.classList.add("is-soon");
      el.setAttribute("aria-disabled", "true");
      el.textContent = "Coming soon";
    }
  });

  var social = document.getElementById("social-link");
  if (social) {
    if (links.social) {
      social.href = links.social;
      social.target = "_blank";
      social.rel = "noopener";
    } else {
      social.replaceWith(document.createTextNode("@mykosreward"));
    }
  }

  // No single word alone on the last line of a paragraph: tie the last two
  // words together. (CSS text-wrap: pretty does this too where supported.)
  document.querySelectorAll("main p:not(.one-line), main h3, main blockquote").forEach(function (el) {
    if (el.textContent.trim().split(/\s+/).length < 3) return; // two words may still need to wrap
    var walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT), nodes = [], n;
    while ((n = walker.nextNode())) nodes.push(n);
    var seenWord = false;
    for (var i = nodes.length - 1; i >= 0; i--) {
      var t = nodes[i].nodeValue;
      for (var k = t.length - 1; k >= 0; k--) {
        if (/\s/.test(t[k])) {
          if (seenWord) { nodes[i].nodeValue = t.slice(0, k) + "\u00a0" + t.slice(k + 1); return; }
        } else {
          seenWord = true;
        }
      }
    }
  });

  // Keep the mural still for visitors who asked for reduced motion.
  if (window.matchMedia && matchMedia("(prefers-reduced-motion: reduce)").matches) {
    document.querySelectorAll(".mural-video").forEach(function (v) { v.removeAttribute("autoplay"); v.pause(); });
  }

  var year = document.getElementById("year");
  if (year) year.textContent = new Date().getFullYear();

  // Share button: native share sheet where available, otherwise copy the link.
  var share = document.getElementById("share");
  var status = document.getElementById("share-status");
  if (share) {
    share.addEventListener("click", function () {
      var data = {
        title: "Myko's Reward: The Original Power",
        text: "It took an algorithm four seconds to decide she wasn't worth saving. You need to read this.",
        url: location.origin + location.pathname
      };
      if (navigator.share) {
        navigator.share(data).catch(function () {});
      } else if (navigator.clipboard) {
        navigator.clipboard.writeText(data.url).then(function () {
          status.textContent = "Link copied. Paste it to a friend.";
        }, function () {
          status.textContent = data.url;
        });
      } else {
        status.textContent = data.url;
      }
    });
  }
})();
