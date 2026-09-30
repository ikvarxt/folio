# Markdown Previewer

Native macOS Markdown previewer built with SwiftUI and WebKit. Open files are tabs in the left sidebar, the preview sits in the center, and the right sidebar is an outline of the document's headings.

## What it supports

- GitHub Flavored Markdown through `swift-cmark-gfm`: tables, task lists, strikethrough, footnotes
- Syntax highlighting for fenced code blocks, via highlight.js
- Mermaid diagrams from fenced code blocks tagged `mermaid`
- Light and dark appearance that follows the system setting, diagrams included
- Local images referenced by relative path, inline or as blocks
- Relative links to other Markdown files open them as tabs
- Opening a file that is already open focuses its tab
- Resizable sidebars; zen mode (`⌘Z`) hides both
- Change detection: files edited on disk are flagged, `⌘R` reloads the changed ones and `⇧⌘R` reloads all; auto reload can be switched on from the toolbar
- Drag files into the window to open them; drop or paste (`⌘V`) text to preview it as a temporary document

## Build

```bash
./scripts/build-app.sh
```

The packaged app is emitted to:

`dist/MarkdownPreviewer.app`

## Run during development

```bash
./scripts/run-app.sh
```

You can also launch the binary directly with file paths:

```bash
swift run MarkdownPreviewer /path/to/file.md
```
