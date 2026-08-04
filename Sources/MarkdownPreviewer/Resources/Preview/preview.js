(function () {
  const tocHandler = window.webkit?.messageHandlers?.tableOfContents;
  const scrollHandler = window.webkit?.messageHandlers?.scrollState;
  const highlightAliases = new Map([
    ["react", "jsx"],
    ["javascriptreact", "jsx"],
    ["typescriptreact", "tsx"],
    ["shell", "bash"],
  ]);

  // Warm-paper palette mirroring preview.css, so diagrams sit on the same
  // surface as the prose instead of arriving in Mermaid's grey default theme.
  const mermaidTheme = {
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
    fontFamily: '"Iowan Old Style", "Palatino Linotype", "Songti SC", serif',
    fontSize: "14px",
  };

  const slugCounts = new Map();
  let scrollScheduled = false;

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

  function nextFrame() {
    return new Promise((resolve) => {
      window.requestAnimationFrame(() => {
        resolve();
      });
    });
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
        await nextFrame();
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

  function firstTextNode(root) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);

    while (walker.nextNode()) {
      if ((walker.currentNode.nodeValue || "").trim()) {
        return walker.currentNode;
      }
    }

    return null;
  }

  /*
   * cmark has no GFM task-list extension, so "- [ ] item" arrives as literal
   * "[ ] item" text. Rewrite it into a styled checkbox here rather than
   * teaching the Markdown preprocessor about list structure.
   */
  function decorateTaskLists() {
    document.querySelectorAll("li").forEach((item) => {
      const textNode = firstTextNode(item);
      if (!textNode) {
        return;
      }

      const match = /^\s*\[([ xX])\]\s+/.exec(textNode.nodeValue || "");
      if (!match) {
        return;
      }

      textNode.nodeValue = (textNode.nodeValue || "").slice(match[0].length);
      item.classList.add("task-item");

      if (match[1] !== " ") {
        item.classList.add("is-done");
      }

      const box = document.createElement("span");
      box.className = "task-box";
      box.setAttribute("aria-hidden", "true");
      item.insertBefore(box, item.firstChild);
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

  function reportScroll() {
    if (scrollScheduled) {
      return;
    }

    scrollScheduled = true;
    window.requestAnimationFrame(() => {
      scrollScheduled = false;
      scrollHandler?.postMessage(String(window.scrollY || 0));
    });
  }

  function setupScrollTracking() {
    window.addEventListener("scroll", reportScroll, { passive: true });
  }

  async function renderMermaid(nodes) {
    if (!nodes.length || !window.mermaid) {
      return;
    }

    window.mermaid.initialize({
      startOnLoad: false,
      securityLevel: "loose",
      theme: "base",
      themeVariables: mermaidTheme,
      flowchart: {
        useMaxWidth: true,
      },
    });

    try {
      await window.mermaid.run({ nodes });
    } catch (error) {
      nodes.forEach((node) => {
        node.classList.add("mermaid-failed");
      });
    }
  }

  async function boot() {
    const mermaidNodes = replaceMermaidBlocks();
    wrapTables();
    decorateTaskLists();
    buildTableOfContents();
    setupScrollTracking();
    await highlightCodeBlocks();
    await renderMermaid(mermaidNodes);
    reportScroll();
  }

  window.markdownPreview = {
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

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => {
      void boot();
    }, { once: true });
  } else {
    void boot();
  }
})();
