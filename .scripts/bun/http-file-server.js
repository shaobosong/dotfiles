#!/usr/bin/env bun

import { mkdtemp, mkdir, readdir, realpath, rm, stat, symlink, writeFile } from "node:fs/promises";
import { realpathSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, extname, isAbsolute, join, relative, resolve } from "node:path";

const DEFAULT_CONFIG = Object.freeze({
  host: "0.0.0.0",
  port: 3000,
  root: process.cwd(),
  runTests: false,
});

const TEXT_FILE_EXTENSIONS = new Set([
  ".txt", ".text", ".md", ".markdown", ".rst", ".adoc", ".asciidoc", ".log",
  ".json", ".jsonl", ".ndjson", ".xml", ".xsd", ".yaml", ".yml", ".toml", ".ini", ".cfg", ".conf", ".properties", ".env", ".csv", ".tsv",
  ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx",
  ".css", ".scss", ".less",
  ".html", ".htm", ".svg",
  ".sh", ".bash", ".zsh", ".fish", ".ps1", ".bat", ".cmd",
  ".py", ".go", ".rs", ".java", ".kt", ".c", ".cc", ".cpp", ".h", ".hpp",
  ".sql", ".proto", ".graphql", ".gql", ".diff", ".patch", ".srt", ".vtt",
]);

const TEXT_FILE_NAMES = new Set([
  "dockerfile", "makefile", "cmakelists.txt",
  ".dockerignore", ".gitignore", ".gitattributes", ".editorconfig",
  ".npmrc", ".nvmrc", ".prettierrc", ".eslintrc",
  "license", "copying", "readme", "changelog",
]);

const NON_DOWNLOAD_TEXT_EXTENSIONS = new Set([
  ".html", ".htm",
]);

const IMAGE_PREVIEW_EXTENSIONS = new Set([
  ".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".ico", ".avif",
]);

const PREVIEW_TEXT_LIMIT_BYTES = 256 * 1024;
const PREVIEW_TEXT_LIMIT_CHARS = 200000;
const PREVIEW_TEXT_LIMIT_MESSAGE = "Text preview is limited to 256 KB. Use view/download for full content.";

function parsePort(value, source) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0 || parsed > 65535) {
    throw new Error(`Invalid ${source}: ${value ?? ""}. Expected integer in range 1-65535.`);
  }
  return parsed;
}

function isPathInside(baseDir, targetPath) {
  const rel = relative(baseDir, targetPath);
  return rel === "" || (!rel.startsWith("..") && !isAbsolute(rel));
}

function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function safeResolvePath(rootDir, pathname) {
  const decodedPath = (() => {
    try {
      return decodeURIComponent(pathname);
    } catch {
      return null;
    }
  })();

  if (decodedPath == null) return null;

  const targetPath = resolve(rootDir, `.${decodedPath}`);
  if (!isPathInside(rootDir, targetPath)) {
    return null;
  }
  return targetPath;
}

function isTextLikeByName(fileName) {
  if (!fileName) return false;
  const normalized = basename(fileName).toLowerCase();
  if (!normalized) return false;
  if (TEXT_FILE_NAMES.has(normalized)) return true;
  const ext = extname(normalized);
  return TEXT_FILE_EXTENSIONS.has(ext);
}

function isForceDownloadTextByName(fileName) {
  if (!isTextLikeByName(fileName)) return false;
  const ext = extname(basename(fileName).toLowerCase());
  return !NON_DOWNLOAD_TEXT_EXTENSIONS.has(ext);
}

function normalizeMimeType(mime) {
  if (!mime) return "";
  return mime.toLowerCase().split(";")[0].trim();
}

function resolveContentType(fileType, fileName) {
  const normalized = normalizeMimeType(fileType);
  if ((normalized === "" || normalized === "application/octet-stream") && isTextLikeByName(fileName)) {
    return "text/plain; charset=utf-8";
  }
  return fileType || "";
}

function shouldForceDownloadByMime(mime, fileName = "") {
  if (mime) {
    const normalized = normalizeMimeType(mime);
    if (normalized.startsWith("text/") && !normalized.startsWith("text/html")) {
      return true;
    }
    if (
      normalized === "application/json" ||
      normalized === "application/xml" ||
      normalized.endsWith("+json") ||
      normalized.endsWith("+xml")
    ) {
      return true;
    }
  }
  if (isForceDownloadTextByName(fileName)) return true;
  return false;
}

function buildContentDisposition(dispositionType, filename) {
  const sanitized = String(filename)
    .replace(/[\u0000-\u001F\u007F]/g, "_") || "download";
  const escaped = sanitized
    .replaceAll("\\", "\\\\")
    .replaceAll('"', '\\"');
  return `${dispositionType}; filename="${escaped}"; filename*=UTF-8''${encodeURIComponent(sanitized)}`;
}

function formatBytes(bytes) {
  if (!Number.isFinite(bytes) || bytes < 0) return "-";
  if (bytes < 1024) return `${bytes} B`;
  const units = ["KB", "MB", "GB", "TB"];
  let size = bytes / 1024;
  let idx = 0;
  while (size >= 1024 && idx < units.length - 1) {
    size /= 1024;
    idx += 1;
  }
  return `${size.toFixed(size < 10 ? 1 : 0)} ${units[idx]}`;
}

function formatTimestamp(ms) {
  if (!Number.isFinite(ms) || ms <= 0) return "-";
  const date = new Date(ms);
  if (Number.isNaN(date.getTime())) return "-";
  const pad2 = (value) => String(value).padStart(2, "0");
  const formatOffset = (value) => {
    const totalMinutes = -value.getTimezoneOffset();
    const sign = totalMinutes >= 0 ? "+" : "-";
    const absMinutes = Math.abs(totalMinutes);
    const offsetHours = pad2(Math.floor(absMinutes / 60));
    const offsetMinutes = pad2(absMinutes % 60);
    return `${sign}${offsetHours}:${offsetMinutes}`;
  };
  const year = date.getFullYear();
  const month = pad2(date.getMonth() + 1);
  const day = pad2(date.getDate());
  const hours = pad2(date.getHours());
  const minutes = pad2(date.getMinutes());
  const seconds = pad2(date.getSeconds());
  return `${year}-${month}-${day} ${hours}:${minutes}:${seconds} ${formatOffset(date)}`;
}

function renderNameIcon(isDirectory) {
  if (isDirectory) {
    return '<svg class="name-icon folder" viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path d="M1.5 4.5h4l1.2 1.5h7v6.5a1 1 0 0 1-1 1h-11a1 1 0 0 1-1-1z" fill="none" stroke="currentColor" stroke-width="1.2" stroke-linejoin="round"></path><path d="M1.5 4.5a1 1 0 0 1 1-1h2.7l1.2 1.5" fill="none" stroke="currentColor" stroke-width="1.2" stroke-linecap="round"></path></svg>';
  }
  return '<svg class="name-icon file" viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path d="M4 1.5h5l3 3v10a1 1 0 0 1-1 1h-7a1 1 0 0 1-1-1v-12a1 1 0 0 1 1-1z" fill="none" stroke="currentColor" stroke-width="1.2" stroke-linejoin="round"></path><path d="M9 1.5v3h3" fill="none" stroke="currentColor" stroke-width="1.2" stroke-linejoin="round"></path></svg>';
}

function isTextPreviewMime(mime) {
  if (!mime) return false;
  const normalized = normalizeMimeType(mime);
  if (normalized.startsWith("text/")) return true;
  if (
    normalized === "application/json" ||
    normalized === "application/xml" ||
    normalized === "application/javascript" ||
    normalized === "application/typescript" ||
    normalized.endsWith("+json") ||
    normalized.endsWith("+xml")
  ) {
    return true;
  }
  return false;
}

function isImagePreviewMime(mime) {
  if (!mime) return false;
  return normalizeMimeType(mime).startsWith("image/");
}

function getPreviewKind(mime, fileName) {
  if (isImagePreviewMime(mime)) return "image";
  if (isTextPreviewMime(mime)) return "text";
  const ext = extname(fileName).toLowerCase();
  if (IMAGE_PREVIEW_EXTENSIONS.has(ext)) return "image";
  if (isTextLikeByName(fileName)) return "text";
  return "none";
}

function buildIndexPathHtml(urlPath) {
  const parts = urlPath
    .split("/")
    .filter(Boolean)
    .map((segment) => {
      try {
        return decodeURIComponent(segment);
      } catch {
        return segment;
      }
    });

  if (parts.length === 0) {
    return '<span class="index-path-current">root</span>';
  }

  const crumbs = ['<a class="index-path-link" href="/">root</a>'];
  let currentHref = "/";
  for (let i = 0; i < parts.length; i += 1) {
    const segment = parts[i];
    currentHref += `${encodeURIComponent(segment)}/`;
    if (i === parts.length - 1) {
      crumbs.push(`<span class="index-sep">/</span><span class="index-path-current">${escapeHtml(segment)}</span>`);
    } else {
      crumbs.push(`<span class="index-sep">/</span><a class="index-path-link" href="${currentHref}">${escapeHtml(segment)}</a>`);
    }
  }
  return crumbs.join("");
}

function createDirectoryHtml(urlPath, items) {
  const sorted = [...items].sort((a, b) => {
    if (a.isDirectory && !b.isDirectory) return -1;
    if (!a.isDirectory && b.isDirectory) return 1;
    return a.name.localeCompare(b.name);
  });

  const rows = sorted
    .map((item) => {
      const actionLinks = [];
      const nameHref = item.isDirectory ? item.href : (item.downloadHref || item.href);
      if (item.previewHref) actionLinks.push(`<a class="preview-link" href="${item.previewHref}">preview</a>`);
      if (item.viewHref) actionLinks.push(`<a href="${item.viewHref}">view</a>`);
      const action = actionLinks.length > 0
        ? `<span class="action-links">${actionLinks.join('<span class="sep muted">|</span>')}</span>`
        : '<span class="muted">-</span>';
      return `<tr data-group="${item.groupSort}" data-preview-kind="${item.previewKind}" data-preview-url="${escapeHtml(item.previewHref || "")}" data-name="${escapeHtml(item.name)}" data-size-label="${escapeHtml(item.sizeLabel)}" data-modified-label="${escapeHtml(item.modifiedLabel)}" data-mime="${escapeHtml(item.mime || "")}">
  <td class="name" data-sort="${escapeHtml(item.sortName)}"><a class="name-link" href="${escapeHtml(nameHref)}">${renderNameIcon(item.isDirectory)}<span class="name-text">${escapeHtml(item.name)}</span></a></td>
  <td class="size" data-sort="${item.sizeSort}">${escapeHtml(item.sizeLabel)}</td>
  <td class="modified" data-sort="${item.modifiedSort}">${escapeHtml(item.modifiedLabel)}</td>
  <td class="action">${action}</td>
</tr>`;
    })
    .join("");

  const parent = urlPath === "/"
    ? ""
    : `<tr data-group="-1" data-preview-kind="none" data-preview-url="" data-name="../" data-size-label="-" data-modified-label="-" data-mime="">
  <td class="name" data-sort=""><a class="name-link" href="../">${renderNameIcon(true)}<span class="name-text">../</span></a></td>
  <td class="size" data-sort="-1">-</td>
  <td class="modified" data-sort="0">-</td>
  <td class="action"><span class="muted">-</span></td>
</tr>`;
  const indexPath = buildIndexPathHtml(urlPath);

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Index of ${escapeHtml(urlPath)}</title>
  <style>
    :root { --fg: #111827; --muted: #6b7280; --border: #e5e7eb; --bg: #f8fafc; --card: #ffffff; --link: #0b57d0; }
    html { overflow-y: scroll; scrollbar-gutter: stable; }
    *, *::before, *::after { box-sizing: border-box; }
    body { font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, sans-serif; margin: 0; color: var(--fg); background: var(--bg); min-height: 100vh; overflow-x: hidden; }
    .wrap { width: 100%; max-width: 1100px; margin: 0 auto; padding: 1rem; }
    .index-title { font-size: 1.25rem; margin: 0 0 0.85rem; display: flex; flex-wrap: wrap; align-items: baseline; gap: 0.35rem; font-weight: 700; color: var(--fg); }
    .index-path { display: inline-flex; flex-wrap: wrap; align-items: baseline; gap: 0.25rem; min-width: 0; color: inherit; font-weight: inherit; }
    .index-path-link { color: var(--link); text-decoration: none; font-weight: inherit; }
    .index-path-link:hover { text-decoration: none; }
    .index-sep { opacity: 1; color: inherit; font-weight: inherit; }
    .index-path-current { color: inherit; font-weight: inherit; overflow-wrap: anywhere; word-break: break-word; }
    .toolbar { display: flex; flex-wrap: wrap; gap: 0.75rem; align-items: center; margin-bottom: 0.85rem; }
    .toolbar > * { min-width: 0; }
    .search-wrap { position: relative; flex: 1 1 240px; max-width: 420px; min-width: 0; }
    .search { width: 100%; border: 1px solid var(--border); border-radius: 8px; padding: 0.45rem 2.2rem 0.45rem 0.65rem; background: #fff; color: var(--fg); }
    .search::-webkit-search-cancel-button { -webkit-appearance: none; appearance: none; display: none; }
    .search::placeholder { color: transparent; }
    .search-ghost { position: absolute; left: 0.65rem; top: 50%; transform: translateY(-50%); display: inline-flex; align-items: center; gap: 0.35rem; color: var(--muted); font-size: 0.9rem; pointer-events: none; }
    .search:focus + .search-ghost,
    .search:not(:placeholder-shown) + .search-ghost { opacity: 0; }
    .search-kbd { width: 1rem; height: 1rem; font-size: 0.72rem; color: inherit; vertical-align: text-bottom; background: transparent; border: 1px solid #9ca3af; border-radius: 4px; box-shadow: none; justify-content: center; align-items: center; padding: 0; line-height: 1; display: inline-grid; }
    .search-clear { position: absolute; right: 0.5rem; top: 50%; transform: translateY(-50%); width: 1.3rem; height: 1.3rem; border: 1px solid #cbd5e1; border-radius: 999px; background: #fff; color: #64748b; padding: 0; line-height: 1; display: inline-flex; align-items: center; justify-content: center; cursor: pointer; }
    .search-clear:hover { background: #f1f5f9; border-color: #94a3b8; color: #334155; }
    .search-clear[hidden] { display: none; }
    .search-clear:focus-visible { outline: 2px solid #93c5fd; outline-offset: 1px; }
    .table-wrap { width: 100%; border: 1px solid var(--border); border-radius: 10px; overflow-x: auto; overflow-y: hidden; background: var(--card); -webkit-overflow-scrolling: touch; }
    table { border-collapse: collapse; width: 100%; min-width: 560px; table-layout: auto; }
    th, td { text-align: left; padding: 0.7rem 0.85rem; border-bottom: 1px solid var(--border); white-space: nowrap; vertical-align: top; }
    th { font-weight: 600; color: var(--muted); background: #f9fafb; }
    tr:last-child td { border-bottom: none; }
    th.name, td.name { white-space: normal; width: 100%; min-width: 14rem; }
    td.name .name-link { display: flex; align-items: flex-start; gap: 0.5rem; min-width: 0; }
    td.name .name-text { min-width: 0; overflow-wrap: anywhere; word-break: break-word; }
    .name-icon { width: 1rem; height: 1rem; flex: 0 0 auto; margin-top: 0.08rem; color: #64748b; }
    .name-icon.folder { color: #b45309; }
    th.size, td.size { width: 7.5rem; color: var(--muted); font-variant-numeric: tabular-nums; text-align: right; }
    th.modified, td.modified { width: 12rem; color: var(--muted); font-variant-numeric: tabular-nums; }
    th.action, td.action { width: 1%; white-space: nowrap; padding-right: 1.1rem; text-align: left; }
    .action-links { display: inline-flex; align-items: center; gap: 0.35rem; }
    .action-links .sep { opacity: 0.75; }
    tr.preview-active td { background: #f7fbff; }
    .preview-drawer { position: fixed; top: 1rem; right: 1rem; width: min(34rem, calc(100vw - 1.5rem)); max-width: 34rem; height: calc(100vh - 2rem); max-height: calc(100vh - 2rem); z-index: 50; border: 1px solid var(--border); border-radius: 12px; background: var(--card); box-shadow: 0 14px 42px rgba(15, 23, 42, 0.22); display: flex; flex-direction: column; transform: translateX(calc(100% + 1rem)); opacity: 0; pointer-events: none; transition: transform 0.2s ease, opacity 0.2s ease; }
    .preview-drawer.open { transform: translateX(0); opacity: 1; pointer-events: auto; }
    .preview-head { display: flex; align-items: center; justify-content: space-between; gap: 0.5rem; padding: 0.75rem 0.85rem; border-bottom: 1px solid var(--border); }
    .preview-title { margin: 0; font-size: 0.98rem; }
    .preview-actions { display: inline-flex; align-items: center; gap: 0.4rem; }
    .preview-btn { appearance: none; border: 1px solid var(--border); border-radius: 7px; background: #fff; color: var(--fg); font: inherit; line-height: 1; width: 2rem; height: 2rem; padding: 0; display: inline-flex; align-items: center; justify-content: center; cursor: pointer; }
    .preview-btn:hover { background: #f8fafc; }
    .preview-btn:disabled { opacity: 0.52; cursor: not-allowed; }
    .preview-btn svg { width: 1rem; height: 1rem; fill: none; stroke: currentColor; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; }
    .preview-btn[data-copy-state="copied"] { color: #15803d; border-color: #86efac; background: #f0fdf4; }
    .preview-btn[data-copy-state="failed"] { color: #b91c1c; border-color: #fca5a5; background: #fef2f2; }
    .preview-meta { color: var(--muted); font-size: 0.8rem; padding: 0.6rem 0.85rem; border-bottom: 1px solid var(--border); overflow-wrap: anywhere; }
    .preview-body { padding: 0.72rem 0.85rem 0.85rem; overflow: auto; min-height: 0; display: flex; flex: 1 1 auto; flex-direction: column; gap: 0.55rem; }
    .preview-empty { margin: 0; color: var(--muted); }
    .preview-textbox { width: 100%; min-height: 0; height: 100%; flex: 1 1 auto; margin: 0; padding: 0.6rem 0.7rem; border: 1px solid var(--border); border-radius: 8px; background: #fff; color: var(--fg); font-size: 0.84rem; line-height: 1.45; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; resize: none; }
    .preview-textbox:focus { outline: none; border-color: #93c5fd; box-shadow: 0 0 0 1px rgba(59, 130, 246, 0.22); }
    .preview-image { display: block; max-width: 100%; height: auto; border-radius: 8px; background: #f8fafc; }
    .preview-image.zoomable { cursor: zoom-in; }
    .preview-image-zoom { position: fixed; inset: 0; z-index: 70; display: flex; align-items: center; justify-content: center; padding: 1rem; background: rgba(15, 23, 42, 0.78); }
    .preview-image-zoom[hidden] { display: none; }
    .preview-image-zoom-viewport { max-width: calc(100vw - 2rem); max-height: calc(100vh - 2rem); overflow: auto; border-radius: 10px; cursor: default; scrollbar-width: none; -ms-overflow-style: none; }
    .preview-image-zoom-viewport::-webkit-scrollbar { width: 0; height: 0; display: none; }
    .preview-image-zoom-viewport.draggable { cursor: grab; }
    .preview-image-zoom-viewport.dragging { cursor: grabbing; user-select: none; }
    .preview-image-zoom-media { display: block; max-width: none; max-height: none; border-radius: 10px; background: #fff; box-shadow: 0 20px 56px rgba(15, 23, 42, 0.45); user-select: none; -webkit-user-drag: none; }
    .preview-image-zoom-close { position: absolute; top: 1rem; right: 1rem; appearance: none; border: 1px solid rgba(255, 255, 255, 0.35); border-radius: 999px; background: rgba(2, 6, 23, 0.62); color: #fff; width: 2rem; height: 2rem; padding: 0; font: inherit; font-size: 1.2rem; line-height: 1; display: inline-flex; align-items: center; justify-content: center; cursor: pointer; }
    .preview-image-zoom-close:hover { background: rgba(2, 6, 23, 0.78); }
    .preview-note { margin: 0.55rem 0 0; color: var(--muted); font-size: 0.8rem; }
    .sort-btn { appearance: none; border: none; background: transparent; color: inherit; font: inherit; font-weight: inherit; cursor: pointer; padding: 0; display: inline-flex; align-items: center; gap: 0.25rem; }
    .sort-btn::after {
      content: "";
      width: 0.72rem;
      height: 0.72rem;
      opacity: 0;
      background: currentColor;
      mask-repeat: no-repeat;
      mask-position: center;
      mask-size: contain;
      -webkit-mask-repeat: no-repeat;
      -webkit-mask-position: center;
      -webkit-mask-size: contain;
    }
    .sort-btn[data-dir="asc"]::after {
      opacity: 0.9;
      mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 12 12'%3E%3Cpath d='M2 8 6 4l4 4' fill='none' stroke='%23000' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
      -webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 12 12'%3E%3Cpath d='M2 8 6 4l4 4' fill='none' stroke='%23000' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
    }
    .sort-btn[data-dir="desc"]::after {
      opacity: 0.9;
      mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 12 12'%3E%3Cpath d='M2 4 6 8l4-4' fill='none' stroke='%23000' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
      -webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 12 12'%3E%3Cpath d='M2 4 6 8l4-4' fill='none' stroke='%23000' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
    }
    a { text-decoration: none; color: var(--link); }
    a:hover { text-decoration: underline; }
    .muted { color: var(--muted); }
    .search-hit { background: #fde68a; color: inherit; padding: 0 0.1em; border-radius: 0.2em; }
    @media (max-width: 860px) {
      td.modified, th.modified { display: none; }
      table { min-width: 460px; }
    }
    @media (max-width: 560px) {
      td.size, th.size { display: none; }
      table { min-width: 320px; }
    }
    @media (max-width: 760px) {
      .wrap { padding: 0.75rem; }
      .search-wrap { flex: 1 1 100%; max-width: none; }
      .preview-drawer { top: 0.5rem; right: 0.5rem; width: calc(100vw - 1rem); max-width: none; height: calc(100vh - 1rem); max-height: calc(100vh - 1rem); }
    }
  </style>
</head>
<body>
  <main class="wrap">
    <h1 class="index-title"><span>Index of</span><span class="index-path">${indexPath}</span></h1>
    <div class="toolbar">
      <div class="search-wrap">
        <input id="searchInput" class="search" type="search" placeholder=" " autocomplete="off" aria-label="Search by name">
        <span class="search-ghost" aria-hidden="true"><span>Type</span><kbd class="search-kbd">/</kbd><span>to search</span></span>
        <button id="searchClear" class="search-clear" type="button" aria-label="Clear search" title="Clear search" hidden>&times;</button>
      </div>
    </div>
    <div class="table-wrap">
      <table id="fileTable">
        <thead>
          <tr>
            <th class="name"><button type="button" class="sort-btn" data-key="name">Name</button></th>
            <th class="size"><button type="button" class="sort-btn" data-key="size">Size</button></th>
            <th class="modified"><button type="button" class="sort-btn" data-key="modified">Modified</button></th>
            <th class="action">Operations</th>
          </tr>
        </thead>
        <tbody>${parent}${rows}</tbody>
      </table>
    </div>
  </main>
  <aside id="previewDrawer" class="preview-drawer" aria-label="File preview" aria-hidden="true">
    <div class="preview-head">
      <h2 class="preview-title">Preview</h2>
      <div class="preview-actions">
        <button id="previewCopy" type="button" class="preview-btn" data-copy-state="idle" aria-label="Copy preview text" title="Copy preview text" disabled><svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><rect x="5" y="5" width="8" height="8" rx="1.4"></rect><path d="M3 10V3.8C3 3.36 3.36 3 3.8 3H10"></path></svg></button>
        <button id="previewClose" type="button" class="preview-btn" aria-label="Close preview panel" title="Close preview panel"><svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path d="M4 4l8 8M12 4L4 12"></path></svg></button>
      </div>
    </div>
    <div id="previewMeta" class="preview-meta">No file selected</div>
    <div id="previewBody" class="preview-body">
      <p class="preview-empty">Click preview in Operations to open this floating panel.</p>
    </div>
  </aside>
  <div id="previewImageZoom" class="preview-image-zoom" aria-hidden="true" hidden>
    <button id="previewImageZoomClose" type="button" class="preview-image-zoom-close" aria-label="Close image zoom" title="Close image zoom">&times;</button>
    <div id="previewImageZoomViewport" class="preview-image-zoom-viewport">
      <img id="previewImageZoomImg" class="preview-image-zoom-media" alt="" draggable="false">
    </div>
  </div>
  <script>
    (() => {
      const table = document.getElementById("fileTable");
      const tbody = table && table.tBodies[0];
      if (!tbody) return;

      const parentRow = tbody.querySelector('tr td a[href="../"]')?.closest("tr") || null;
      const entryRows = Array.from(tbody.querySelectorAll("tr")).filter((row) => row !== parentRow);
      const searchInput = document.getElementById("searchInput");
      const searchClear = document.getElementById("searchClear");
      const previewDrawer = document.getElementById("previewDrawer");
      const previewMeta = document.getElementById("previewMeta");
      const previewBody = document.getElementById("previewBody");
      const previewCopy = document.getElementById("previewCopy");
      const previewClose = document.getElementById("previewClose");
      const previewImageZoom = document.getElementById("previewImageZoom");
      const previewImageZoomViewport = document.getElementById("previewImageZoomViewport");
      const previewImageZoomImg = document.getElementById("previewImageZoomImg");
      const previewImageZoomClose = document.getElementById("previewImageZoomClose");
      const sortButtons = Array.from(document.querySelectorAll(".sort-btn"));
      const sortKeys = new Set(["name", "size", "modified"]);
      const sortStorageKey = "http-file-server:sort:" + location.pathname;
      const initialState = loadSortState();
      const state = initialState || { key: "name", dir: "asc" };
      const PREVIEW_TEXT_LIMIT_BYTES = ${PREVIEW_TEXT_LIMIT_BYTES};
      const PREVIEW_TEXT_LIMIT_CHARS = ${PREVIEW_TEXT_LIMIT_CHARS};
      const PREVIEW_TEXT_LIMIT_MESSAGE = ${JSON.stringify(PREVIEW_TEXT_LIMIT_MESSAGE)};
      let previewRequestId = 0;
      let activePreviewRow = null;
      let activePreviewAbort = null;
      let previewCopyText = "";
      let previewCopyFeedbackTimer = null;
      let imageZoomScale = 1;
      let imageZoomNaturalWidth = 0;
      let imageZoomNaturalHeight = 0;
      let imageZoomDragging = false;
      let imageZoomPointerId = -1;
      let imageZoomDragStartX = 0;
      let imageZoomDragStartY = 0;
      let imageZoomStartScrollLeft = 0;
      let imageZoomStartScrollTop = 0;
      const IMAGE_ZOOM_MIN = 0.2;
      const IMAGE_ZOOM_MAX = 8;
      const COPY_ICON_DEFAULT = '<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><rect x="5" y="5" width="8" height="8" rx="1.4"></rect><path d="M3 10V3.8C3 3.36 3.36 3 3.8 3H10"></path></svg>';
      const COPY_ICON_COPIED = '<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path d="M3.2 8.5l2.4 2.4 7-7"></path></svg>';
      const COPY_ICON_FAILED = '<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><circle cx="8" cy="8" r="5.7"></circle><path d="M8 5.1v3.6"></path><path d="M8 11.3h.01"></path></svg>';

      function loadSortState() {
        try {
          const raw = localStorage.getItem(sortStorageKey);
          if (!raw) return null;
          const parsed = JSON.parse(raw);
          if (!parsed || typeof parsed !== "object") return null;
          if (!sortKeys.has(parsed.key)) return null;
          if (parsed.dir !== "asc" && parsed.dir !== "desc") return null;
          return { key: parsed.key, dir: parsed.dir };
        } catch {
          return null;
        }
      }

      function saveSortState() {
        try {
          localStorage.setItem(sortStorageKey, JSON.stringify({ key: state.key, dir: state.dir }));
        } catch {
          // Ignore storage failures (private mode, denied quota, etc.).
        }
      }

      function isEditableTarget(target) {
        if (!(target instanceof HTMLElement)) return false;
        const tag = target.tagName;
        return tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" || target.isContentEditable;
      }

      function clearNode(node) {
        while (node.firstChild) node.removeChild(node.firstChild);
      }

      function clearCopyFeedback() {
        if (!(previewCopy instanceof HTMLButtonElement)) return;
        if (previewCopyFeedbackTimer != null) {
          clearTimeout(previewCopyFeedbackTimer);
          previewCopyFeedbackTimer = null;
        }
        previewCopy.dataset.copyState = "idle";
        previewCopy.setAttribute("aria-label", "Copy preview text");
        previewCopy.setAttribute("title", "Copy preview text");
        previewCopy.innerHTML = COPY_ICON_DEFAULT;
      }

      function setCopyText(value) {
        previewCopyText = value || "";
        if (!(previewCopy instanceof HTMLButtonElement)) return;
        previewCopy.disabled = previewCopyText.length === 0;
        clearCopyFeedback();
      }

      function flashCopyState(state) {
        if (!(previewCopy instanceof HTMLButtonElement)) return;
        if (state === "copied") {
          previewCopy.dataset.copyState = "copied";
          previewCopy.setAttribute("aria-label", "Copied");
          previewCopy.setAttribute("title", "Copied");
          previewCopy.innerHTML = COPY_ICON_COPIED;
        } else {
          previewCopy.dataset.copyState = "failed";
          previewCopy.setAttribute("aria-label", "Copy failed");
          previewCopy.setAttribute("title", "Copy failed");
          previewCopy.innerHTML = COPY_ICON_FAILED;
        }
        if (previewCopyFeedbackTimer != null) {
          clearTimeout(previewCopyFeedbackTimer);
        }
        previewCopyFeedbackTimer = setTimeout(() => {
          previewCopyFeedbackTimer = null;
          clearCopyFeedback();
        }, 1200);
      }

      async function writeTextToClipboard(text) {
        const value = String(text || "");
        if (!value) return;
        if (navigator.clipboard && typeof navigator.clipboard.writeText === "function" && window.isSecureContext) {
          await navigator.clipboard.writeText(value);
          return;
        }
        const textarea = document.createElement("textarea");
        textarea.value = value;
        textarea.setAttribute("readonly", "");
        textarea.style.position = "fixed";
        textarea.style.left = "-9999px";
        textarea.style.top = "0";
        document.body.appendChild(textarea);
        textarea.focus();
        textarea.select();
        textarea.setSelectionRange(0, textarea.value.length);
        const copied = document.execCommand("copy");
        document.body.removeChild(textarea);
        if (!copied) {
          throw new Error("clipboard unavailable");
        }
      }

      function isPreviewOpen() {
        return previewDrawer instanceof HTMLElement && previewDrawer.classList.contains("open");
      }

      function setPreviewOpen(open) {
        if (!(previewDrawer instanceof HTMLElement)) return;
        previewDrawer.classList.toggle("open", open);
        previewDrawer.setAttribute("aria-hidden", open ? "false" : "true");
      }

      function isImageZoomOpen() {
        return previewImageZoom instanceof HTMLElement && !previewImageZoom.hidden;
      }

      function clampImageZoomScale(scale) {
        return Math.min(IMAGE_ZOOM_MAX, Math.max(IMAGE_ZOOM_MIN, scale));
      }

      function canDragZoomImage() {
        if (!(previewImageZoomViewport instanceof HTMLElement)) return false;
        return (
          previewImageZoomViewport.scrollWidth > previewImageZoomViewport.clientWidth + 1 ||
          previewImageZoomViewport.scrollHeight > previewImageZoomViewport.clientHeight + 1
        );
      }

      function syncImageZoomDragCursor() {
        if (!(previewImageZoomViewport instanceof HTMLElement)) return;
        previewImageZoomViewport.classList.toggle("draggable", canDragZoomImage());
        if (!imageZoomDragging) {
          previewImageZoomViewport.classList.remove("dragging");
        }
      }

      function stopImageZoomDrag() {
        if (!(previewImageZoomViewport instanceof HTMLElement)) return;
        imageZoomDragging = false;
        imageZoomPointerId = -1;
        previewImageZoomViewport.classList.remove("dragging");
      }

      function applyImageZoom(scale) {
        if (!(previewImageZoomImg instanceof HTMLImageElement)) return;
        if (imageZoomNaturalWidth <= 0 || imageZoomNaturalHeight <= 0) return;
        imageZoomScale = clampImageZoomScale(scale);
        previewImageZoomImg.style.width = String(Math.max(1, Math.round(imageZoomNaturalWidth * imageZoomScale))) + "px";
        previewImageZoomImg.style.height = String(Math.max(1, Math.round(imageZoomNaturalHeight * imageZoomScale))) + "px";
        syncImageZoomDragCursor();
      }

      function fitImageZoomToViewport() {
        if (!(previewImageZoomViewport instanceof HTMLElement)) return;
        if (imageZoomNaturalWidth <= 0 || imageZoomNaturalHeight <= 0) return;
        const viewportWidth = Math.max(1, previewImageZoomViewport.clientWidth);
        const viewportHeight = Math.max(1, previewImageZoomViewport.clientHeight);
        const fitScale = Math.min(viewportWidth / imageZoomNaturalWidth, viewportHeight / imageZoomNaturalHeight, 1);
        applyImageZoom(fitScale);
        const contentWidth = imageZoomNaturalWidth * imageZoomScale;
        const contentHeight = imageZoomNaturalHeight * imageZoomScale;
        previewImageZoomViewport.scrollLeft = Math.max(0, (contentWidth - viewportWidth) / 2);
        previewImageZoomViewport.scrollTop = Math.max(0, (contentHeight - viewportHeight) / 2);
      }

      function closeImageZoom() {
        if (!(previewImageZoom instanceof HTMLElement)) return;
        previewImageZoom.hidden = true;
        previewImageZoom.setAttribute("aria-hidden", "true");
        stopImageZoomDrag();
        imageZoomScale = 1;
        imageZoomNaturalWidth = 0;
        imageZoomNaturalHeight = 0;
        if (previewImageZoomViewport instanceof HTMLElement) {
          previewImageZoomViewport.scrollLeft = 0;
          previewImageZoomViewport.scrollTop = 0;
          previewImageZoomViewport.classList.remove("draggable");
          previewImageZoomViewport.classList.remove("dragging");
        }
        if (previewImageZoomImg instanceof HTMLImageElement) {
          previewImageZoomImg.removeAttribute("src");
          previewImageZoomImg.alt = "";
          previewImageZoomImg.style.removeProperty("width");
          previewImageZoomImg.style.removeProperty("height");
        }
      }

      function openImageZoom(src, altText) {
        if (!(previewImageZoom instanceof HTMLElement)) return;
        if (!(previewImageZoomImg instanceof HTMLImageElement)) return;
        imageZoomScale = 1;
        imageZoomNaturalWidth = 0;
        imageZoomNaturalHeight = 0;
        previewImageZoomImg.style.removeProperty("width");
        previewImageZoomImg.style.removeProperty("height");
        previewImageZoomImg.alt = altText || "Image preview";
        previewImageZoomImg.src = src;
        previewImageZoom.hidden = false;
        previewImageZoom.setAttribute("aria-hidden", "false");
        if (previewImageZoomImg.complete && previewImageZoomImg.naturalWidth > 0 && previewImageZoomImg.naturalHeight > 0) {
          imageZoomNaturalWidth = previewImageZoomImg.naturalWidth;
          imageZoomNaturalHeight = previewImageZoomImg.naturalHeight;
          fitImageZoomToViewport();
        }
      }

      function setActivePreviewRow(row) {
        if (activePreviewRow) activePreviewRow.classList.remove("preview-active");
        activePreviewRow = row;
        if (activePreviewRow) activePreviewRow.classList.add("preview-active");
      }

      function setPreviewMessage(message) {
        if (!(previewBody instanceof HTMLElement)) return;
        clearNode(previewBody);
        const p = document.createElement("p");
        p.className = "preview-empty";
        p.textContent = message;
        previewBody.appendChild(p);
      }

      function closePreview() {
        closeImageZoom();
        cancelActivePreviewRequest();
        setPreviewOpen(false);
        setActivePreviewRow(null);
        setCopyText("");
      }

      function cancelActivePreviewRequest() {
        previewRequestId += 1;
        if (activePreviewAbort) {
          activePreviewAbort.abort();
          activePreviewAbort = null;
        }
        return previewRequestId;
      }

      function parseContentLengthHeader(response) {
        const raw = response.headers.get("content-length");
        if (!raw) return -1;
        const value = Number(raw);
        if (!Number.isFinite(value) || value < 0) return -1;
        return value;
      }

      async function readLimitedTextPreview(response, requestId) {
        let text = "";
        let truncated = false;
        if (response.body && typeof response.body.getReader === "function") {
          const reader = response.body.getReader();
          const decoder = new TextDecoder();
          let totalBytes = 0;
          try {
            while (true) {
              const { value, done } = await reader.read();
              if (requestId !== previewRequestId) {
                try {
                  await reader.cancel();
                } catch {
                  // Ignore cancellation failures.
                }
                return null;
              }
              if (done) break;
              if (!(value instanceof Uint8Array) || value.byteLength === 0) continue;

              const remainingBytes = PREVIEW_TEXT_LIMIT_BYTES - totalBytes;
              if (remainingBytes <= 0) {
                truncated = true;
                try {
                  await reader.cancel();
                } catch {
                  // Ignore cancellation failures.
                }
                break;
              }

              let chunk = value;
              if (chunk.byteLength > remainingBytes) {
                chunk = chunk.subarray(0, remainingBytes);
                truncated = true;
              }

              totalBytes += chunk.byteLength;
              text += decoder.decode(chunk, { stream: true });
              if (text.length >= PREVIEW_TEXT_LIMIT_CHARS) {
                text = text.slice(0, PREVIEW_TEXT_LIMIT_CHARS);
                truncated = true;
              }

              if (truncated) {
                try {
                  await reader.cancel();
                } catch {
                  // Ignore cancellation failures.
                }
                break;
              }
            }
            text += decoder.decode();
          } finally {
            reader.releaseLock();
          }
        } else {
          const fallbackLength = parseContentLengthHeader(response);
          if (fallbackLength < 0 || fallbackLength > PREVIEW_TEXT_LIMIT_BYTES) {
            throw new Error("preview stream unavailable");
          }
          text = await response.text();
          if (text.length > PREVIEW_TEXT_LIMIT_CHARS) {
            text = text.slice(0, PREVIEW_TEXT_LIMIT_CHARS);
            truncated = true;
          }
        }
        return { text, truncated };
      }

      async function openPreview(row) {
        if (!(previewBody instanceof HTMLElement)) return;
        const kind = row.dataset.previewKind || "none";
        const previewUrl = row.dataset.previewUrl || "";
        const name = row.dataset.name || "(unknown)";
        const sizeLabel = row.dataset.sizeLabel || "-";
        const modifiedLabel = row.dataset.modifiedLabel || "-";
        const mime = row.dataset.mime || "unknown";

        closeImageZoom();
        setPreviewOpen(true);
        setActivePreviewRow(row);
        if (previewMeta) {
          previewMeta.textContent = name + " | " + (mime || "unknown") + " | " + sizeLabel + " | " + modifiedLabel;
        }
        setCopyText("");
        const requestId = cancelActivePreviewRequest();

        if (!previewUrl || kind === "none") {
          setPreviewMessage("This file type is not previewable.");
          return;
        }

        const sizeCell = row.querySelector("td.size");
        const sizeBytes = Number(sizeCell?.dataset.sort ?? -1);
        if (kind === "text" && Number.isFinite(sizeBytes) && sizeBytes > PREVIEW_TEXT_LIMIT_BYTES) {
          setPreviewMessage(PREVIEW_TEXT_LIMIT_MESSAGE);
          return;
        }

        setPreviewMessage("Loading preview...");

        if (kind === "image") {
          clearNode(previewBody);
          const img = document.createElement("img");
          img.className = "preview-image zoomable";
          img.alt = name;
          img.loading = "lazy";
          img.src = previewUrl;
          img.title = "Click image to zoom";
          img.addEventListener("error", () => {
            if (requestId !== previewRequestId) return;
            setPreviewMessage("Image preview unavailable.");
          });
          img.addEventListener("click", () => {
            if (requestId !== previewRequestId) return;
            openImageZoom(previewUrl, name);
          });
          previewBody.appendChild(img);
          const note = document.createElement("p");
          note.className = "preview-note";
          note.textContent = "Image preview. Click image to zoom, use mouse wheel to zoom in/out, and drag to pan.";
          previewBody.appendChild(note);
          return;
        }

        const abortController = new AbortController();
        activePreviewAbort = abortController;
        try {
          const response = await fetch(previewUrl, { method: "GET", signal: abortController.signal });
          if (requestId !== previewRequestId) return;
          if (!response.ok) throw new Error("HTTP " + response.status);
          const contentLength = parseContentLengthHeader(response);
          if (contentLength > PREVIEW_TEXT_LIMIT_BYTES) {
            if (response.body && typeof response.body.cancel === "function") {
              try {
                await response.body.cancel();
              } catch {
                // Ignore cancellation failures.
              }
            }
            setCopyText("");
            setPreviewMessage(PREVIEW_TEXT_LIMIT_MESSAGE);
            return;
          }

          const readResult = await readLimitedTextPreview(response, requestId);
          if (requestId !== previewRequestId || readResult == null) return;
          const { text, truncated } = readResult;
          setCopyText(text);

          clearNode(previewBody);
          const textbox = document.createElement("textarea");
          textbox.className = "preview-textbox";
          textbox.readOnly = true;
          textbox.spellcheck = false;
          textbox.value = text;
          previewBody.appendChild(textbox);
          if (truncated) {
            const note = document.createElement("p");
            note.className = "preview-note";
            note.textContent = "Preview truncated for performance.";
            previewBody.appendChild(note);
          }
        } catch (error) {
          if (requestId !== previewRequestId) return;
          if (error instanceof DOMException && error.name === "AbortError") return;
          const message = error instanceof Error ? error.message : String(error);
          setCopyText("");
          setPreviewMessage("Preview failed (" + message + ").");
        } finally {
          if (activePreviewAbort === abortController) {
            activePreviewAbort = null;
          }
        }
      }

      function clearHighlights(root) {
        const marks = root.querySelectorAll("mark.search-hit");
        for (const mark of marks) {
          mark.replaceWith(document.createTextNode(mark.textContent || ""));
        }
        root.normalize();
      }

      function highlightInCell(cell, query) {
        if (!query) return false;
        const walker = document.createTreeWalker(cell, NodeFilter.SHOW_TEXT);
        const textNodes = [];
        let node = walker.nextNode();
        while (node) {
          if (node.nodeValue && node.nodeValue.trim() !== "") {
            textNodes.push(node);
          }
          node = walker.nextNode();
        }

        let matched = false;
        for (const textNode of textNodes) {
          const text = textNode.nodeValue || "";
          const lower = text.toLowerCase();
          let start = 0;
          let idx = lower.indexOf(query, start);
          if (idx === -1) continue;

          matched = true;
          const fragment = document.createDocumentFragment();
          while (idx !== -1) {
            if (idx > start) {
              fragment.append(document.createTextNode(text.slice(start, idx)));
            }
            const mark = document.createElement("mark");
            mark.className = "search-hit";
            mark.textContent = text.slice(idx, idx + query.length);
            fragment.append(mark);
            start = idx + query.length;
            idx = lower.indexOf(query, start);
          }
          if (start < text.length) {
            fragment.append(document.createTextNode(text.slice(start)));
          }
          textNode.parentNode.replaceChild(fragment, textNode);
        }

        return matched;
      }

      function rowMatchesAndHighlight(row, query) {
        clearHighlights(row);
        if (!query) return true;
        const nameCell = row.querySelector("td.name");
        if (!nameCell) return false;
        return highlightInCell(nameCell, query);
      }

      function sortValue(row, key) {
        const cell = row.querySelector(\`td.\${key}\`);
        if (!cell) return "";
        return cell.dataset.sort ?? "";
      }

      function rowGroup(row) {
        return Number(row.dataset.group ?? 1);
      }

      function compareRows(a, b) {
        const groupDiff = rowGroup(a) - rowGroup(b);
        if (groupDiff !== 0) return groupDiff;

        let result = 0;
        if (state.key === "name") {
          result = String(sortValue(a, "name")).localeCompare(String(sortValue(b, "name")), undefined, { sensitivity: "base" });
        } else if (state.key === "size") {
          result = Number(sortValue(a, "size")) - Number(sortValue(b, "size"));
        } else if (state.key === "modified") {
          result = Number(sortValue(a, "modified")) - Number(sortValue(b, "modified"));
        }

        if (result === 0) {
          result = String(sortValue(a, "name")).localeCompare(String(sortValue(b, "name")), undefined, { sensitivity: "base" });
        }
        return state.dir === "asc" ? result : -result;
      }

      function syncSearchClearVisibility() {
        if (!(searchInput instanceof HTMLInputElement)) return;
        if (!(searchClear instanceof HTMLButtonElement)) return;
        searchClear.hidden = searchInput.value.length === 0;
      }

      function render() {
        const query = (searchInput?.value || "").trim().toLowerCase();
        const sortedRows = [...entryRows].sort(compareRows);
        for (const row of sortedRows) {
          const visible = rowMatchesAndHighlight(row, query);
          row.hidden = !visible;
          tbody.appendChild(row);
        }
        for (const btn of sortButtons) {
          btn.dataset.dir = btn.dataset.key === state.key ? state.dir : "";
        }
        syncSearchClearVisibility();
      }

      for (const btn of sortButtons) {
        btn.addEventListener("click", () => {
          if (state.key === btn.dataset.key) {
            state.dir = state.dir === "asc" ? "desc" : "asc";
          } else {
            state.key = btn.dataset.key || "name";
            state.dir = "asc";
          }
          saveSortState();
          render();
        });
      }

      tbody.addEventListener("click", (event) => {
        const target = event.target;
        if (!(target instanceof Element)) return;
        const previewLink = target.closest("a.preview-link");
        if (!previewLink) return;
        if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
        event.preventDefault();
        const row = previewLink.closest("tr");
        if (row) void openPreview(row);
      });

      previewImageZoomImg?.addEventListener("load", () => {
        if (!(previewImageZoomImg instanceof HTMLImageElement)) return;
        if (!isImageZoomOpen()) return;
        if (previewImageZoomImg.naturalWidth <= 0 || previewImageZoomImg.naturalHeight <= 0) return;
        imageZoomNaturalWidth = previewImageZoomImg.naturalWidth;
        imageZoomNaturalHeight = previewImageZoomImg.naturalHeight;
        fitImageZoomToViewport();
      });

      previewImageZoomViewport?.addEventListener("wheel", (event) => {
        if (!isImageZoomOpen()) return;
        if (!(previewImageZoomViewport instanceof HTMLElement)) return;
        if (imageZoomNaturalWidth <= 0 || imageZoomNaturalHeight <= 0) return;
        event.preventDefault();
        const factor = Math.exp(-event.deltaY * 0.0015);
        const previousScale = imageZoomScale;
        const nextScale = clampImageZoomScale(previousScale * factor);
        if (Math.abs(nextScale - previousScale) < 0.0001) return;
        const rect = previewImageZoomViewport.getBoundingClientRect();
        const anchorViewportX = event.clientX - rect.left;
        const anchorViewportY = event.clientY - rect.top;
        const anchorImageX = anchorViewportX + previewImageZoomViewport.scrollLeft;
        const anchorImageY = anchorViewportY + previewImageZoomViewport.scrollTop;
        const prevWidth = imageZoomNaturalWidth * previousScale;
        const prevHeight = imageZoomNaturalHeight * previousScale;
        const ratioX = prevWidth > 0 ? anchorImageX / prevWidth : 0.5;
        const ratioY = prevHeight > 0 ? anchorImageY / prevHeight : 0.5;
        applyImageZoom(nextScale);
        const nextWidth = imageZoomNaturalWidth * imageZoomScale;
        const nextHeight = imageZoomNaturalHeight * imageZoomScale;
        previewImageZoomViewport.scrollLeft = ratioX * nextWidth - anchorViewportX;
        previewImageZoomViewport.scrollTop = ratioY * nextHeight - anchorViewportY;
      }, { passive: false });

      previewImageZoomViewport?.addEventListener("pointerdown", (event) => {
        if (!isImageZoomOpen()) return;
        if (!(previewImageZoomViewport instanceof HTMLElement)) return;
        if (event.button !== 0) return;
        if (!canDragZoomImage()) return;
        imageZoomDragging = true;
        imageZoomPointerId = event.pointerId;
        imageZoomDragStartX = event.clientX;
        imageZoomDragStartY = event.clientY;
        imageZoomStartScrollLeft = previewImageZoomViewport.scrollLeft;
        imageZoomStartScrollTop = previewImageZoomViewport.scrollTop;
        previewImageZoomViewport.classList.add("dragging");
        try {
          previewImageZoomViewport.setPointerCapture(event.pointerId);
        } catch {
          // Ignore pointer capture failures.
        }
        event.preventDefault();
      });

      previewImageZoomViewport?.addEventListener("pointermove", (event) => {
        if (!imageZoomDragging) return;
        if (event.pointerId !== imageZoomPointerId) return;
        if (!(previewImageZoomViewport instanceof HTMLElement)) return;
        const deltaX = event.clientX - imageZoomDragStartX;
        const deltaY = event.clientY - imageZoomDragStartY;
        previewImageZoomViewport.scrollLeft = imageZoomStartScrollLeft - deltaX;
        previewImageZoomViewport.scrollTop = imageZoomStartScrollTop - deltaY;
        event.preventDefault();
      });

      previewImageZoomViewport?.addEventListener("pointerup", (event) => {
        if (!imageZoomDragging) return;
        if (event.pointerId !== imageZoomPointerId) return;
        if (previewImageZoomViewport instanceof HTMLElement && previewImageZoomViewport.hasPointerCapture(event.pointerId)) {
          previewImageZoomViewport.releasePointerCapture(event.pointerId);
        }
        stopImageZoomDrag();
      });

      previewImageZoomViewport?.addEventListener("pointercancel", (event) => {
        if (!imageZoomDragging) return;
        if (event.pointerId !== imageZoomPointerId) return;
        if (previewImageZoomViewport instanceof HTMLElement && previewImageZoomViewport.hasPointerCapture(event.pointerId)) {
          previewImageZoomViewport.releasePointerCapture(event.pointerId);
        }
        stopImageZoomDrag();
      });

      previewImageZoomViewport?.addEventListener("lostpointercapture", () => {
        stopImageZoomDrag();
      });

      previewClose?.addEventListener("click", closePreview);
      previewImageZoomClose?.addEventListener("click", (event) => {
        event.preventDefault();
        closeImageZoom();
      });
      previewImageZoom?.addEventListener("click", (event) => {
        const target = event.target;
        if (!(target instanceof Element)) return;
        if (target === previewImageZoom) {
          closeImageZoom();
        }
      });
      previewCopy?.addEventListener("click", async () => {
        if (!previewCopyText) return;
        try {
          await writeTextToClipboard(previewCopyText);
          flashCopyState("copied");
        } catch {
          flashCopyState("failed");
        }
      });

      searchClear?.addEventListener("click", () => {
        if (!(searchInput instanceof HTMLInputElement)) return;
        if (!searchInput.value) return;
        searchInput.value = "";
        render();
        searchInput.focus();
      });

      document.addEventListener("pointerdown", (event) => {
        if (!isPreviewOpen()) return;
        const target = event.target;
        if (!(target instanceof Element)) return;
        if (target.closest("#previewDrawer")) return;
        if (target.closest("#previewImageZoom")) return;
        if (target.closest("a.preview-link")) return;
        closePreview();
      });

      document.addEventListener("keydown", (event) => {
        if (!searchInput || event.defaultPrevented || event.ctrlKey || event.metaKey || event.altKey) return;
        const active = document.activeElement;
        const inEditable = isEditableTarget(active);

        if (event.key === "/" && !inEditable) {
          event.preventDefault();
          searchInput.focus();
          searchInput.select();
          return;
        }

        if (event.key === "Escape") {
          if (isImageZoomOpen()) {
            event.preventDefault();
            closeImageZoom();
            return;
          }
          if (active === searchInput) {
            event.preventDefault();
            if (searchInput.value) {
              searchInput.value = "";
              render();
            }
            searchInput.blur();
            return;
          }
          if (isPreviewOpen()) {
            event.preventDefault();
            closePreview();
          }
        }
      });

      searchInput?.addEventListener("input", render);
      render();
    })();
  </script>
</body>
</html>`;
}

function parseCliConfig(argv) {
  const config = { ...DEFAULT_CONFIG };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];

    if (arg === "--help" || arg === "-?") {
      printUsage();
      process.exit(0);
    }

    if (arg === "--port" || arg === "-p") {
      config.port = parsePort(argv[i + 1], "port");
      i += 1;
      continue;
    }

    if (arg === "--host" || arg === "-h") {
      const next = argv[i + 1];
      if (!next || next.startsWith("-")) {
        throw new Error("Missing host after --host");
      }
      config.host = next;
      i += 1;
      continue;
    }

    if (!arg.startsWith("-")) {
      config.root = arg;
      continue;
    }

    if (arg === "--test") {
      config.runTests = true;
      continue;
    }

    throw new Error(`Unknown argument: ${arg}`);
  }

  return config;
}

function printUsage() {
  console.log([
    "Usage:",
    "  bun http-file-server.js [root] [--host <HOST>] [--port <PORT>] [--test]",
    "",
    "Options:",
    "  -h, --host <HOST>        Bind host (default: 0.0.0.0)",
    "  -p, --port <PORT>        Bind port (default: 3000)",
    "  --test                   Run built-in self tests and exit",
    "  -?, --help               Show this help message",
  ].join("\n"));
}

export class HttpFileServer {
  constructor(options = {}) {
    const merged = { ...DEFAULT_CONFIG, ...options };
    this.host = merged.host;
    this.port = parsePort(merged.port, "port option");
    this.rootDir = resolve(merged.root);
    try {
      this.rootRealDir = realpathSync(this.rootDir);
    } catch (error) {
      throw new Error(`Invalid root directory: ${this.rootDir}`);
    }
    this.server = null;
  }

  start() {
    this.server = Bun.serve({
      hostname: this.host,
      port: this.port,
      fetch: this.handleRequest.bind(this),
      error: this.handleError.bind(this),
    });
    return this.server;
  }

  handleError(error) {
    console.error("Server error:", error);
    return new Response("Internal Server Error", { status: 500 });
  }

  respond(req, body, init) {
    if (req.method === "HEAD") {
      return new Response(null, init);
    }
    return new Response(body, init);
  }

  async handleRequest(req) {
    if (req.method !== "GET" && req.method !== "HEAD") {
      return new Response("Method Not Allowed", {
        status: 405,
        headers: { Allow: "GET, HEAD" },
      });
    }

    const url = new URL(req.url);
    const targetPath = safeResolvePath(this.rootDir, url.pathname);
    if (!targetPath) {
      return new Response("Forbidden", { status: 403 });
    }

    let targetStat;
    try {
      targetStat = await stat(targetPath);
    } catch {
      return new Response("Not Found", { status: 404 });
    }

    let realTargetPath;
    try {
      realTargetPath = await realpath(targetPath);
    } catch {
      return new Response("Not Found", { status: 404 });
    }
    if (!isPathInside(this.rootRealDir, realTargetPath)) {
      return new Response("Forbidden", { status: 403 });
    }

    if (targetStat.isDirectory()) {
      return this.serveDirectory(req, url, targetPath);
    }

    if (!targetStat.isFile()) {
      return new Response("Not Found", { status: 404 });
    }

    return this.serveFile(req, targetPath, url);
  }

  async serveDirectory(req, url, targetPath) {
    if (!url.pathname.endsWith("/")) {
      const normalizedPath = `/${url.pathname.replace(/^\/+/, "")}`;
      const redirectPath = normalizedPath.endsWith("/") ? normalizedPath : `${normalizedPath}/`;
      const redirect = `${redirectPath}${url.search}`;
      return Response.redirect(redirect, 301);
    }

    const indexPath = join(targetPath, "index.html");
    try {
      const indexStat = await stat(indexPath);
      if (indexStat.isFile()) {
        const indexFile = Bun.file(indexPath);
        const headers = this.buildFileHeaders(indexFile, indexPath);
        return this.respond(req, indexFile, { status: 200, headers });
      }
    } catch {
      // No index.html; continue with generated listing.
    }

    const entries = await readdir(targetPath, { withFileTypes: true });
    const items = await Promise.all(entries.map(async (entry) => {
      const fullPath = join(targetPath, entry.name);
      let isDirectory = entry.isDirectory();
      let isFile = entry.isFile();
      let metadataPath = fullPath;
      let metadataStat = null;

      // Resolve symlinks before reading metadata so out-of-root targets do not leak details.
      if (entry.isSymbolicLink()) {
        try {
          const resolved = await realpath(fullPath);
          if (!isPathInside(this.rootRealDir, resolved)) {
            metadataPath = null;
          } else {
            metadataPath = resolved;
          }
        } catch {
          metadataPath = null;
        }
      }

      if (metadataPath) {
        try {
          metadataStat = await stat(metadataPath);
          isDirectory = metadataStat.isDirectory();
          isFile = metadataStat.isFile();
        } catch {
          metadataPath = null;
        }
      }

      if (!metadataPath && entry.isSymbolicLink()) {
        isDirectory = false;
        isFile = false;
      }

      const displayName = entry.name + (isDirectory ? "/" : "");
      const href = `${encodeURIComponent(entry.name)}${isDirectory ? "/" : ""}`;
      let downloadHref = null;
      let viewHref = null;
      let previewHref = null;
      let previewKind = "none";
      let mime = "";
      let sizeSort = -1;
      let sizeLabel = "-";
      let modifiedSort = 0;
      let modifiedLabel = "-";

      if (metadataStat) {
        modifiedSort = Number(metadataStat.mtimeMs || 0);
        modifiedLabel = formatTimestamp(modifiedSort);
        if (metadataStat.isFile()) {
          sizeSort = Number(metadataStat.size || 0);
          sizeLabel = formatBytes(sizeSort);
        }
      }

      if (isFile) {
        downloadHref = `${href}?action=download`;
        const rawEntryType = Bun.file(metadataPath || fullPath).type || "";
        const resolvedEntryType = resolveContentType(rawEntryType, entry.name);
        mime = resolvedEntryType;
        previewKind = getPreviewKind(resolvedEntryType, entry.name);
        if (previewKind === "text") {
          previewHref = `${href}?action=view`;
        } else if (previewKind === "image") {
          previewHref = href;
        }
        if (shouldForceDownloadByMime(resolvedEntryType, entry.name)) {
          viewHref = `${href}?action=view`;
        }
      }

      return {
        name: displayName,
        sortName: entry.name,
        href,
        downloadHref,
        viewHref,
        previewHref,
        previewKind,
        mime,
        isDirectory,
        groupSort: isDirectory ? 0 : 1,
        sizeSort,
        sizeLabel,
        modifiedSort,
        modifiedLabel,
      };
    }));
    const html = createDirectoryHtml(url.pathname, items);
    const headers = new Headers({ "Content-Type": "text/html; charset=utf-8" });
    return this.respond(req, html, { status: 200, headers });
  }

  serveFile(req, targetPath, url) {
    const file = Bun.file(targetPath);
    const action = url.searchParams.get("action");
    if (url.searchParams.has("view")) {
      return new Response('Bad Request: unsupported query parameter "view"; use "action=view|download".', {
        status: 400,
      });
    }
    if (action && action !== "view" && action !== "download") {
      return new Response('Bad Request: invalid "action"; expected "view" or "download".', {
        status: 400,
      });
    }

    const requestInline = action === "view";
    const requestDownload = action === "download";
    const headers = this.buildFileHeaders(file, targetPath, { requestInline, requestDownload });
    return this.respond(req, file, { status: 200, headers });
  }

  buildFileHeaders(file, filePath, options = {}) {
    const requestInline = Boolean(options.requestInline);
    const requestDownload = Boolean(options.requestDownload);
    const fileName = basename(filePath);
    const resolvedType = resolveContentType(file.type, fileName);
    const headers = new Headers();
    if (resolvedType) headers.set("Content-Type", resolvedType);
    headers.set("Content-Length", String(file.size));
    if (requestDownload) {
      headers.set("Content-Disposition", buildContentDisposition("attachment", fileName));
    } else if (shouldForceDownloadByMime(resolvedType, fileName)) {
      const dispositionType = requestInline ? "inline" : "attachment";
      headers.set("Content-Disposition", buildContentDisposition(dispositionType, fileName));
    }
    return headers;
  }
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function runSelfTests() {
  let total = 0;
  let passed = 0;

  async function test(name, fn) {
    total += 1;
    try {
      await fn();
      passed += 1;
      console.log(`PASS ${name}`);
    } catch (error) {
      console.error(`FAIL ${name}`);
      console.error(error instanceof Error ? error.message : String(error));
    }
  }

  await test("parseCliConfig enables --test", () => {
    const config = parseCliConfig(["--test"]);
    assert(config.runTests === true, "Expected runTests=true");
  });

  await test("parseCliConfig rejects invalid --port", () => {
    let threw = false;
    try {
      parseCliConfig(["--port", "abc"]);
    } catch {
      threw = true;
    }
    assert(threw, "Expected parseCliConfig to reject invalid port");
  });

  await test("safeResolvePath blocks traversal", () => {
    const root = resolve("/tmp/http-file-server-test-root");
    const blocked = safeResolvePath(root, "/%2e%2e/etc/passwd");
    assert(blocked === null, "Expected traversal path to be blocked");
  });

  await test("mime and extension behavior for text detection", () => {
    assert(shouldForceDownloadByMime("text/plain") === true, "text/plain should force behavior");
    assert(shouldForceDownloadByMime("text/html") === false, "text/html should not force behavior");
    assert(shouldForceDownloadByMime("", "guide.rst") === true, ".rst should force behavior by extension");
    assert(shouldForceDownloadByMime("", "Dockerfile") === true, "Dockerfile should force behavior by file name");
    assert(shouldForceDownloadByMime("", "index.html") === false, ".html should not force behavior by extension");
    assert(resolveContentType("", "LICENSE").startsWith("text/plain"), "LICENSE should resolve to text/plain");
    assert(resolveContentType("application/octet-stream", "Dockerfile").startsWith("text/plain"), "Dockerfile should resolve to text/plain");
  });

  const testRoot = await mkdtemp(join(tmpdir(), "http-file-server-test-"));
  const outsideRoot = await mkdtemp(join(tmpdir(), "http-file-server-test-outside-"));
  try {
    await writeFile(join(testRoot, "note.txt"), "hello");
    await writeFile(join(testRoot, "guide.rst"), "Title\n=====\n");
    await writeFile(join(testRoot, "LICENSE"), "MIT License\n");
    await writeFile(join(testRoot, "Dockerfile"), "FROM scratch\n");
    const controlName = "bad\nname.txt";
    await writeFile(join(testRoot, controlName), "x");
    await writeFile(join(testRoot, "data.json"), '{"ok":true}');
    await writeFile(join(testRoot, "blob.bin"), "abc");
    await writeFile(join(testRoot, "cover.png"), "png");
    await mkdir(join(testRoot, "sub"));
    await mkdir(join(testRoot, "example.com"));
    await mkdir(join(testRoot, "nested", "child"), { recursive: true });
    await writeFile(join(testRoot, "sub", "index.html"), "<h1>sub</h1>");
    await writeFile(join(testRoot, "nested", "child", "readme.txt"), "nested");
    await symlink(join(testRoot, "note.txt"), join(testRoot, "note-link.txt"));
    await writeFile(join(outsideRoot, "secret.txt"), "very-secret-content");
    await symlink(join(outsideRoot, "secret.txt"), join(testRoot, "secret-link.txt"));

    await test("default text behavior is attachment", async () => {
      const app = new HttpFileServer({ root: testRoot });
      const response = await app.handleRequest(new Request("http://localhost/note.txt"));
      assert(response.status === 200, `Expected 200, got ${response.status}`);
      assert(
        (response.headers.get("Content-Disposition") || "").startsWith("attachment;"),
        "Expected Content-Disposition attachment",
      );
    });

    await test("rst extension fallback is treated as text attachment", async () => {
      const app = new HttpFileServer({ root: testRoot });
      const response = await app.handleRequest(new Request("http://localhost/guide.rst"));
      assert(response.status === 200, `Expected 200, got ${response.status}`);
      assert(
        (response.headers.get("Content-Disposition") || "").startsWith("attachment;"),
        "Expected Content-Disposition attachment for .rst",
      );
    });

    await test("inline view query sets inline disposition", async () => {
      const app = new HttpFileServer({ root: testRoot });
      const response = await app.handleRequest(new Request("http://localhost/note.txt?action=view"));
      assert(response.status === 200, `Expected 200, got ${response.status}`);
      assert(
        (response.headers.get("Content-Disposition") || "").startsWith("inline;"),
        "Expected Content-Disposition inline",
      );
    });

    await test("LICENSE view uses inline text content type", async () => {
      const app = new HttpFileServer({ root: testRoot });
      const response = await app.handleRequest(new Request("http://localhost/LICENSE?action=view"));
      assert(response.status === 200, `Expected 200, got ${response.status}`);
      assert(
        (response.headers.get("Content-Disposition") || "").startsWith("inline;"),
        "Expected Content-Disposition inline for LICENSE view",
      );
      assert(
        (response.headers.get("Content-Type") || "").toLowerCase().startsWith("text/plain"),
        "Expected text/plain Content-Type for LICENSE view",
      );
    });

    await test("download action forces attachment for non-text file", async () => {
      const app = new HttpFileServer({ root: testRoot });
      const response = await app.handleRequest(new Request("http://localhost/blob.bin?action=download"));
      assert(response.status === 200, `Expected 200, got ${response.status}`);
      assert(
        (response.headers.get("Content-Disposition") || "").startsWith("attachment;"),
        "Expected Content-Disposition attachment for action=download",
      );
    });

    await test("download headers sanitize control chars in filename", async () => {
      const app = new HttpFileServer({ root: testRoot });
      const encoded = encodeURIComponent(controlName);
      const response = await app.handleRequest(new Request(`http://localhost/${encoded}?action=download`));
      assert(response.status === 200, `Expected 200, got ${response.status}`);
      const disposition = response.headers.get("Content-Disposition") || "";
      assert(disposition.startsWith("attachment;"), "Expected attachment disposition");
      assert(!disposition.includes("\n"), "Expected disposition to strip line breaks");
      assert(!disposition.includes("\r"), "Expected disposition to strip carriage returns");
    });

    await test("legacy view query parameter is rejected", async () => {
      const app = new HttpFileServer({ root: testRoot });
      const response = await app.handleRequest(new Request("http://localhost/note.txt?view=inline"));
      assert(response.status === 400, `Expected 400, got ${response.status}`);
    });

    await test("invalid action query parameter is rejected", async () => {
      const app = new HttpFileServer({ root: testRoot });
      const response = await app.handleRequest(new Request("http://localhost/note.txt?action=open"));
      assert(response.status === 400, `Expected 400, got ${response.status}`);
    });

    await test("directory listing uses Name for download and Operations for preview/view", async () => {
      const app = new HttpFileServer({ root: testRoot });
      const response = await app.handleRequest(new Request("http://localhost/"));
      assert(response.status === 200, `Expected 200, got ${response.status}`);
      const body = await response.text();
      assert(body.includes('class="index-title"'), "Expected index title");
      assert(body.includes('<span class="index-path-current">root</span>'), "Expected root path in title");
      assert(body.includes("scrollbar-gutter: stable"), "Expected stable scrollbar gutter");
      assert(body.includes("note.txt"), "Expected note.txt in listing");
      assert(body.includes('id="previewDrawer"'), "Expected floating preview drawer markup");
      assert(body.includes('id="previewImageZoom"'), "Expected image zoom overlay markup");
      assert(body.includes('id="previewImageZoomViewport"'), "Expected image zoom viewport markup");
      assert(body.includes('id="previewCopy"'), "Expected preview copy button");
      assert(body.includes('aria-label="Copy preview text"'), "Expected icon-style copy button accessibility label");
      assert(body.includes('aria-label="Close preview panel"'), "Expected icon-style close button accessibility label");
      assert(body.includes("preview-textbox"), "Expected readonly preview textbox styles");
      assert(body.includes(".preview-image.zoomable"), "Expected zoom cursor style for preview image");
      assert(body.includes(".preview-image-zoom-viewport"), "Expected zoom viewport style for image preview");
      assert(body.includes("scrollbar-width: none"), "Expected hidden scrollbar style for image zoom viewport");
      assert(body.includes(".preview-image-zoom-viewport.draggable"), "Expected grab cursor style for zoom viewport");
      assert(body.includes('class="preview-link" href="note.txt?action=view"'), "Expected text preview link");
      assert(body.includes('class="preview-link" href="guide.rst?action=view"'), "Expected preview link for .rst");
      assert(body.includes('class="preview-link" href="cover.png"'), "Expected image preview link");
      assert(body.includes('note.txt?action=download'), "Expected download target for note.txt");
      assert(body.includes('<td class="name" data-sort="note.txt"><a class="name-link" href="note.txt?action=download"'), "Expected note.txt Name link to download");
      assert(body.includes('<td class="name" data-sort="cover.png"><a class="name-link" href="cover.png?action=download"'), "Expected cover.png Name link to download");
      assert(body.includes('<td class="name" data-sort="sub"><a class="name-link" href="sub/"'), "Expected directory Name link to keep navigation");
      assert(body.includes('note.txt?action=view'), "Expected view link for note.txt");
      assert(body.includes('LICENSE?action=view'), "Expected view link for LICENSE");
      assert(body.includes('guide.rst?action=view'), "Expected view link for .rst");
      assert(body.includes('>preview<'), "Expected preview label");
      assert(!body.includes('>download<'), "Expected download label removed from Operations column");
      assert(body.includes('>view<'), "Expected view label");
      assert(body.includes('class="name-icon file"'), "Expected file icon in Name column");
      assert(!body.includes('data-key="type"'), "Expected Type column to be removed");
      assert(body.includes('document.addEventListener("pointerdown"'), "Expected outside-click close hook");
      assert(body.includes('previewCopy?.addEventListener("click"'), "Expected copy click hook");
      assert(body.includes('previewImageZoomClose?.addEventListener("click"'), "Expected image zoom close hook");
      assert(body.includes('previewImageZoomViewport?.addEventListener("wheel"'), "Expected image zoom wheel hook");
      assert(body.includes('previewImageZoomViewport?.addEventListener("pointerdown"'), "Expected image zoom drag-start hook");
      assert(body.includes("previewImageZoomViewport.classList.add(\"dragging\")"), "Expected dragging state toggle for zoom viewport");
      assert(body.includes("Math.exp(-event.deltaY * 0.0015)"), "Expected smooth wheel zoom factor");
      assert(body.includes("openImageZoom(previewUrl, name)"), "Expected image zoom open hook");
      assert(body.includes('response.headers.get("content-length")'), "Expected content-length preview guard");
      assert(body.includes("response.body.getReader"), "Expected stream reader preview guard");
      assert(body.includes("new AbortController()"), "Expected abort controller for preview request lifecycle");
      assert(body.includes("activePreviewAbort.abort()"), "Expected active preview request cancellation hook");
      assert(body.includes('note-link.txt?action=download'), "Expected download link for in-root file symlink");
      assert(body.includes('note-link.txt?action=view'), "Expected view link for in-root file symlink");
      const secretIdx = body.indexOf('data-name="secret-link.txt"');
      assert(secretIdx !== -1, "Expected external symlink row to exist");
      const secretRow = body.slice(Math.max(0, secretIdx - 60), secretIdx + 420);
      assert(secretRow.includes('data-size-label="-"'), "Expected external symlink size to remain hidden");
      assert(secretRow.includes('data-modified-label="-"'), "Expected external symlink modified time to remain hidden");
      assert(!secretRow.includes("?action=download"), "Expected no download action for external symlink");
    });

    await test("directory listing renders clickable path links in title for nested path", async () => {
      const app = new HttpFileServer({ root: testRoot });
      const response = await app.handleRequest(new Request("http://localhost/nested/child/"));
      assert(response.status === 200, `Expected 200, got ${response.status}`);
      const body = await response.text();
      assert(body.includes('class="index-title"'), "Expected title with embedded path");
      assert(body.includes('<a class="index-path-link" href="/">root</a>'), "Expected root path link");
      assert(body.includes('<a class="index-path-link" href="/nested/">nested</a>'), "Expected nested path link");
      assert(body.includes('<span class="index-path-current">child</span>'), "Expected current path segment");
      assert(!body.includes('aria-label="Breadcrumb"'), "Expected standalone breadcrumb nav removed");
    });

    await test("directory listing includes keyboard shortcuts and sort persistence hooks", async () => {
      const app = new HttpFileServer({ root: testRoot });
      const response = await app.handleRequest(new Request("http://localhost/"));
      assert(response.status === 200, `Expected 200, got ${response.status}`);
      const body = await response.text();
      assert(body.includes('class="search-ghost"'), "Expected html-based search ghost hint");
      assert(!body.includes("Search by Name; press / to focus, Esc to clear; click headers to sort"), "Expected hint text removed");
      assert(body.includes('<span class="search-ghost" aria-hidden="true"><span>Type</span><kbd class="search-kbd">/</kbd><span>to search</span></span>'), "Expected boxed slash embedded in hint text");
      assert(body.includes('id="searchClear" class="search-clear"'), "Expected custom circular clear button");
      assert(body.includes("search::-webkit-search-cancel-button"), "Expected native search clear button hidden");
      assert(body.includes('searchClear?.addEventListener("click"'), "Expected clear button click behavior");
      assert(body.includes('"http-file-server:sort:" + location.pathname'), "Expected path-scoped sort storage key");
      assert(body.includes('event.key === "/"'), "Expected slash shortcut handling");
      assert(body.includes("searchInput.blur()"), "Expected Esc to blur search input");
    });

    await test("directory without trailing slash redirects", async () => {
      const app = new HttpFileServer({ root: testRoot });
      const response = await app.handleRequest(new Request("http://localhost/sub"));
      assert(response.status === 301, `Expected 301, got ${response.status}`);
    });

    await test("directory redirect is not protocol-relative", async () => {
      const app = new HttpFileServer({ root: testRoot });
      const response = await app.handleRequest(new Request("http://localhost//example.com"));
      assert(response.status === 301, `Expected 301, got ${response.status}`);
      const location = response.headers.get("Location") || "";
      assert(location.startsWith("/"), `Expected relative redirect location, got: ${location}`);
      assert(!location.startsWith("//"), `Expected redirect not to be protocol-relative, got: ${location}`);
    });

    await test("directory with index.html serves index", async () => {
      const app = new HttpFileServer({ root: testRoot });
      const response = await app.handleRequest(new Request("http://localhost/sub/"));
      assert(response.status === 200, `Expected 200, got ${response.status}`);
      const body = await response.text();
      assert(body.includes("<h1>sub</h1>"), "Expected sub index.html content");
    });

    await test("symlink escaping root is forbidden", async () => {
      const app = new HttpFileServer({ root: testRoot });
      const response = await app.handleRequest(new Request("http://localhost/secret-link.txt"));
      assert(response.status === 403, `Expected 403, got ${response.status}`);
    });

    await test("method not allowed returns 405", async () => {
      const app = new HttpFileServer({ root: testRoot });
      const response = await app.handleRequest(new Request("http://localhost/note.txt", { method: "POST" }));
      assert(response.status === 405, `Expected 405, got ${response.status}`);
      assert(response.headers.get("Allow") === "GET, HEAD", "Expected Allow header");
    });
  } finally {
    await rm(testRoot, { recursive: true, force: true });
    await rm(outsideRoot, { recursive: true, force: true });
  }

  console.log(`\n${passed}/${total} tests passed`);
  return passed === total;
}

if (import.meta.main) {
  const config = parseCliConfig(process.argv.slice(2));
  if (config.runTests) {
    const ok = await runSelfTests();
    process.exit(ok ? 0 : 1);
  }
  const app = new HttpFileServer(config);
  const server = app.start();
  console.log(`Serving ${app.rootDir}`);
  console.log(`http://${app.host}:${server.port}`);
}
