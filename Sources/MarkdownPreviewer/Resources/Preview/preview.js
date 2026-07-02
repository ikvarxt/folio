(function () {
  const tocHandler = window.webkit?.messageHandlers?.tableOfContents;
  const scrollHandler = window.webkit?.messageHandlers?.scrollState;

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

  async function renderMermaid() {
    const nodes = replaceMermaidBlocks();
    if (!nodes.length || !window.mermaid) {
      return;
    }

    window.mermaid.initialize({
      startOnLoad: false,
      securityLevel: "loose",
      theme: "neutral",
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
    wrapTables();
    buildTableOfContents();
    setupScrollTracking();
    await renderMermaid();
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
