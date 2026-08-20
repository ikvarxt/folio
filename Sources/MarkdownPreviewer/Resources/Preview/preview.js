(function () {
  const tocHandler = window.webkit?.messageHandlers?.tableOfContents;
  const scrollHandler = window.webkit?.messageHandlers?.scrollState;
  const highlightAliases = new Map([
    ["react", "jsx"],
    ["javascriptreact", "jsx"],
    ["typescriptreact", "tsx"],
    ["shell", "bash"],
  ]);

  const mermaidTypography = {
    fontFamily: '"Iowan Old Style", "Palatino Linotype", "Songti SC", serif',
    fontSize: "14px",
  };

  /*
   * Warm-paper palettes mirroring preview.css, so diagrams sit on the same
   * surface as the prose instead of arriving in Mermaid's grey default theme.
   * Mermaid derives shades from these with a colour library that does not parse
   * oklch(), so they stay hex here rather than reading the CSS custom properties.
   */
  const mermaidPalettes = {
    light: {
      ...mermaidTypography,
      background: "#fdfcf8",
      primaryColor: "#f6f1e6",
      primaryTextColor: "#362f27",
      primaryBorderColor: "#c9bda8",
      secondaryColor: "#f1ece0",
      tertiaryColor: "#faf7f0",
      mainBkg: "#f6f1e6",
      nodeBorder: "#c9bda8",
      clusterBkg: "#faf7f0",
      clusterBorder: "#d8cfbe",
      lineColor: "#9d8b71",
      textColor: "#362f27",
      edgeLabelBackground: "#fdfcf8",
    },
    dark: {
      ...mermaidTypography,
      background: "#29251f",
      primaryColor: "#342e26",
      primaryTextColor: "#ece5da",
      primaryBorderColor: "#5b5042",
      secondaryColor: "#3b3429",
      tertiaryColor: "#2f2a23",
      mainBkg: "#342e26",
      nodeBorder: "#5b5042",
      clusterBkg: "#2f2a23",
      clusterBorder: "#4a4136",
      lineColor: "#9b8b74",
      textColor: "#ece5da",
      edgeLabelBackground: "#29251f",
    },
  };

  const darkSchemeQuery = window.matchMedia("(prefers-color-scheme: dark)");

  const activeHeadingHandler = window.webkit?.messageHandlers?.activeHeading;

  const slugCounts = new Map();
  let scrollScheduled = false;
  let headingIndex = [];
  let lastReportedHeadingID = null;
  let isScrollTrackingBound = false;
  let configuredMermaidScheme = null;
  let hostScheme = null;
  let cachedAnchorOffset = null;

  function slugify(input) {
    return (input || "")
      .toLowerCase()
      .trim()
      .replace(/[^\w\u4e00-\u9fff\s-]/g, "")
      .replace(/\s+/g, "-")
      .replace(/-+/g, "-")
      .replace(/^-|-$/g, "") || "section";
  }

  function uniqueSlug(base) {
    const count = slugCounts.get(base) || 0;
    slugCounts.set(base, count + 1);
    return count === 0 ? base : `${base}-${count + 1}`;
  }

  function replaceMermaidBlocks() {
    const nodes = [];
    const mermaidBlocks = document.querySelectorAll("pre > code[class*='language-mermaid']");

    mermaidBlocks.forEach((block) => {
      const pre = block.parentElement;
      if (!pre) {
        return;
      }

      const wrapper = document.createElement("div");
      wrapper.className = "mermaid diagram-surface";
      wrapper.textContent = block.textContent || "";
      // Mermaid overwrites the node with baked SVG, colours included, so the
      // source has to be kept to redraw the diagram in the other palette.
      wrapper.dataset.mermaidSource = wrapper.textContent;
      pre.replaceWith(wrapper);
      nodes.push(wrapper);
    });

    return nodes;
  }

  function extractLanguageClass(block) {
    return Array.from(block.classList).find((className) => (
      className.startsWith("language-") || className.startsWith("lang-")
    ));
  }

  function resolveHighlightLanguage(block) {
    const languageClass = extractLanguageClass(block);
    if (!languageClass) {
      return null;
    }

    const rawLanguage = languageClass
      .replace(/^language-/, "")
      .replace(/^lang-/, "")
      .toLowerCase();

    return highlightAliases.get(rawLanguage) || rawLanguage;
  }

  /*
   * Yielding exists only to keep long highlight passes from janking the frame
   * being painted. While the view is occluded there is no frame to protect, and
   * both clocks become unreliable there: requestAnimationFrame stops firing
   * entirely and timers get throttled hard. So do not yield at all when hidden,
   * and keep a timer backstop for the visible case.
   */
  function yieldToRenderer() {
    if (document.hidden) {
      return Promise.resolve();
    }

    return new Promise((resolve) => {
      let hasSettled = false;

      const settle = () => {
        if (!hasSettled) {
          hasSettled = true;
          resolve();
        }
      };

      window.requestAnimationFrame(settle);
      window.setTimeout(settle, 32);
    });
  }

  /// Resolves with `fallback` if `promise` has not settled in time.
  function withTimeout(promise, milliseconds, fallback) {
    return Promise.race([
      promise,
      new Promise((resolve) => {
        window.setTimeout(() => resolve(fallback), milliseconds);
      }),
    ]);
  }

  async function highlightCodeBlocks() {
    const blocks = Array.from(document.querySelectorAll("pre > code[class*='language-'], pre > code[class*='lang-']"));

    for (const [index, block] of blocks.entries()) {
      const language = resolveHighlightLanguage(block);
      if (!language || language === "mermaid") {
        continue;
      }

      // Label every tagged fence, even one hljs cannot tokenise.
      if (block.parentElement) {
        block.parentElement.dataset.lang = language;
      }

      if (!window.hljs || !window.hljs.getLanguage(language)) {
        continue;
      }

      block.classList.add(`language-${language}`);
      delete block.dataset.highlighted;

      try {
        window.hljs.highlightElement(block);
      } catch (error) {
        continue;
      }

      if (blocks.length > 6 && index % 3 === 2) {
        await yieldToRenderer();
      }
    }
  }

  function wrapTables() {
    const tables = document.querySelectorAll("table");

    tables.forEach((table) => {
      if (table.closest(".table-scroll")) {
        return;
      }

      const scrollWrapper = document.createElement("div");
      scrollWrapper.className = "table-scroll";

      const frame = document.createElement("div");
      frame.className = "table-frame";

      table.replaceWith(scrollWrapper);
      scrollWrapper.appendChild(frame);
      frame.appendChild(table);
    });
  }

  function buildTableOfContents() {
    slugCounts.clear();

    const items = [];
    const headings = document.querySelectorAll("h1, h2, h3, h4, h5, h6");

    headings.forEach((heading) => {
      const title = heading.textContent?.trim() || "";
      if (!title) {
        return;
      }

      if (!heading.id) {
        heading.id = uniqueSlug(slugify(title));
      }

      items.push({
        id: heading.id,
        title,
        level: Number(heading.tagName.slice(1)),
      });
    });

    if (tocHandler) {
      tocHandler.postMessage(JSON.stringify(items));
    }
  }

  /*
   * Heading offsets, measured once per render. The scroll handler then only
   * does a scan over this array rather than touching layout on every frame.
   */
  function buildHeadingIndex() {
    headingIndex = Array.from(document.querySelectorAll("h1, h2, h3, h4, h5, h6"))
      .filter((heading) => heading.id)
      .map((heading) => ({
        id: heading.id,
        top: heading.getBoundingClientRect().top + (window.scrollY || 0),
      }));
  }

  /*
   * How far below the viewport top a heading may sit and still count as the one
   * being read. It has to cover `scroll-margin-top`, because jumping to a
   * heading from the outline deliberately parks it that far down: with a smaller
   * value the heading you just clicked sits below the line and the entry above
   * it wins instead. Read from CSS so the two cannot drift apart.
   */
  function activeHeadingSlack() {
    if (cachedAnchorOffset === null) {
      const raw = getComputedStyle(document.documentElement).getPropertyValue("--anchor-offset");
      const parsed = Number.parseFloat(raw);
      cachedAnchorOffset = Number.isFinite(parsed) ? parsed : 0;
    }

    return cachedAnchorOffset + 4;
  }

  /// Last heading at or above the top of the viewport.
  function headingAtViewportTop(slack) {
    const limit = (window.scrollY || 0) + (slack || 0);
    let found = null;

    for (const heading of headingIndex) {
      if (heading.top <= limit) {
        found = heading;
      } else {
        break;
      }
    }

    return found;
  }

  function isScrolledToBottom() {
    const doc = document.scrollingElement || document.documentElement;
    const maxScroll = doc.scrollHeight - window.innerHeight;
    return maxScroll > 0 && (window.scrollY || 0) >= maxScroll - 2;
  }

  function scrollRatio() {
    const doc = document.scrollingElement || document.documentElement;
    const maxScroll = Math.max(0, doc.scrollHeight - window.innerHeight);
    return maxScroll > 0 ? (window.scrollY || 0) / maxScroll : 0;
  }

  function reportScroll() {
    if (scrollScheduled) {
      return;
    }

    scrollScheduled = true;
    void yieldToRenderer().then(() => {
      scrollScheduled = false;
      scrollHandler?.postMessage(String(window.scrollY || 0));

      /*
       * A trailing section shorter than the viewport can never reach the top of
       * the screen, so at the bottom of the document the last heading wins.
       * Otherwise: last heading at or above the viewport top, with a few px of
       * slack so one scrolled flush to the top counts as active.
       */
      const active = isScrolledToBottom()
        ? headingIndex[headingIndex.length - 1]
        : (headingAtViewportTop(activeHeadingSlack()) || headingIndex[0]);
      const activeID = active ? active.id : "";

      if (activeID !== lastReportedHeadingID) {
        lastReportedHeadingID = activeID;
        activeHeadingHandler?.postMessage(activeID);
      }
    });
  }

  function setupScrollTracking() {
    if (isScrollTrackingBound) {
      return;
    }

    isScrollTrackingBound = true;
    window.addEventListener("scroll", reportScroll, { passive: true });
  }

  async function renderMermaid(nodes) {
    if (!nodes.length || !window.mermaid) {
      return;
    }

    // Configuration is global; only a scheme switch makes it stale.
    const scheme = currentScheme();

    if (configuredMermaidScheme !== scheme) {
      configuredMermaidScheme = scheme;
      window.mermaid.initialize({
        startOnLoad: false,
        securityLevel: "loose",
        theme: "base",
        themeVariables: mermaidPalettes[scheme],
        flowchart: {
          useMaxWidth: true,
        },
      });
    }

    try {
      await window.mermaid.run({ nodes });
    } catch (error) {
      nodes.forEach((node) => {
        node.classList.add("mermaid-failed");
      });
    }
  }

  /*
   * The host is the authority once it has spoken, because the media query alone
   * cannot be observed reliably: see applyColorScheme below.
   */
  function currentScheme() {
    return hostScheme || (darkSchemeQuery.matches ? "dark" : "light");
  }

  /*
   * Prose and code follow the system appearance through CSS alone. Diagrams
   * cannot: their colours are already inside the generated SVG, so they have to
   * be reset to source and drawn again.
   */
  async function redrawMermaidForScheme() {
    const nodes = Array.from(document.querySelectorAll(".mermaid[data-mermaid-source]"));

    nodes.forEach((node) => {
      node.removeAttribute("data-processed");
      node.classList.remove("mermaid-failed");
      node.textContent = node.dataset.mermaidSource || "";
    });

    await renderMermaid(nodes);
  }

  /// Everything that has to run over freshly inserted markup.
  async function runContentPasses() {
    const mermaidNodes = replaceMermaidBlocks();
    wrapTables();
    buildTableOfContents();
    await highlightCodeBlocks();
    await renderMermaid(mermaidNodes);
    buildHeadingIndex();
  }

  /*
   * Anchor on the heading at the top of the viewport rather than on a pixel
   * offset or a scroll ratio: when a reload adds or removes content above the
   * reading position, both of those drift, but the heading does not.
   */
  function captureReadingPosition() {
    const anchor = headingAtViewportTop(activeHeadingSlack());

    if (anchor) {
      return { id: anchor.id, delta: (window.scrollY || 0) - anchor.top };
    }

    return { ratio: scrollRatio() };
  }

  function restoreReadingPosition(position) {
    const root = document.documentElement;
    const previousBehavior = root.style.scrollBehavior;

    // `scroll-behavior: smooth` would animate a restore that must be instant.
    root.style.scrollBehavior = "auto";

    if (position.id) {
      const target = document.getElementById(position.id);

      if (target) {
        const top = target.getBoundingClientRect().top + (window.scrollY || 0);
        window.scrollTo({ top: Math.max(0, top + position.delta), behavior: "auto" });
        root.style.scrollBehavior = previousBehavior;
        return;
      }
    }

    const doc = document.scrollingElement || document.documentElement;
    const maxScroll = Math.max(0, doc.scrollHeight - window.innerHeight);
    window.scrollTo({ top: maxScroll * (position.ratio || 0), behavior: "auto" });
    root.style.scrollBehavior = previousBehavior;
  }

  async function boot() {
    setupScrollTracking();
    await runContentPasses();
    reportScroll();
  }

  window.markdownPreview = {
    /*
     * Swap the document body in place instead of reloading the page. A reload
     * white-flashes, drops the scroll position, and re-runs every vendored
     * script; this keeps the same page alive and only replaces its content.
     * Returns false so the host can fall back to a full load.
     */
    async replaceBody(bodyHTML) {
      const article = document.querySelector(".document");

      if (!article) {
        return false;
      }

      const position = captureReadingPosition();
      lastReportedHeadingID = null;
      article.innerHTML = bodyHTML;

      // The markup is already in the DOM. If a vendored renderer stalls, the
      // reader still gets the text rather than a preview stuck on old content.
      await withTimeout(runContentPasses(), 5000, undefined);
      restoreReadingPosition(position);
      reportScroll();

      return true;
    },
    /*
     * Called by the host on an appearance change, and the only signal that
     * arrives on every path: WebKit dispatches no matchMedia change event when
     * the appearance is inherited from the window rather than set on the web
     * view, which is exactly how a system-wide switch reaches this app.
     */
    applyColorScheme(isDark) {
      hostScheme = isDark ? "dark" : "light";

      if (configuredMermaidScheme === hostScheme) {
        return;
      }

      return redrawMermaidForScheme();
    },
    restoreScroll(position) {
      window.scrollTo({ top: Number(position) || 0, behavior: "auto" });
    },
    scrollToHeading(id) {
      const target = document.getElementById(id);
      if (!target) {
        return;
      }

      target.scrollIntoView({
        block: "start",
        inline: "nearest",
        behavior: "smooth",
      });
    },
  };

  /*
   * Backstop for the paths WebKit does notify — an appearance set directly on
   * the web view, or a future release that fixes the inherited case. Bound at
   * load rather than in boot(): the page outlives every document swap.
   */
  darkSchemeQuery.addEventListener("change", () => {
    if (configuredMermaidScheme === currentScheme()) {
      return;
    }

    void redrawMermaidForScheme();
  });

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => {
      void boot();
    }, { once: true });
  } else {
    void boot();
  }
})();
