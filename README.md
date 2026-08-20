# Markdown Previewer

Native macOS Markdown previewer built with SwiftUI and WebKit. It is designed for large local files and keeps the interface intentionally quiet: open files as tabs in the left sidebar, preview in the center, and jump through headings from the right-side outline.

## What it supports

- Basic Markdown rendering through `Down` and `cmark`
- Mermaid diagrams from fenced code blocks tagged `mermaid`
- Tab deduplication: opening an already-open file focuses the existing tab
- Three-pane layout with resizable sidebar and TOC pane
- Light and dark presentation that follows the macOS system appearance, diagrams included
- Finder reveal, reload, and file-open commands
- Relative local file navigation for Markdown links

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
