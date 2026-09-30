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
    fontFamily: 'ui-serif, "Iowan Old Style", "Songti SC", serif',
    fontSize: "14px",
  };

  /*
   * The preview.css tokens restated as literals: Mermaid derives its shades
   * with a colour library at initialize time, before any CSS variable resolves.
   */
  const mermaidPalettes = {
    light: {
      ...mermaidTypography,
      background: "#fcfbf8",
      primaryColor: "#f4f2ed",
      primaryTextColor: "#26231f",
      primaryBorderColor: "#cfc8bc",
      secondaryColor: "#f4f2ed",
      tertiaryColor: "#fcfbf8",
      mainBkg: "#f4f2ed",
      nodeBorder: "#cfc8bc",
      clusterBkg: "#fcfbf8",
      clusterBorder: "#e6e2da",
      lineColor: "#8a8378",
      textColor: "#26231f",
      edgeLabelBackground: "#fcfbf8",
    },
    dark: {
      ...mermaidTypography,
      background: "#1c1b19",
      primaryColor: "#252320",
      primaryTextColor: "#e6e1d8",
      primaryBorderColor: "#4a463f",
      secondaryColor: "#252320",
      tertiaryColor: "#1c1b19",
      mainBkg: "#252320",
      nodeBorder: "#4a463f",
      clusterBkg: "#1c1b19",
      clusterBorder: "#33302b",
      lineColor: "#8c857a",
      textColor: "#e6e1d8",
      edgeLabelBackground: "#1c1b19",
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
    lightbox.close();
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

  /*
   * Full-window viewer for images and diagrams. Zoom resizes the element
   * instead of scaling it with a transform, so SVG stays vector-sharp and a
   * raster image is resampled rather than stretched from a cached layer.
   */
  const lightbox = (() => {
    const margin = 48;
    let overlay = null;
    let figure = null;
    let natural = { width: 1, height: 1 };
    let isRaster = false;
    let fit = 1;
    let scale = 1;
    let origin = { x: 0, y: 0 };
    let drag = null;
    let gestureStartScale = 1;

    function zoomable(target) {
      if (!(target instanceof Element)) {
        return null;
      }

      const svg = target.closest(".mermaid:not(.mermaid-failed) svg");
      if (svg) {
        return svg;
      }

      // A linked image keeps behaving as a link.
      const image = target.closest(".document img");
      return image && !image.closest("a") ? image : null;
    }

    function measure(source) {
      if (source instanceof HTMLImageElement) {
        return { width: source.naturalWidth || source.width, height: source.naturalHeight || source.height };
      }

      const box = source.viewBox && source.viewBox.baseVal;
      if (box && box.width && box.height) {
        return { width: box.width, height: box.height };
      }

      const rect = source.getBoundingClientRect();
      return { width: rect.width, height: rect.height };
    }

    function open(source) {
      close();

      natural = measure(source);
      if (!natural.width || !natural.height) {
        return;
      }

      isRaster = source instanceof HTMLImageElement && !/\.svg(\?|#|$)/i.test(source.currentSrc || source.src);

      figure = source.cloneNode(true);
      figure.removeAttribute("style");
      figure.removeAttribute("width");
      figure.removeAttribute("height");
      figure.classList.add("lightbox-figure");

      const closeButton = document.createElement("button");
      closeButton.className = "lightbox-close";
      closeButton.type = "button";
      closeButton.setAttribute("aria-label", "Close");
      closeButton.textContent = "×";
      closeButton.addEventListener("click", close);

      overlay = document.createElement("div");
      overlay.className = "lightbox";
      overlay.setAttribute("role", "dialog");
      overlay.setAttribute("aria-modal", "true");
      overlay.append(figure, closeButton);
      document.body.append(overlay);
      document.documentElement.classList.add("lightbox-open");

      overlay.addEventListener("wheel", onWheel, { passive: false });
      overlay.addEventListener("gesturestart", onGestureStart);
      overlay.addEventListener("gesturechange", onGestureChange);
      overlay.addEventListener("pointerdown", onPointerDown);
      overlay.addEventListener("dblclick", onDoubleClick);
      window.addEventListener("keydown", onKeyDown, true);
      window.addEventListener("resize", reset);

      reset();
      requestAnimationFrame(() => overlay?.classList.add("is-visible"));
    }

    function close() {
      if (!overlay) {
        return;
      }

      window.removeEventListener("keydown", onKeyDown, true);
      window.removeEventListener("resize", reset);
      document.documentElement.classList.remove("lightbox-open");
      overlay.remove();
      overlay = null;
      figure = null;
      drag = null;
    }

    function reset() {
      const width = window.innerWidth - margin * 2;
      const height = window.innerHeight - margin * 2;
      fit = Math.min(width / natural.width, height / natural.height);

      // Upscaling a small bitmap past 2x only magnifies its blur.
      if (isRaster) {
        fit = Math.min(fit, 2);
      }

      scale = fit;
      origin = {
        x: (window.innerWidth - natural.width * scale) / 2,
        y: (window.innerHeight - natural.height * scale) / 2,
      };
      apply();
    }

    function maxScale() {
      return Math.max(fit * 8, isRaster ? 4 : 1);
    }

    // Content smaller than the window stays centred; larger content can pan
    // edge to edge but never leaves a gap on either side.
    function clampAxis(offset, size, viewport) {
      if (size <= viewport) {
        return (viewport - size) / 2;
      }

      return Math.min(0, Math.max(viewport - size, offset));
    }

    function apply() {
      if (!figure) {
        return;
      }

      const width = natural.width * scale;
      const height = natural.height * scale;
      origin.x = clampAxis(origin.x, width, window.innerWidth);
      origin.y = clampAxis(origin.y, height, window.innerHeight);

      figure.style.width = `${width}px`;
      figure.style.height = `${height}px`;
      figure.style.transform = `translate(${origin.x}px, ${origin.y}px)`;
      overlay.classList.toggle("is-zoomed", scale > fit * 1.01);
    }

    function zoomTo(next, pointX = window.innerWidth / 2, pointY = window.innerHeight / 2) {
      const clamped = Math.min(maxScale(), Math.max(fit, next));
      const ratio = clamped / scale;
      origin.x = pointX - (pointX - origin.x) * ratio;
      origin.y = pointY - (pointY - origin.y) * ratio;
      scale = clamped;
      apply();
    }

    // Trackpad pinch arrives as a ctrl-modified wheel; a plain wheel pans.
    function onWheel(event) {
      event.preventDefault();

      if (event.ctrlKey || event.metaKey) {
        zoomTo(scale * Math.exp(-event.deltaY * 0.01), event.clientX, event.clientY);
        return;
      }

      origin.x -= event.deltaX;
      origin.y -= event.deltaY;
      apply();
    }

    // WebKit's own pinch events, which it sends instead of ctrl-wheel.
    function onGestureStart(event) {
      event.preventDefault();
      gestureStartScale = scale;
    }

    function onGestureChange(event) {
      event.preventDefault();
      zoomTo(gestureStartScale * event.scale, event.clientX, event.clientY);
    }

    function onPointerDown(event) {
      if (event.button !== 0 || event.target.closest(".lightbox-close")) {
        return;
      }

      drag = { x: event.clientX, y: event.clientY, originX: origin.x, originY: origin.y, moved: false };
      overlay.setPointerCapture(event.pointerId);
      overlay.addEventListener("pointermove", onPointerMove);
      overlay.addEventListener("pointerup", onPointerUp, { once: true });
    }

    function onPointerMove(event) {
      if (!drag) {
        return;
      }

      const dx = event.clientX - drag.x;
      const dy = event.clientY - drag.y;

      if (!drag.moved && Math.hypot(dx, dy) < 4) {
        return;
      }

      drag.moved = true;
      overlay.classList.add("is-dragging");
      origin.x = drag.originX + dx;
      origin.y = drag.originY + dy;
      apply();
    }

    function onPointerUp(event) {
      overlay?.removeEventListener("pointermove", onPointerMove);
      overlay?.classList.remove("is-dragging");

      const wasClick = drag && !drag.moved;
      drag = null;

      if (wasClick && event.target === overlay) {
        close();
      }
    }

    function onDoubleClick(event) {
      if (event.target !== figure && !figure?.contains(event.target)) {
        return;
      }

      if (scale > fit * 1.01) {
        reset();
      } else {
        zoomTo(isRaster ? Math.max(1, fit * 2) : fit * 2.5, event.clientX, event.clientY);
      }
    }

    function onKeyDown(event) {
      const handled = {
        Escape: close,
        "=": () => zoomTo(scale * 1.25),
        "+": () => zoomTo(scale * 1.25),
        "-": () => zoomTo(scale / 1.25),
        "0": reset,
      }[event.key];

      if (handled && !event.metaKey) {
        event.preventDefault();
        event.stopPropagation();
        handled();
      }
    }

    document.addEventListener("click", (event) => {
      if (overlay) {
        return;
      }

      const source = zoomable(event.target);
      if (source) {
        event.preventDefault();
        open(source);
      }
    });

    return { close };
  })();

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

      lightbox.close();
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
