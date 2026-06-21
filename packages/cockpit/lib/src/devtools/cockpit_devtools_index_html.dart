const String cockpitDevtoolsIndexHtml = r'''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Flutter Cockpit Devtools</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #0c1110;
      --bg-2: #111917;
      --panel: #16211e;
      --panel-2: #1c2a26;
      --ink: #edf6f1;
      --muted: #a7b8b0;
      --soft: #789188;
      --line: #2b3e38;
      --line-strong: #47635a;
      --accent: #72e4b5;
      --accent-2: #e0c067;
      --bad: #ff7e73;
      --warn: #f4bc60;
      --good: #7dda9a;
      --running: #77b7ff;
      --code: #08110e;
      --shadow: rgba(0, 0, 0, .24);
      font-family: "Avenir Next", "Segoe UI", "Helvetica Neue", sans-serif;
      font-size: 13px;
    }
    * { box-sizing: border-box; }
    html, body { min-height: 100%; }
    body {
      margin: 0;
      background:
        radial-gradient(circle at 12% 8%, rgba(114, 228, 181, .14), transparent 28rem),
        radial-gradient(circle at 80% 0%, rgba(224, 192, 103, .12), transparent 24rem),
        linear-gradient(140deg, var(--bg), #0a0d0d 55%, #111814);
      color: var(--ink);
    }
    button, textarea, select, input { font: inherit; }
    button { color: inherit; }
    header {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 10px;
      align-items: center;
      padding: 10px clamp(10px, 1.8vw, 20px);
      border-bottom: 1px solid var(--line);
      background: rgba(12, 17, 16, .86);
      backdrop-filter: blur(16px);
      position: sticky;
      top: 0;
      z-index: 5;
    }
    h1 {
      margin: 0;
      font-size: 20px;
      line-height: 1;
      letter-spacing: -.02em;
      text-wrap: balance;
    }
    h2, h3 {
      margin: 0;
      letter-spacing: -.02em;
      line-height: 1.12;
      text-wrap: balance;
    }
    h2 { font-size: 14px; }
    h3 { font-size: 13px; }
    .header-copy {
      display: grid;
      gap: 6px;
      min-width: 0;
    }
    .subhead, .meta, .muted {
      color: var(--muted);
      font-family: "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
    }
    .subhead {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      font-size: 11px;
    }
    .status-strip {
      display: flex;
      flex-wrap: wrap;
      justify-content: flex-end;
      gap: 6px;
    }
    .header-actions {
      display: flex;
      flex-wrap: wrap;
      justify-content: flex-end;
      align-items: center;
      gap: 6px;
    }
    .panel-controls {
      display: flex;
      flex-wrap: wrap;
      justify-content: flex-end;
      gap: 5px;
    }
    .chip {
      display: inline-flex;
      align-items: center;
      gap: 7px;
      min-height: 24px;
      padding: 3px 7px;
      border: 1px solid var(--line);
      border-radius: 999px;
      background: rgba(28, 42, 38, .82);
      color: var(--muted);
      font: 11px/1.2 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
      white-space: nowrap;
    }
    .chip strong { color: var(--ink); font-weight: 700; }
    .dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--soft);
      box-shadow: 0 0 0 3px rgba(120, 145, 136, .16);
    }
    .dot.running { background: var(--running); }
    .dot.completed, .dot.succeeded { background: var(--good); }
    .dot.failed { background: var(--bad); }
    .dot.canceled, .dot.cancelled { background: var(--warn); }
    main {
      display: grid;
      grid-template-columns: minmax(220px, 300px) minmax(420px, 1fr) minmax(300px, 420px);
      gap: 8px;
      padding: 8px clamp(8px, 1.6vw, 18px) 18px;
      min-height: calc(100vh - 52px);
    }
    .rail, .workspace, .inspector {
      min-width: 0;
    }
    .rail, .inspector {
      align-self: start;
      position: sticky;
      top: 64px;
      max-height: calc(100vh - 74px);
      overflow: auto;
    }
    .workspace {
      display: grid;
      gap: 8px;
      align-content: start;
    }
    .panel {
      border: 1px solid var(--line);
      background: linear-gradient(180deg, rgba(28, 42, 38, .92), rgba(19, 29, 26, .92));
      box-shadow: 0 6px 14px var(--shadow);
    }
    .panel-body { padding: 8px; }
    .panel-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
      padding: 8px 9px;
      border-bottom: 1px solid var(--line);
      background: rgba(12, 17, 16, .26);
    }
    .collapsible-panel {
      position: relative;
    }
    .panel-heading-row {
      padding-right: 112px;
    }
    .panel-heading-actions {
      display: flex;
      align-items: center;
      justify-content: flex-end;
      gap: 5px;
      position: absolute;
      top: 6px;
      right: 8px;
      z-index: 1;
      max-width: calc(100% - 80px);
      overflow-x: auto;
      scrollbar-width: none;
      white-space: nowrap;
    }
    .panel-heading-actions::-webkit-scrollbar { display: none; }
    .run-detail-panel > .panel-summary { padding-right: 120px; }
    .runs-panel > .panel-summary { padding-right: 82px; }
    .timeline-panel > .panel-summary { padding-right: 220px; }
    .inspector-panel > .panel-summary { padding-right: 150px; }
    .collapsible-panel:not([open]) > .panel-header {
      border-bottom: 0;
    }
    .collapsible-panel:not([open]) > .panel-heading-row {
      border-bottom: 0;
    }
    .collapsible-panel:not([open]) > .panel-summary {
      padding-right: 9px;
    }
    .panel-summary {
      display: flex;
      justify-content: flex-start;
      align-items: center;
      gap: 6px;
      cursor: pointer;
      list-style: none;
    }
    .panel-summary::-webkit-details-marker {
      display: none;
    }
    .panel-summary::before {
      content: "+";
      flex: 0 0 auto;
      width: 14px;
      color: var(--soft);
      font: 11px/1 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
    }
    .collapsible-panel[open] > .panel-summary::before {
      content: "-";
    }
    .panel-summary h2 {
      flex: 0 0 auto;
    }
    .panel-summary h3 {
      flex: 0 0 auto;
    }
    .panel-summary .meta {
      min-width: 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .media-viewer-panel > .media-viewer-toolbar::before {
      margin-top: 1px;
    }
    .rail .panel, .inspector .panel, .workspace .panel {
      border-radius: 10px;
      overflow: hidden;
    }
    .run-list, .timeline-list, .artifact-grid {
      display: grid;
      gap: 6px;
    }
    .run {
      width: 100%;
      display: grid;
      gap: 5px;
      padding: 7px;
      text-align: left;
      cursor: pointer;
      border: 1px solid transparent;
      border-radius: 8px;
      background: rgba(22, 33, 30, .72);
      transition: border-color .16s ease, background .16s ease, transform .16s ease;
    }
    .run:hover, .run:focus-visible {
      border-color: var(--line-strong);
      background: rgba(31, 48, 43, .9);
      outline: none;
    }
    .run[aria-current="true"] {
      border-color: rgba(114, 228, 181, .72);
      background: rgba(33, 63, 53, .8);
    }
    .run-title {
      display: flex;
      align-items: center;
      gap: 6px;
      min-width: 0;
    }
    .run-title strong {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      font-size: 12px;
    }
    .run-meta {
      display: grid;
      gap: 2px;
      color: var(--muted);
      font: 10px/1.3 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
    }
    .run-search, textarea, select {
      width: 100%;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: rgba(8, 17, 14, .9);
      color: var(--ink);
      outline: none;
    }
    .run-search {
      margin-bottom: 6px;
      padding: 7px 8px;
      font: 11px/1.3 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
    }
    .run-search:focus, textarea:focus, select:focus {
      border-color: rgba(114, 228, 181, .72);
      box-shadow: 0 0 0 3px rgba(114, 228, 181, .12);
    }
    .overview {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 1px;
      border: 1px solid var(--line);
      border-radius: 10px;
      overflow: hidden;
      background: var(--line);
    }
    .run-detail .overview {
      max-height: 92px;
    }
    .compact-summary {
      min-width: 0;
    }
    .metric {
      display: grid;
      gap: 4px;
      min-height: 42px;
      padding: 6px;
      background: rgba(20, 31, 28, .96);
      min-width: 0;
      overflow: hidden;
    }
    .metric span {
      color: var(--muted);
      font: 10px/1.2 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .metric strong {
      font-size: 17px;
      line-height: 1;
      letter-spacing: -.03em;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .metric strong.compact {
      font-size: 13px;
      line-height: 1.18;
    }
    .run-detail {
      display: grid;
      grid-template-columns: minmax(0, 1.1fr) minmax(260px, .9fr);
      gap: 8px;
      align-items: start;
    }
    .run-facts-scroll {
      max-height: 92px;
      overflow: auto;
      overscroll-behavior: contain;
      padding-right: 3px;
    }
    .facts {
      display: grid;
      grid-template-columns: 74px minmax(0, 1fr);
      column-gap: 8px;
      row-gap: 3px;
    }
    .facts dt, .facts dd {
      margin: 0;
      min-width: 0;
      overflow-wrap: anywhere;
    }
    .facts dt {
      color: var(--soft);
      font: 10px/1.25 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
    }
    .facts dd {
      padding-bottom: 3px;
      border-bottom: 1px solid rgba(43, 62, 56, .72);
    }
    .facts dd:last-child { border-bottom: 0; }
    .fact {
      display: grid;
      grid-template-columns: 74px minmax(0, 1fr);
      gap: 8px;
      padding: 5px 0;
      border-bottom: 1px solid rgba(43, 62, 56, .72);
    }
    .fact:last-child { border-bottom: 0; }
    .fact dt {
      margin: 0;
      color: var(--soft);
      font: 10px/1.25 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
    }
    .fact dd {
      margin: 0;
      min-width: 0;
      overflow-wrap: anywhere;
    }
    .launcher-grid {
      display: grid;
      gap: 8px;
    }
    textarea {
      min-height: 150px;
      padding: 8px;
      resize: vertical;
      font: 11px/1.45 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
      tab-size: 2;
    }
    select {
      padding: 7px 8px;
      font: 11px/1.3 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
    }
    .actions {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 6px;
    }
    .action {
      border: 1px solid rgba(114, 228, 181, .46);
      border-radius: 8px;
      background: #10251f;
      color: var(--accent);
      min-height: 32px;
      padding: 6px 8px;
      cursor: pointer;
      font-weight: 700;
      transition: transform .16s ease, border-color .16s ease, background .16s ease;
    }
    .action:hover, .action:focus-visible {
      transform: translateY(-1px);
      border-color: var(--accent);
      outline: none;
    }
    .action.primary {
      background: var(--accent);
      color: #062018;
    }
    .action.ghost {
      border-color: var(--line);
      background: rgba(8, 17, 14, .65);
      color: var(--muted);
    }
    .timeline-toolbar, .tabs {
      display: flex;
      flex-wrap: wrap;
      gap: 5px;
      align-items: center;
    }
    .panel-heading-actions.timeline-toolbar,
    .panel-heading-actions.tabs {
      flex-wrap: nowrap;
    }
    .tab, .tool-button {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      border: 1px solid var(--line);
      border-radius: 999px;
      background: rgba(8, 17, 14, .55);
      color: var(--muted);
      min-height: 24px;
      padding: 4px 7px;
      cursor: pointer;
      font: 10px/1.15 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
      text-decoration: none;
    }
    .tab[aria-selected="true"], .tool-button.active {
      border-color: rgba(114, 228, 181, .62);
      color: var(--accent);
      background: rgba(114, 228, 181, .1);
    }
    .timeline-list {
      position: relative;
      padding-left: 10px;
    }
    .timeline-shell {
      display: grid;
      gap: 5px;
    }
    .timeline-context {
      display: flex;
      flex-wrap: wrap;
      gap: 4px;
      align-items: center;
      color: var(--muted);
      font: 10px/1.2 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
    }
    .context-pill {
      max-width: 100%;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      border: 1px solid var(--line);
      border-radius: 999px;
      background: rgba(8, 17, 14, .5);
      padding: 3px 6px;
    }
    .context-pill strong {
      color: var(--ink);
      font-weight: 650;
    }
    .context-pill.warn strong {
      color: var(--warn);
    }
    .timeline-scroll {
      max-height: min(520px, calc(100vh - 188px));
      overflow: auto;
      overscroll-behavior: contain;
      padding-right: 4px;
    }
    .timeline-list::before {
      content: "";
      position: absolute;
      top: 2px;
      bottom: 2px;
      left: 20px;
      width: 1px;
      background: linear-gradient(var(--line-strong), rgba(43, 62, 56, 0));
    }
    .event {
      position: relative;
      border: 1px solid var(--line);
      border-radius: 9px;
      background: rgba(13, 21, 18, .88);
      overflow: hidden;
    }
    .event::before {
      content: "";
      position: absolute;
      top: 16px;
      left: -1px;
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: var(--soft);
      box-shadow: 0 0 0 3px #101916;
    }
    .event.running::before { background: var(--running); }
    .event.completed::before, .event.succeeded::before { background: var(--good); }
    .event.failed::before { background: var(--bad); }
    .event.canceled::before, .event.cancelled::before { background: var(--warn); }
    .event[aria-selected="true"] {
      border-color: rgba(114, 228, 181, .72);
      background: rgba(24, 43, 37, .94);
    }
    .event > .event-summary {
      padding: 7px 8px 7px 16px;
      align-items: flex-start;
    }
    .event > .event-summary::before {
      margin-top: 3px;
    }
    .event-summary-content {
      display: grid;
      gap: 5px;
      min-width: 0;
      flex: 1 1 auto;
    }
    .event-head {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 6px;
      align-items: start;
    }
    .event-title {
      display: flex;
      flex-wrap: wrap;
      gap: 4px;
      align-items: center;
      min-width: 0;
    }
    .event-title strong {
      overflow-wrap: anywhere;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      border: 1px solid var(--line);
      border-radius: 999px;
      padding: 2px 5px;
      color: var(--muted);
      background: rgba(8, 17, 14, .58);
      font: 10px/1.1 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
    }
    .badge.good { color: var(--good); border-color: rgba(125, 218, 154, .42); }
    .badge.bad { color: var(--bad); border-color: rgba(255, 126, 115, .42); }
    .badge.warn { color: var(--warn); border-color: rgba(244, 188, 96, .42); }
    .badge.running { color: var(--running); border-color: rgba(119, 183, 255, .42); }
    .event-description {
      color: var(--muted);
      line-height: 1.45;
      overflow-wrap: anywhere;
    }
    .event:not([open]) .event-description,
    .event:not(.expanded) .event-description {
      display: -webkit-box;
      -webkit-box-orient: vertical;
      -webkit-line-clamp: 3;
      max-height: 4.35em;
      overflow: hidden;
    }
    .event[open] .event-description,
    .event.expanded .event-description {
      max-height: 9em;
      overflow: auto;
      overscroll-behavior: contain;
      padding-right: 3px;
    }
    .event-details {
      display: none;
      border-top: 1px solid rgba(43, 62, 56, .72);
      padding: 6px;
    }
    .event[open] > .event-details,
    .event.expanded .event-details { display: grid; gap: 6px; }
    .artifact-grid {
      grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
    }
    .artifact {
      display: block;
      min-width: 0;
      border: 1px solid var(--line);
      border-radius: 9px;
      background: rgba(8, 17, 14, .58);
      overflow: hidden;
    }
    .artifact-summary {
      align-items: flex-start;
      padding: 7px;
    }
    .artifact-summary::before {
      margin-top: 2px;
    }
    .artifact-body {
      display: grid;
      gap: 6px;
      padding: 0 7px 7px;
    }
    .artifact:not([open]) > .artifact-summary {
      padding-bottom: 7px;
    }
    .artifact-media {
      display: grid;
      place-items: center;
      position: relative;
      aspect-ratio: 16 / 10;
      overflow: hidden;
      border-radius: 7px;
      background:
        linear-gradient(135deg, rgba(114, 228, 181, .09), transparent),
        #07100d;
      border: 1px solid rgba(43, 62, 56, .72);
    }
    .artifact-media.clickable {
      cursor: zoom-in;
    }
    .artifact-media.clickable:hover,
    .artifact-media.clickable:focus-visible {
      border-color: rgba(114, 228, 181, .68);
      outline: none;
    }
    .artifact-media img, .artifact-media video {
      width: 100%;
      height: 100%;
      object-fit: contain;
      display: block;
      background: #050807;
    }
    .artifact-media video {
      pointer-events: none;
    }
    .artifact-media .placeholder {
      padding: 8px;
      color: var(--muted);
      text-align: center;
      font: 11px/1.3 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
      overflow-wrap: anywhere;
    }
    .media-status {
      position: absolute;
      left: 5px;
      bottom: 5px;
      max-width: calc(100% - 10px);
      padding: 3px 5px;
      border: 1px solid rgba(43, 62, 56, .84);
      border-radius: 999px;
      background: rgba(5, 8, 7, .78);
      color: var(--muted);
      font: 9px/1.1 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .media-status.ready { color: var(--good); }
    .media-status.error {
      color: var(--bad);
      border-color: rgba(255, 126, 115, .46);
    }
    .artifact-caption {
      display: grid;
      gap: 3px;
      min-width: 0;
      font: 10px/1.3 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
    }
    .artifact-caption strong {
      color: var(--ink);
      overflow-wrap: anywhere;
    }
    .artifact-caption span {
      color: var(--muted);
      overflow-wrap: anywhere;
    }
    .artifact-open {
      color: var(--accent);
      text-decoration: none;
      font: 10px/1.15 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
    }
    .artifact-open:hover, .artifact-open:focus-visible {
      text-decoration: underline;
      outline: none;
    }
    body.media-viewer-open {
      overflow: hidden;
    }
    .media-viewer[hidden] {
      display: none;
    }
    .media-viewer {
      position: fixed;
      inset: 0;
      z-index: 40;
      display: grid;
      place-items: center;
      padding: clamp(12px, 2vw, 28px);
    }
    .media-viewer-backdrop {
      position: absolute;
      inset: 0;
      background: rgba(3, 7, 6, .82);
    }
    .media-viewer-dialog {
      position: relative;
      z-index: 1;
      display: grid;
      grid-template-rows: auto minmax(0, 1fr);
      width: min(1180px, 96vw);
      height: min(820px, 92vh);
      border: 1px solid var(--line-strong);
      border-radius: 16px;
      background: #07100d;
      box-shadow: 0 20px 48px rgba(0, 0, 0, .42);
      overflow: hidden;
    }
    .media-viewer-panel:not([open]) {
      grid-template-rows: auto;
      height: auto;
      align-self: start;
    }
    .media-viewer-panel:not([open]) > .media-viewer-stage {
      display: none;
    }
    .media-viewer-panel > .media-viewer-toolbar {
      cursor: pointer;
      list-style: none;
    }
    .media-viewer-panel > .media-viewer-toolbar::-webkit-details-marker {
      display: none;
    }
    .media-viewer-toolbar {
      display: flex;
      gap: 6px;
      align-items: center;
      padding: 12px;
      padding-right: 390px;
      border-bottom: 1px solid var(--line);
      background: rgba(13, 21, 18, .96);
    }
    .media-viewer-title {
      min-width: 0;
      display: grid;
      gap: 4px;
      flex: 1 1 auto;
    }
    .media-viewer-title strong,
    .media-viewer-title span {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .media-viewer-actions {
      display: flex;
      flex-wrap: wrap;
      justify-content: flex-end;
      gap: 8px;
      position: absolute;
      top: 10px;
      right: 12px;
      z-index: 2;
      max-width: min(380px, calc(100% - 96px));
      overflow-x: auto;
      scrollbar-width: none;
      white-space: nowrap;
    }
    .media-viewer-actions::-webkit-scrollbar { display: none; }
    .media-viewer-stage {
      display: grid;
      place-items: center;
      overflow: auto;
      padding: 12px;
      background:
        radial-gradient(circle at 18% 0%, rgba(114, 228, 181, .08), transparent 24rem),
        #050807;
    }
    .media-viewer-stage img,
    .media-viewer-stage video {
      max-width: 100%;
      max-height: 100%;
      object-fit: contain;
      background: #020403;
    }
    .media-viewer-stage.actual {
      place-items: start;
    }
    .media-viewer-stage.actual img,
    .media-viewer-stage.actual video {
      width: auto;
      height: auto;
      max-width: none;
      max-height: none;
    }
    .media-viewer-placeholder {
      max-width: 70ch;
      padding: 24px;
      border: 1px dashed var(--line-strong);
      border-radius: 14px;
      color: var(--muted);
      overflow-wrap: anywhere;
      text-align: center;
      font: 12px/1.45 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
    }
    .code-view {
      border: 1px solid var(--line);
      border-radius: 12px;
      overflow: auto;
      background: var(--code);
      color: #dff5eb;
      max-height: 460px;
      padding: 10px;
      font: 12px/1.55 "SFMono-Regular", "Cascadia Code", "Liberation Mono", monospace;
    }
    .tree {
      display: grid;
      gap: 2px;
      min-width: max-content;
    }
    .tree details {
      margin: 0;
      padding-left: 14px;
      border-left: 1px solid rgba(72, 103, 94, .46);
    }
    .tree details.root {
      padding-left: 0;
      border-left: 0;
    }
    .tree summary {
      cursor: pointer;
      list-style: none;
      outline: none;
      white-space: nowrap;
    }
    .tree summary::-webkit-details-marker { display: none; }
    .tree summary::before {
      content: "+";
      display: inline-block;
      width: 14px;
      color: var(--soft);
    }
    .tree details[open] > summary::before { content: "-"; }
    .tree-row {
      display: block;
      min-height: 18px;
      white-space: nowrap;
    }
    .tree-key { color: #8bdabf; }
    .tree-string { color: #efd78f; }
    .tree-number { color: #9ec8ff; }
    .tree-bool { color: #ffb1a9; }
    .tree-null { color: #a7b8b0; }
    .tree-type { color: var(--soft); }
    .tree-leaf {
      display: block;
      padding-left: 14px;
      white-space: nowrap;
    }
    .yaml-tree .yaml-line {
      display: block;
      white-space: pre;
      color: #dff5eb;
    }
    .yaml-tree details {
      padding-left: 16px;
    }
    .empty {
      border: 1px dashed var(--line-strong);
      border-radius: 14px;
      padding: 18px;
      color: var(--muted);
      text-align: center;
      background: rgba(8, 17, 14, .38);
    }
    .split {
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
      gap: 12px;
    }
    .subpanel {
      min-width: 0;
      border: 1px solid var(--line);
      border-radius: 10px;
      overflow: hidden;
      background: rgba(8, 17, 14, .42);
    }
    .subpanel-summary {
      padding: 7px 8px;
      border-bottom: 1px solid var(--line);
      background: rgba(12, 17, 16, .3);
    }
    .subpanel-body {
      padding: 6px;
    }
    .subpanel:not([open]) > .subpanel-summary {
      border-bottom: 0;
    }
    .inline-panel {
      min-width: 0;
      border: 1px solid rgba(43, 62, 56, .84);
      border-radius: 8px;
      overflow: hidden;
      background: rgba(8, 17, 14, .38);
    }
    .inline-panel-summary {
      padding: 6px 7px;
      border-bottom: 1px solid rgba(43, 62, 56, .72);
      background: rgba(12, 17, 16, .24);
    }
    .inline-panel-summary .meta {
      font-size: 10px;
    }
    .inline-panel-body {
      padding: 6px;
    }
    .inline-panel:not([open]) > .inline-panel-summary {
      border-bottom: 0;
    }
    .sr-only {
      position: absolute;
      width: 1px;
      height: 1px;
      padding: 0;
      margin: -1px;
      overflow: hidden;
      clip: rect(0, 0, 0, 0);
      white-space: nowrap;
      border: 0;
    }
    @media (prefers-reduced-motion: reduce) {
      *, *::before, *::after {
        animation-duration: .001ms !important;
        transition-duration: .001ms !important;
        scroll-behavior: auto !important;
      }
    }
    @media (max-width: 1180px) and (min-width: 760px) {
      main {
        grid-template-columns: minmax(180px, 240px) minmax(0, 1fr);
      }
      .inspector {
        position: static;
        max-height: none;
        grid-column: 1 / -1;
      }
    }
    @media (max-width: 759px) {
      header {
        grid-template-columns: minmax(0, 1fr);
      }
      .status-strip { justify-content: flex-start; }
      main {
        grid-template-columns: 1fr;
      }
      .rail, .inspector {
        position: static;
        max-height: none;
      }
      .split {
        grid-template-columns: 1fr;
      }
      .run-detail {
        grid-template-columns: minmax(0, 1fr) minmax(170px, .9fr);
      }
      .media-viewer-toolbar {
        gap: 8px;
        padding-right: 194px;
      }
      .media-viewer-actions {
        flex-wrap: nowrap;
        gap: 6px;
        max-width: min(186px, calc(100% - 76px));
      }
      .overview {
        grid-template-columns: repeat(4, minmax(0, 1fr));
      }
      .facts {
        grid-template-columns: 78px minmax(0, 1fr);
      }
      .compact-launcher-summary {
        align-items: flex-start;
      }
    }
    @media (max-width: 520px) {
      h1 { font-size: 17px; }
      .subhead { font-size: 10px; }
      .chip:nth-child(n + 3) { display: none; }
      .run-detail {
        grid-template-columns: 1fr;
      }
      .run-facts-scroll {
        max-height: 92px;
      }
    }
  </style>
</head>
<body data-density="compact">
  <header>
    <div class="header-copy">
      <h1>Flutter Cockpit Devtools</h1>
      <div class="subhead" id="status">loading local live history</div>
    </div>
    <div class="header-actions">
      <div class="status-strip" aria-label="Run status summary">
        <div class="chip"><span class="dot" id="selectedStatusDot"></span><strong id="selectedStatus">unknown</strong></div>
        <div class="chip"><span>runs</span><strong id="runCount">0</strong></div>
        <div class="chip"><span>events</span><strong id="eventCount">0</strong></div>
        <div class="chip"><span>artifacts</span><strong id="artifactCount">0</strong></div>
      </div>
      <div class="panel-controls" aria-label="Panel controls">
        <button class="tool-button" type="button" id="collapsePanels">collapse all</button>
        <button class="tool-button" type="button" id="expandPanels">expand all</button>
      </div>
    </div>
  </header>
  <main>
    <aside class="rail">
      <details class="panel collapsible-panel runs-panel" data-testid="runs-panel" data-panel-id="runs" data-panel-persist="true" aria-label="Runs" open>
        <summary class="panel-header panel-heading-row panel-summary compact-runs-summary">
          <h2>Runs</h2>
        </summary>
        <div class="panel-heading-actions">
          <button class="tool-button" type="button" id="refreshNow">Refresh</button>
        </div>
        <div class="panel-body">
          <label class="sr-only" for="scopeSelect">History scope</label>
          <select class="run-search" id="scopeSelect" data-testid="scope-select" aria-label="History scope">
            <option value="">current scope</option>
          </select>
          <label class="sr-only" for="runSearch">Filter runs</label>
          <input class="run-search" id="runSearch" type="search" placeholder="filter run, task, platform">
          <div class="run-list" id="runs" data-testid="run-list"></div>
        </div>
      </details>
    </aside>
    <div class="workspace">
      <details class="panel collapsible-panel run-detail-panel" data-testid="run-detail" data-panel-id="run-detail" data-panel-persist="true">
        <summary class="panel-header panel-heading-row panel-summary compact-run-summary">
          <h2 id="run-detail-heading">Run Detail</h2>
        </summary>
        <div class="panel-heading-actions tabs" aria-label="Detail actions">
          <button class="tab" type="button" id="selectLatest">latest</button>
          <button class="tab" type="button" id="copyRunId">copy id</button>
        </div>
        <div class="panel-body run-detail">
          <div class="compact-summary">
            <div class="overview" id="overview"></div>
          </div>
          <div class="run-facts-scroll">
            <dl class="facts" id="runFacts"></dl>
          </div>
        </div>
      </details>
      <details class="panel collapsible-panel timeline-panel" data-testid="timeline-panel" data-panel-id="timeline" data-panel-persist="true" open>
        <summary class="panel-header panel-heading-row panel-summary">
          <h2>Timeline</h2>
        </summary>
        <div class="panel-heading-actions timeline-toolbar">
          <button class="tool-button active" type="button" data-filter="all" aria-pressed="true">all</button>
          <button class="tool-button" type="button" data-filter="failed" aria-pressed="false">errors</button>
          <button class="tool-button" type="button" data-filter="artifact" aria-pressed="false">artifacts</button>
          <button class="tool-button" type="button" id="expandTimeline" aria-pressed="false">expand</button>
        </div>
        <div class="panel-body">
          <div class="timeline-shell">
            <div class="timeline-context" id="timelineContext" data-testid="timeline-context">loading context</div>
            <div class="meta" id="timelineSummary">loading events</div>
            <div class="timeline-scroll" data-testid="timeline-scroll">
              <div class="timeline-list" id="timeline" data-testid="timeline-list"></div>
            </div>
          </div>
        </div>
      </details>
      <details class="panel collapsible-panel evidence-panel" data-testid="evidence-panel" data-panel-id="evidence" data-panel-persist="true" open>
        <summary class="panel-header panel-summary">
          <h2>Evidence Gallery</h2>
          <span class="meta" id="artifactSummary">no artifacts</span>
        </summary>
        <div class="panel-body">
          <div class="artifact-grid" id="artifactGallery" data-testid="artifact-gallery"></div>
        </div>
      </details>
      <details class="panel collapsible-panel launcher-panel" data-testid="launcher-panel" data-panel-id="launcher" data-panel-persist="true">
        <summary class="panel-header panel-summary compact-launcher-summary">
          <h2>Workflow Launcher</h2>
          <span class="meta">paste YAML/JSON only when you need to run from the board</span>
        </summary>
        <div class="panel-body launcher-grid">
          <div class="tabs" aria-label="Payload format">
            <button class="tab" type="button" id="formatJson">json</button>
            <button class="tab" type="button" id="formatYaml">yaml</button>
          </div>
          <select id="launchKind" aria-label="Launch kind">
            <option value="runScript">runScript workflow</option>
            <option value="validateTask">validateTask config</option>
          </select>
          <textarea id="launchPayload" spellcheck="false">schemaVersion: 1
sessionId: dashboard-session
taskId: dashboard-task
platform: macos
steps:
  - stepId: assert-ready
    stepType: command
    description: Verify the app is ready.
    command:
      commandId: assert-ready
      commandType: assertText
      parameters:
        text: Ready
</textarea>
          <div class="actions">
            <button class="action" id="parseWorkflow" type="button">Parse workflow</button>
            <button class="action primary" id="submitRun" type="button">Submit run</button>
          </div>
          <div class="split">
            <details class="subpanel collapsible-panel" data-testid="launch-result-panel" data-panel-id="launch-result" open>
              <summary class="subpanel-summary panel-summary">
                <h3>Parsed / Result</h3>
              </summary>
              <div class="subpanel-body">
                <div class="code-view" id="launchResult">{}</div>
              </div>
            </details>
            <details class="subpanel collapsible-panel" data-testid="payload-preview-panel" data-panel-id="payload-preview" open>
              <summary class="subpanel-summary panel-summary">
                <h3>Payload Tree</h3>
              </summary>
              <div class="subpanel-body">
                <div class="code-view" id="payloadPreview"></div>
              </div>
            </details>
          </div>
        </div>
      </details>
    </div>
    <aside class="inspector">
      <details class="panel collapsible-panel inspector-panel" data-testid="inspector-panel" data-panel-id="inspector" data-panel-persist="true" open>
        <summary class="panel-header panel-heading-row panel-summary">
          <h2>Inspector</h2>
        </summary>
        <div class="panel-heading-actions tabs" role="tablist" aria-label="Inspector view">
          <button class="tab" type="button" role="tab" id="tabEvent" aria-selected="true">event</button>
          <button class="tab" type="button" role="tab" id="tabState" aria-selected="false">state</button>
          <button class="tab" type="button" role="tab" id="tabYaml" aria-selected="false">yaml</button>
        </div>
        <div class="panel-body">
          <div class="code-view" id="inspector"></div>
        </div>
      </details>
    </aside>
  </main>
  <div class="media-viewer" id="mediaViewer" data-testid="media-viewer" hidden>
    <div class="media-viewer-backdrop" id="mediaViewerBackdrop"></div>
    <details class="media-viewer-dialog media-viewer-panel collapsible-panel" data-panel-id="media-viewer" data-panel-persist="true" open role="dialog" aria-modal="true" aria-labelledby="mediaViewerTitle">
      <summary class="media-viewer-toolbar panel-summary">
        <div class="media-viewer-title">
          <strong id="mediaViewerTitle">Artifact</strong>
          <span class="meta" id="mediaViewerPath"></span>
        </div>
      </summary>
      <div class="media-viewer-actions">
        <button class="tool-button" type="button" id="mediaViewerSize">actual size</button>
        <button class="tool-button" type="button" id="mediaViewerCopy">copy link</button>
        <a class="tool-button" id="mediaViewerDownload" href="#" download>download</a>
        <a class="tool-button" id="mediaViewerOpen" href="#" target="_blank" rel="noreferrer">open</a>
        <button class="tool-button" type="button" id="mediaViewerClose">close</button>
      </div>
      <div class="media-viewer-stage" id="mediaViewerStage"></div>
    </details>
  </div>
  <script>
    const searchParams = new URLSearchParams(location.search);
    const token = searchParams.get('token') || '';
    const initialScope = searchParams.get('scope') || 'current';
    const MAX_EVENTS = 350;
    const TIMELINE_RENDER_LIMIT = 120;
    const INITIAL_EVENT_TAIL_BYTES = 262144;
    const AUTO_REFRESH_MS = 1500;
    const EAGER_ARTIFACT_COUNT = 8;
    const RUN_PAGE_LIMIT = 200;
    const PANEL_STATE_STORAGE_KEY = 'flutter-cockpit-devtools-panels:v1';
    const state = {
      scopes: [],
      selectedScopeId: (initialScope === 'current' || initialScope === 'latest') ? '' : initialScope,
      pinnedScopeId: (initialScope === 'current' || initialScope === 'latest') ? null : initialScope || null,
      scopeMode: initialScope === 'latest' ? 'latest' : initialScope === 'current' ? 'current' : initialScope === 'all' ? 'all' : 'scope',
      requestedScope: initialScope,
      currentScopeId: '',
      activeScopeId: '',
      activeScopeKind: '',
      activeScopeLabel: '',
      totalRunCount: 0,
      filteredRunCount: 0,
      returnedRunCount: 0,
      hasMoreRuns: false,
      runs: [],
      selectedRunId: null,
      selectedEventSeq: null,
      selectedEventKey: null,
      liveState: null,
      bundleSummary: null,
      job: null,
      events: [],
      scopeEventCount: 0,
      returnedScopeEventCount: 0,
      hasMoreScopeEvents: false,
      eventFilter: 'all',
      inspectorTab: 'event',
      expandAll: false,
      mediaViewerArtifact: null,
      mediaViewerActualSize: false,
      mediaViewerReturnFocus: null,
      payloadPreviewDirty: true,
      dynamicPanelOpen: {},
      eventsByteOffset: 0,
      eventsPartialLine: '',
      eventsHaveLoaded: false,
      lastFetchedEventCount: null,
      lastScopeEventsKey: '',
      lastLiveStateText: '',
      lastBundleSummaryKey: '',
      lastRenderedSignature: '',
      hasLoadedRuns: false,
      hasResolvedInitialScope: initialScope !== 'current',
      hasStoredPanelState: false,
      selectionRevision: 0,
      timer: null
    };

    const els = {
      status: document.getElementById('status'),
      selectedStatus: document.getElementById('selectedStatus'),
      selectedStatusDot: document.getElementById('selectedStatusDot'),
      runCount: document.getElementById('runCount'),
      eventCount: document.getElementById('eventCount'),
      artifactCount: document.getElementById('artifactCount'),
      runs: document.getElementById('runs'),
      runsPanel: document.querySelector('[data-testid="runs-panel"]'),
      scopeSelect: document.getElementById('scopeSelect'),
      runSearch: document.getElementById('runSearch'),
      overview: document.getElementById('overview'),
      runFacts: document.getElementById('runFacts'),
      timeline: document.getElementById('timeline'),
      timelineScroll: document.querySelector('[data-testid="timeline-scroll"]'),
      timelineContext: document.getElementById('timelineContext'),
      timelineSummary: document.getElementById('timelineSummary'),
      artifactGallery: document.getElementById('artifactGallery'),
      artifactSummary: document.getElementById('artifactSummary'),
      launcherPanel: document.querySelector('[data-testid="launcher-panel"]'),
      collapsePanels: document.getElementById('collapsePanels'),
      expandPanels: document.getElementById('expandPanels'),
      inspector: document.getElementById('inspector'),
      launchKind: document.getElementById('launchKind'),
      launchPayload: document.getElementById('launchPayload'),
      launchResult: document.getElementById('launchResult'),
      payloadPreview: document.getElementById('payloadPreview'),
      mediaViewer: document.getElementById('mediaViewer'),
      mediaViewerPanel: document.querySelector('[data-panel-id="media-viewer"]'),
      mediaViewerStage: document.getElementById('mediaViewerStage'),
      mediaViewerTitle: document.getElementById('mediaViewerTitle'),
      mediaViewerPath: document.getElementById('mediaViewerPath'),
      mediaViewerSize: document.getElementById('mediaViewerSize'),
      mediaViewerCopy: document.getElementById('mediaViewerCopy'),
      mediaViewerDownload: document.getElementById('mediaViewerDownload'),
      mediaViewerOpen: document.getElementById('mediaViewerOpen'),
      mediaViewerClose: document.getElementById('mediaViewerClose'),
      mediaViewerBackdrop: document.getElementById('mediaViewerBackdrop')
    };

    function api(path) {
      const url = new URL(path, location.origin);
      if (token) url.searchParams.set('token', token);
      return url;
    }

    async function fetchJson(path) {
      const response = await fetch(api(path), {cache: 'no-store'});
      if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
      return response.json();
    }

    async function fetchText(path) {
      const response = await fetch(api(path), {cache: 'no-store'});
      if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
      return response.text();
    }

    async function fetchTextResponse(path, options = {}) {
      const response = await fetch(api(path), {cache: 'no-store', ...options});
      if (!response.ok && response.status !== 206) {
        throw new Error(`${response.status} ${response.statusText}`);
      }
      return response;
    }

    async function postJson(path, body) {
      const response = await fetch(api(path), {
        method: 'POST',
        headers: {'content-type': 'application/json'},
        body: JSON.stringify(body)
      });
      const text = await response.text();
      let payload;
      try { payload = JSON.parse(text); } catch (_) { payload = {raw: text}; }
      if (!response.ok) {
        const message = payload.message || payload.error || response.statusText;
        throw new Error(`${response.status} ${message}`);
      }
      return payload;
    }

    function clearNode(node) {
      node.textContent = '';
    }

    function appendText(parent, text, className) {
      const span = document.createElement('span');
      if (className) span.className = className;
      span.textContent = text;
      parent.appendChild(span);
      return span;
    }

    function appendElement(parent, tagName, text, className) {
      const element = document.createElement(tagName);
      if (className) element.className = className;
      element.textContent = text;
      parent.appendChild(element);
      return element;
    }

    function createInlinePanel(title, summaryText, className = '') {
      const panel = document.createElement('details');
      panel.className = `inline-panel collapsible-panel${className ? ` ${className}` : ''}`;
      panel.open = true;
      const summary = document.createElement('summary');
      summary.className = 'inline-panel-summary panel-summary';
      appendElement(summary, 'h3', title);
      if (summaryText) appendText(summary, summaryText, 'meta');
      panel.appendChild(summary);
      const body = document.createElement('div');
      body.className = 'inline-panel-body';
      panel.appendChild(body);
      return {panel, body};
    }

    function textValue(value) {
      if (value === null || value === undefined) return '';
      if (typeof value === 'string') return value;
      if (typeof value === 'number' || typeof value === 'boolean') return String(value);
      return JSON.stringify(value);
    }

    function formatTime(value) {
      if (!value) return '';
      const date = new Date(value);
      if (Number.isNaN(date.getTime())) return String(value);
      return date.toLocaleTimeString([], {
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
      });
    }

    function formatDateTime(value) {
      if (!value) return '';
      const date = new Date(value);
      if (Number.isNaN(date.getTime())) return String(value);
      return date.toLocaleString();
    }

    function statusClass(status) {
      const value = String(status || 'unknown').toLowerCase();
      if (value === 'succeeded' || value === 'completed') return 'completed';
      if (value === 'failed') return 'failed';
      if (value === 'running') return 'running';
      if (value === 'canceled' || value === 'cancelled') return 'canceled';
      return 'unknown';
    }

    function statusBadgeClass(status) {
      const value = statusClass(status);
      if (value === 'completed') return 'good';
      if (value === 'failed') return 'bad';
      if (value === 'canceled') return 'warn';
      if (value === 'running') return 'running';
      return '';
    }

    function isObject(value) {
      return value !== null && typeof value === 'object' && !Array.isArray(value);
    }

    function renderScalar(value) {
      const span = document.createElement('span');
      if (typeof value === 'string') {
        span.className = 'tree-string';
        span.textContent = JSON.stringify(value);
      } else if (typeof value === 'number') {
        span.className = 'tree-number';
        span.textContent = String(value);
      } else if (typeof value === 'boolean') {
        span.className = 'tree-bool';
        span.textContent = String(value);
      } else if (value === null) {
        span.className = 'tree-null';
        span.textContent = 'null';
      } else {
        span.textContent = String(value);
      }
      return span;
    }

    function jsonSummary(value) {
      if (Array.isArray(value)) return `[${value.length}]`;
      if (isObject(value)) return `{${Object.keys(value).length}}`;
      return '';
    }

    function renderJsonNode(key, value, depth = 0) {
      const label = key === null ? 'root' : key;
      if (Array.isArray(value) || isObject(value)) {
        const details = document.createElement('details');
        details.open = depth < 2;
        if (key === null) details.classList.add('root');
        const summary = document.createElement('summary');
        appendText(summary, label, 'tree-key');
        appendText(summary, ` ${jsonSummary(value)}`, 'tree-type');
        details.appendChild(summary);
        const entries = Array.isArray(value)
          ? value.map((item, index) => [String(index), item])
          : Object.entries(value);
        if (entries.length === 0) {
          const empty = document.createElement('span');
          empty.className = 'tree-leaf tree-type';
          empty.textContent = Array.isArray(value) ? '[]' : '{}';
          details.appendChild(empty);
        } else {
          for (const [childKey, childValue] of entries) {
            details.appendChild(renderJsonNode(childKey, childValue, depth + 1));
          }
        }
        return details;
      }
      const row = document.createElement('span');
      row.className = 'tree-leaf';
      appendText(row, `${label}: `, 'tree-key');
      row.appendChild(renderScalar(value));
      return row;
    }

    function renderJsonTree(target, value) {
      clearNode(target);
      target.classList.remove('yaml-tree');
      const tree = document.createElement('div');
      tree.className = 'tree';
      tree.appendChild(renderJsonNode(null, value, 0));
      target.appendChild(tree);
    }

    function parseYamlBlocks(source) {
      const root = {indent: -1, line: 'YAML', children: []};
      const stack = [root];
      const lines = source
        .replace(/\t/g, '  ')
        .split(/\r?\n/)
        .filter((line) => line.trim())
        .map((line) => ({
          raw: line,
          indent: line.match(/^ */)[0].length,
          line: line.trimEnd()
        }));
      for (let index = 0; index < lines.length; index += 1) {
        const raw = lines[index].raw;
        if (!raw.trim()) continue;
        const indent = lines[index].indent;
        const nextIndent = lines[index + 1]?.indent ?? -1;
        const node = {indent, line: raw.trimEnd(), children: []};
        while (stack.length > 1 && indent <= stack[stack.length - 1].indent) {
          stack.pop();
        }
        stack[stack.length - 1].children.push(node);
        if (nextIndent > indent) {
          stack.push(node);
        }
      }
      return root;
    }

    function renderYamlNode(node, depth) {
      if (!node.children.length) {
        const line = document.createElement('span');
        line.className = 'yaml-line';
        line.textContent = `${' '.repeat(Math.max(0, node.indent))}${node.line}`;
        return line;
      }
      const details = document.createElement('details');
      details.open = depth < 2;
      if (depth === 0) details.classList.add('root');
      const summary = document.createElement('summary');
      appendText(summary, node.line, 'tree-key');
      appendText(summary, ` ${node.children.length}`, 'tree-type');
      details.appendChild(summary);
      for (const child of node.children) {
        details.appendChild(renderYamlNode(child, depth + 1));
      }
      return details;
    }

    function renderYamlTree(target, source) {
      clearNode(target);
      target.classList.add('yaml-tree');
      const tree = document.createElement('div');
      tree.className = 'tree yaml-tree';
      tree.appendChild(renderYamlNode(parseYamlBlocks(source), 0));
      target.appendChild(tree);
    }

    function renderUnknownTree(target, source) {
      const trimmed = source.trim();
      if (!trimmed) {
        clearNode(target);
        appendElement(target, 'div', 'empty payload', 'empty');
        return;
      }
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          renderJsonTree(target, JSON.parse(trimmed));
          return;
        } catch (_) {
          // Fall through to YAML/text view.
        }
      }
      renderYamlTree(target, source);
    }

    function launcherPayload() {
      const text = els.launchPayload.value.trim();
      if (!text) return {kind: els.launchKind.value};
      if (text.startsWith('{')) {
        const decoded = JSON.parse(text);
        return {kind: els.launchKind.value, ...decoded};
      }
      return els.launchKind.value === 'validateTask'
        ? {kind: 'validateTask', configText: text}
        : {kind: 'runScript', scriptText: text};
    }

    function renderLaunchResult(value) {
      if (typeof value === 'string') {
        els.launchResult.textContent = value;
        return;
      }
      renderJsonTree(els.launchResult, value);
    }

    function renderPayloadPreview(options = {}) {
      if (!options.force && els.launcherPanel && !els.launcherPanel.open) {
        state.payloadPreviewDirty = true;
        return;
      }
      state.payloadPreviewDirty = false;
      renderUnknownTree(els.payloadPreview, els.launchPayload.value);
    }

    function dynamicPanelKey(kind, id) {
      return `${kind}:${id || 'unknown'}`;
    }

    function dynamicPanelOpen(kind, id, defaultOpen) {
      const value = state.dynamicPanelOpen[dynamicPanelKey(kind, id)];
      return typeof value === 'boolean' ? value : defaultOpen;
    }

    function setDynamicPanelOpen(kind, id, open) {
      state.dynamicPanelOpen[dynamicPanelKey(kind, id)] = open;
    }

    function pruneDynamicPanelState(kind, allowedKeys) {
      const prefix = `${kind}:`;
      for (const key of Object.keys(state.dynamicPanelOpen)) {
        if (key.startsWith(prefix) && !allowedKeys.has(key)) {
          delete state.dynamicPanelOpen[key];
        }
      }
    }

    let runsPanelAutoCollapsedForCompact = false;

    function panelElements() {
      return Array.from(document.querySelectorAll('details.collapsible-panel'));
    }

    function persistentPanelElements() {
      return Array.from(document.querySelectorAll('details.collapsible-panel[data-panel-persist="true"]'));
    }

    function readStoredPanelState() {
      try {
        const text = localStorage.getItem(PANEL_STATE_STORAGE_KEY);
        if (!text) return {};
        const decoded = JSON.parse(text);
        return isObject(decoded) ? decoded : {};
      } catch (_) {
        return {};
      }
    }

    function savePanelState() {
      try {
        const panelState = {};
        for (const panel of persistentPanelElements()) {
          panelState[panel.dataset.panelId] = panel.open;
        }
        localStorage.setItem(PANEL_STATE_STORAGE_KEY, JSON.stringify(panelState));
      } catch (_) {
        // Storage can be disabled in hardened browser profiles.
      }
    }

    function restorePanelState() {
      const storedState = readStoredPanelState();
      state.hasStoredPanelState = Object.keys(storedState).length > 0;
      for (const panel of persistentPanelElements()) {
        const restored = storedState[panel.dataset.panelId];
        if (typeof restored === 'boolean') {
          panel.open = restored;
        }
      }
    }

    function setPanelGroupOpen(open) {
      let dynamicPanelsChanged = false;
      for (const panel of panelElements()) {
        panel.open = open;
        if (panel.dataset.dynamicPanelKind && panel.dataset.dynamicPanelId) {
          setDynamicPanelOpen(
            panel.dataset.dynamicPanelKind,
            panel.dataset.dynamicPanelId,
            open,
          );
          dynamicPanelsChanged = true;
        }
      }
      state.expandAll = open;
      savePanelState();
      if (els.launcherPanel.open && state.payloadPreviewDirty) {
        renderPayloadPreview({force: true});
      }
      if (dynamicPanelsChanged) {
        state.lastRenderedSignature = '';
        renderAll();
      }
    }

    function wirePanelStatePersistence() {
      for (const panel of persistentPanelElements()) {
        panel.addEventListener('toggle', savePanelState);
      }
    }

    function applyDensityLayout() {
      if (
        innerWidth < 760 &&
        els.runsPanel &&
        !runsPanelAutoCollapsedForCompact &&
        !state.hasStoredPanelState
      ) {
        els.runsPanel.open = false;
        runsPanelAutoCollapsedForCompact = true;
      }
    }

    function artifactPath(artifact) {
      return artifact?.relativePath || artifact?.path || artifact?.bundlePath || artifact?.file || '';
    }

    function artifactRunId(artifact, fallbackRunId = state.selectedRunId) {
      return artifact?.runId || artifact?.eventRunId || artifact?.sourceRunId || fallbackRunId || '';
    }

    function artifactKind(artifact) {
      const path = artifactPath(artifact).toLowerCase();
      const role = String(artifact?.role || artifact?.kind || '').toLowerCase();
      if (role.includes('screenshot') || /\.(png|jpg|jpeg|webp)$/.test(path)) return 'image';
      if (role.includes('recording') || role.includes('video') || /\.(mp4|webm|mov)$/.test(path)) return 'video';
      if (/\.(json|ndjson)$/.test(path)) return 'json';
      if (/\.(yaml|yml)$/.test(path)) return 'yaml';
      return 'file';
    }

    function artifactUrl(runId, artifact) {
      const ownerRunId = artifactRunId(artifact, runId);
      const path = artifactPath(artifact);
      if (!ownerRunId || !path) return '';
      const encodedPath = path.split('/').map(encodeURIComponent).join('/');
      return api(`/api/runs/${encodeURIComponent(ownerRunId)}/bundle/${encodedPath}`).toString();
    }

    function artifactLabel(artifact) {
      return artifact?.role || artifact?.kind || artifactKind(artifact);
    }

    function artifactDownloadName(artifact) {
      const path = artifactPath(artifact);
      const fileName = path.split('/').filter(Boolean).pop();
      return fileName || 'cockpit-artifact';
    }

    function artifactPriority(artifact) {
      const path = artifactPath(artifact).toLowerCase();
      const label = String(artifactLabel(artifact)).toLowerCase();
      const source = String(artifact?.source || artifact?.eventType || '').toLowerCase();
      const kind = artifactKind(artifact);
      const isDelivery = source.includes('delivery') || label.includes('delivery');
      const isKeyframe = label.includes('keyframe') || path.includes('/keyframes/');
      const isDiagnostic = label.includes('diagnostic') || path.includes('/diagnostics/') || kind === 'json';
      if (kind === 'video' && isDelivery) return 0;
      if (kind === 'video') return 1;
      if (kind === 'image' && isKeyframe) return 4;
      if (kind === 'image' && isDelivery) return 2;
      if (kind === 'image' && !isKeyframe) return 3;
      if (isDiagnostic) return 8;
      return 6;
    }

    function collectArtifacts() {
      const artifacts = [];
      const seen = new Set();
      const push = (artifact, event) => {
        if (!artifact || typeof artifact !== 'object') return;
        const path = artifactPath(artifact);
        if (!path) return;
        const runId = artifactRunId(artifact, event?.runId || state.selectedRunId);
        const key = `${runId}|${path}`;
        if (seen.has(key)) return;
        seen.add(key);
        artifacts.push({
          ...artifact,
          runId,
          eventKey: artifact.eventKey || (event ? eventKey(event) : null),
          eventSeq: artifact.eventSeq || event?.seq,
          eventType: event?.type || artifact.eventType,
          workflowStepId: artifact.workflowStepId || event?.workflowStepId,
          capturedAt: artifact.capturedAt || event?.timestamp
        });
      };
      for (const artifact of state.liveState?.recentArtifacts || []) push(artifact, null);
      for (const artifact of state.bundleSummary?.artifactRefs || []) {
        push(artifact, {
          seq: artifact.eventSeq,
          type: artifact.source || 'bundle',
          workflowStepId: artifact.workflowStepId,
          timestamp: artifact.capturedAt
        });
      }
      for (const event of state.events) {
        for (const artifact of event.artifactRefs || []) push(artifact, event);
        for (const artifact of event.captureRefs || []) push(artifact, event);
      }
      return artifacts.slice(-80).sort((left, right) => {
        const priority = artifactPriority(left) - artifactPriority(right);
        if (priority !== 0) return priority;
        const leftSeq = Number(left.eventSeq || 0);
        const rightSeq = Number(right.eventSeq || 0);
        if (leftSeq !== rightSeq) return rightSeq - leftSeq;
        return artifactPath(left).localeCompare(artifactPath(right));
      });
    }

    function renderArtifactPreview(container, artifact, options = {}) {
      const media = document.createElement('div');
      media.className = 'artifact-media';
      const kind = artifactKind(artifact);
      const url = artifactUrl(state.selectedRunId, artifact);
      const status = document.createElement('span');
      status.className = 'media-status';
      status.textContent = 'loading';
      if (kind === 'image' && url) {
        const img = document.createElement('img');
        img.loading = options.eager ? 'eager' : 'lazy';
        img.decoding = 'async';
        img.alt = `${artifactLabel(artifact)} ${artifactPath(artifact)}`;
        img.onload = () => {
          status.className = 'media-status ready';
          status.textContent = img.naturalWidth && img.naturalHeight
            ? `${img.naturalWidth}x${img.naturalHeight}`
            : 'image loaded';
        };
        img.onerror = () => {
          status.className = 'media-status error';
          status.textContent = 'image failed';
        };
        img.src = url;
        media.appendChild(img);
      } else if (kind === 'video' && url) {
        const video = document.createElement('video');
        video.controls = false;
        video.muted = true;
        video.playsInline = true;
        video.preload = 'metadata';
        video.tabIndex = -1;
        video.setAttribute('aria-hidden', 'true');
        video.onloadedmetadata = () => {
          status.className = 'media-status ready';
          const duration = Number.isFinite(video.duration)
            ? `${video.duration.toFixed(1)}s`
            : 'video ready';
          status.textContent = video.videoWidth && video.videoHeight
            ? `${video.videoWidth}x${video.videoHeight} ${duration}`
            : duration;
          if (Number.isFinite(video.duration) && video.duration > 0.3) {
            try {
              video.currentTime = Math.min(0.25, video.duration / 3);
            } catch (_) {
              // Some browsers block seeking until more data is buffered.
            }
          }
        };
        video.onerror = () => {
          status.className = 'media-status error';
          status.textContent = 'video failed';
        };
        video.src = url;
        media.appendChild(video);
      } else {
        const placeholder = document.createElement('div');
        placeholder.className = 'placeholder';
        placeholder.textContent = artifactPath(artifact) || 'artifact without path';
        media.appendChild(placeholder);
        status.textContent = kind;
      }
      if ((kind === 'image' || kind === 'video') && url) {
        media.classList.add('clickable');
        media.tabIndex = 0;
        media.setAttribute('role', 'button');
        media.setAttribute('aria-label', `View ${artifactLabel(artifact)} ${artifactPath(artifact)}`);
        const activateMedia = () => {
          media.focus({preventScroll: true});
          openMediaViewer(artifact, media);
        };
        media.onclick = (event) => {
          event.stopPropagation();
          activateMedia();
        };
        media.onkeydown = (event) => {
          if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            event.stopPropagation();
            activateMedia();
          }
        };
      }
      media.appendChild(status);
      container.appendChild(media);
      return media;
    }

    function renderMediaViewerArtifact(artifact) {
      clearNode(els.mediaViewerStage);
      els.mediaViewerStage.classList.toggle('actual', state.mediaViewerActualSize);
      els.mediaViewerSize.textContent = state.mediaViewerActualSize ? 'fit screen' : 'actual size';
      const kind = artifactKind(artifact);
      const url = artifactUrl(state.selectedRunId, artifact);
      if (kind === 'image' && url) {
        const img = document.createElement('img');
        img.alt = `${artifactLabel(artifact)} ${artifactPath(artifact)}`;
        img.decoding = 'async';
        img.src = url;
        els.mediaViewerStage.appendChild(img);
        return;
      }
      if (kind === 'video' && url) {
        const video = document.createElement('video');
        video.controls = true;
        video.muted = true;
        video.playsInline = true;
        video.preload = 'metadata';
        video.src = url;
        els.mediaViewerStage.appendChild(video);
        return;
      }
      const placeholder = document.createElement('div');
      placeholder.className = 'media-viewer-placeholder';
      placeholder.textContent = artifactPath(artifact) || 'No preview available for this artifact.';
      els.mediaViewerStage.appendChild(placeholder);
    }

    function openMediaViewer(artifact, trigger = null) {
      const url = artifactUrl(state.selectedRunId, artifact);
      if (!url) return;
      state.mediaViewerReturnFocus = trigger instanceof HTMLElement
        ? trigger
        : document.activeElement instanceof HTMLElement
        ? document.activeElement
        : null;
      state.mediaViewerArtifact = artifact;
      state.mediaViewerActualSize = false;
      els.mediaViewerTitle.textContent = artifactLabel(artifact);
      els.mediaViewerPath.textContent = [
        artifactRunId(artifact),
        artifactPath(artifact)
      ].filter(Boolean).join(' / ');
      els.mediaViewerOpen.href = url;
      els.mediaViewerDownload.href = url;
      els.mediaViewerDownload.download = artifactDownloadName(artifact);
      renderMediaViewerArtifact(artifact);
      els.mediaViewerPanel.open = true;
      els.mediaViewer.hidden = false;
      document.body.classList.add('media-viewer-open');
      els.mediaViewerClose.focus();
    }

    function closeMediaViewer() {
      const returnFocus = state.mediaViewerReturnFocus;
      state.mediaViewerArtifact = null;
      state.mediaViewerReturnFocus = null;
      clearNode(els.mediaViewerStage);
      els.mediaViewer.hidden = true;
      document.body.classList.remove('media-viewer-open');
      if (returnFocus && document.contains(returnFocus)) {
        returnFocus.focus();
      }
    }

    async function copyMediaViewerLink() {
      const artifact = state.mediaViewerArtifact;
      if (!artifact) return;
      const url = artifactUrl(state.selectedRunId, artifact);
      if (!url || !navigator.clipboard) return;
      await navigator.clipboard.writeText(url);
      els.mediaViewerCopy.textContent = 'copied';
      setTimeout(() => {
        els.mediaViewerCopy.textContent = 'copy link';
      }, 1200);
    }

    function toggleMediaViewerSize() {
      if (!state.mediaViewerArtifact) return;
      state.mediaViewerActualSize = !state.mediaViewerActualSize;
      renderMediaViewerArtifact(state.mediaViewerArtifact);
    }

    function selectedRun() {
      return state.runs.find((run) => run.runId === state.selectedRunId) || null;
    }

    function eventKey(event) {
      if (!event) return '';
      return event.eventKey || `${event.runId || state.selectedRunId || 'run'}#${event.seq || 'event'}`;
    }

    function selectTimelineEvent(event) {
      if (!event) {
        state.selectedEventKey = null;
        state.selectedEventSeq = null;
        return;
      }
      state.selectedEventKey = eventKey(event);
      state.selectedEventSeq = event.seq || null;
      if (event.runId && state.selectedRunId !== event.runId) {
        selectRun(event.runId);
      }
    }

    function selectRunTimelineTail(runId) {
      if (!runId) return;
      for (let index = state.events.length - 1; index >= 0; index -= 1) {
        if (state.events[index]?.runId === runId) {
          followTimelineEvent(state.events[index]);
          return;
        }
      }
    }

    function followTimelineEvent(event) {
      if (!event) {
        state.selectedEventKey = null;
        state.selectedEventSeq = null;
        return;
      }
      state.selectedEventKey = eventKey(event);
      state.selectedEventSeq = event.seq || null;
    }

    function selectedEvent() {
      return state.events.find((event) => eventKey(event) === state.selectedEventKey) ||
        state.events.find((event) => event.seq === state.selectedEventSeq && event.runId === state.selectedRunId) ||
        state.events[state.events.length - 1] ||
        null;
    }

    function eventForArtifact(artifact) {
      if (!artifact) return null;
      const key = artifact.eventKey || '';
      if (key) {
        const byKey = state.events.find((event) => eventKey(event) === key);
        if (byKey) return byKey;
      }
      const runId = artifactRunId(artifact, state.selectedRunId);
      const seq = artifact.eventSeq;
      if (runId && seq !== null && seq !== undefined) {
        return state.events.find((event) => event.runId === runId && event.seq === seq) || null;
      }
      return null;
    }

    function selectArtifactEvent(displayArtifact, event = null) {
      const targetEvent = event || eventForArtifact(displayArtifact);
      if (targetEvent) {
        selectTimelineEvent(targetEvent);
        state.inspectorTab = 'event';
      } else if (displayArtifact.eventKey || displayArtifact.eventSeq) {
        const runId = artifactRunId(displayArtifact);
        if (runId && state.selectedRunId !== runId) {
          selectRun(runId);
        }
        state.selectedEventKey = displayArtifact.eventKey || null;
        state.selectedEventSeq = displayArtifact.eventSeq || null;
        state.inspectorTab = 'event';
      }
    }

    function setStatus(statusText) {
      els.status.textContent = statusText;
    }

    function advanceSelectionRevision() {
      state.selectionRevision += 1;
      state.lastRenderedSignature = '';
      return state.selectionRevision;
    }

    function isCurrentSelection(revision, runId) {
      return state.selectionRevision === revision &&
        (!runId || state.selectedRunId === runId);
    }

    function replaceUrlScope(scopeId) {
      if (!scopeId || !history.replaceState) return;
      const url = new URL(location.href);
      if (url.searchParams.get('scope') === scopeId) return;
      url.searchParams.set('scope', scopeId);
      history.replaceState(null, '', url);
    }

    function replaceUrlWithLatestScope() {
      if (!history.replaceState) return;
      const url = new URL(location.href);
      if (url.searchParams.get('scope') === 'latest') return;
      url.searchParams.set('scope', 'latest');
      history.replaceState(null, '', url);
    }

    function isFollowingLatestScope() {
      return !state.selectedScopeId &&
        !state.pinnedScopeId &&
        (state.scopeMode === 'latest' || state.requestedScope === 'latest' || initialScope === 'latest');
    }

    function scopeModeLabel() {
      if (state.selectedScopeId === 'all') return 'all runs';
      if (state.pinnedScopeId) return 'pinned scope';
      if (isFollowingLatestScope()) return 'following latest';
      return 'current scope';
    }

    function activeScopeLabel() {
      if (state.activeScopeId === 'all' || state.selectedScopeId === 'all') return 'all runs';
      return state.activeScopeLabel ||
        scopeLabelFor(state.activeScopeId || state.selectedScopeId || state.currentScopeId) ||
        state.activeScopeId ||
        state.selectedScopeId ||
        state.currentScopeId ||
        '';
    }

    function selectRun(runId) {
      const nextRunId = runId || null;
      if (state.selectedRunId === nextRunId) return false;
      state.selectedRunId = nextRunId;
      advanceSelectionRevision();
      resetSelectedRunCaches();
      return true;
    }

    function selectScope(scopeId) {
      const nextScopeId = scopeId || '';
      if (state.selectedScopeId === nextScopeId && state.pinnedScopeId === (nextScopeId || null)) return false;
      state.selectedScopeId = nextScopeId;
      state.pinnedScopeId = nextScopeId || null;
      state.scopeMode = nextScopeId === 'all'
        ? 'all'
        : nextScopeId
        ? 'scope'
        : 'latest';
      state.requestedScope = nextScopeId || 'latest';
      state.hasResolvedInitialScope = initialScope !== 'current' || nextScopeId === '';
      if (nextScopeId) {
        replaceUrlScope(nextScopeId);
      } else {
        replaceUrlWithLatestScope();
      }
      state.selectedRunId = null;
      state.runs = [];
      state.filteredRunCount = 0;
      state.returnedRunCount = 0;
      state.hasMoreRuns = false;
      state.hasLoadedRuns = false;
      state.activeScopeId = nextScopeId || '';
      state.activeScopeKind = nextScopeId === 'all' ? 'all' : '';
      state.activeScopeLabel = nextScopeId ? scopeLabelFor(nextScopeId) : '';
      advanceSelectionRevision();
      resetSelectedRunCaches({clearEvents: true});
      return true;
    }

    function requestedScopeKey() {
      return [
        state.selectedScopeId || '',
        state.pinnedScopeId || '',
        state.scopeMode || '',
        state.requestedScope || '',
        state.hasResolvedInitialScope ? 'resolved' : 'initial'
      ].join('|');
    }

    function renderRuns() {
      const query = els.runSearch.value.trim().toLowerCase();
      const runs = state.runs.filter((run) => {
        if (!query) return true;
        return [
          run.runId,
          run.displayName,
          run.status,
          run.taskId,
          run.sessionId,
          run.scopeId,
          run.scopeLabel,
          run.platform,
          run.updatedAt
        ].filter(Boolean).join(' ').toLowerCase().includes(query);
      }).slice(0, 150);

      clearNode(els.runs);
      if (!state.hasLoadedRuns) {
        const loading = document.createElement('div');
        loading.className = 'empty';
        loading.textContent = 'loading run history...';
        els.runs.appendChild(loading);
        return;
      }
      if (!runs.length) {
        const empty = document.createElement('div');
        empty.className = 'empty';
        empty.textContent = query ? 'no runs match the filter' : 'no live runs yet';
        els.runs.appendChild(empty);
        return;
      }
      if (state.hasMoreRuns && !query) {
        const pageInfo = document.createElement('div');
        pageInfo.className = 'empty';
        pageInfo.textContent = `showing latest ${state.returnedRunCount || state.runs.length} of ${state.filteredRunCount} run(s)`;
        els.runs.appendChild(pageInfo);
      }
      for (const run of runs) {
        const button = document.createElement('button');
        button.className = 'run';
        button.type = 'button';
        button.dataset.runId = run.runId || '';
        button.dataset.scopeId = run.scopeId || '';
        button.setAttribute('aria-current', run.runId === state.selectedRunId ? 'true' : 'false');
        button.setAttribute('aria-label', [
          run.displayName || run.taskId || run.runId || 'run',
          run.status || 'unknown',
          run.scopeLabel || run.scopeId || '',
          run.platform || ''
        ].filter(Boolean).join(' | '));

        const title = document.createElement('div');
        title.className = 'run-title';
        const dot = document.createElement('span');
        dot.className = `dot ${statusClass(run.status)}`;
        title.appendChild(dot);
        appendElement(title, 'strong', run.displayName || run.taskId || run.runId);
        button.appendChild(title);

        const meta = document.createElement('div');
        meta.className = 'run-meta';
        appendText(
          meta,
          `${run.status || 'unknown'} | ${formatTime(run.updatedAt)}`,
        );
        appendText(
          meta,
          [
            run.platform,
            run.scopeLabel || run.scopeId,
            run.runId
          ].filter(Boolean).join(' | '),
        );
        button.appendChild(meta);

        button.onclick = () => {
          selectRun(run.runId);
          selectRunTimelineTail(run.runId);
          refreshSelected();
          renderRuns();
        };
        els.runs.appendChild(button);
      }
    }

    function renderScopes() {
      const scopes = state.scopes || [];
      const explicitScope = state.selectedScopeId || state.pinnedScopeId || '';
      const signature = JSON.stringify(scopes.map((scope) => [
        scope.scopeId,
        scope.scopeLabel,
        scope.runCount,
        scope.updatedAt,
        scope.status
      ])) + `|${explicitScope}|${state.currentScopeId}`;
      if (els.scopeSelect.dataset.signature === signature) return;
      els.scopeSelect.dataset.signature = signature;
      clearNode(els.scopeSelect);
      const current = document.createElement('option');
      current.value = '';
      current.textContent = state.currentScopeId
        ? `follow latest: ${scopeLabelFor(state.currentScopeId)}`
        : 'follow latest scope';
      els.scopeSelect.appendChild(current);
      const all = document.createElement('option');
      all.value = 'all';
      all.textContent = `all runs (${state.totalRunCount || state.runs.length})`;
      els.scopeSelect.appendChild(all);
      for (const scope of scopes) {
        const option = document.createElement('option');
        option.value = scope.scopeId;
        option.textContent = `${scope.scopeLabel || scope.scopeId} (${scope.runCount || 0})`;
        els.scopeSelect.appendChild(option);
      }
      els.scopeSelect.value = explicitScope;
    }

    function scopeLabelFor(scopeId) {
      const scope = (state.scopes || []).find((candidate) => candidate.scopeId === scopeId);
      return scope?.scopeLabel || scopeId;
    }

    function metric(label, value, hint, options = {}) {
      const div = document.createElement('div');
      div.className = 'metric';
      appendElement(div, 'span', label);
      appendElement(div, 'strong', value || 'unknown', options.compact ? 'compact' : '');
      if (hint) appendText(div, hint, 'muted');
      return div;
    }

    function renderOverview() {
      clearNode(els.overview);
      const run = selectedRun();
      const live = state.liveState || {};
      const counts = live.counts || {};
      els.overview.appendChild(metric('status', live.status || run?.status || 'unknown', live.stage || ''));
      els.overview.appendChild(metric('current step', live.currentStep?.workflowStepId || live.currentStep?.commandId || 'none', live.currentStep?.workflowStepType || live.currentStep?.commandType || ''));
      els.overview.appendChild(metric('errors', String(counts.errorCount || 0), live.lastError?.message || ''));
      els.overview.appendChild(
        metric(
          'next',
          shortNextAction(live.recommendedNextStep),
          'recommended action',
          {compact: true},
        ),
      );
    }

    function shortNextAction(value) {
      const text = textValue(value).trim();
      if (!text) return 'observe';
      const command = text.match(/\b[a-z][a-z0-9-]+\b/i);
      const candidate = command ? command[0] : text;
      return candidate.length > 34 ? `${candidate.slice(0, 31)}...` : candidate;
    }

    function fact(label, value) {
      const dt = document.createElement('dt');
      dt.textContent = label;
      const dd = document.createElement('dd');
      dd.textContent = textValue(value) || 'unknown';
      els.runFacts.appendChild(dt);
      els.runFacts.appendChild(dd);
    }

    function renderFacts() {
      clearNode(els.runFacts);
      const run = selectedRun() || {};
      const live = state.liveState || {};
      fact('runId', live.runId || run.runId);
      fact('scopeMode', scopeModeLabel());
      fact('scopeId', live.scopeId || run.scopeId || state.activeScopeId);
      fact('scopeLabel', live.scopeLabel || run.scopeLabel || activeScopeLabel());
      fact('scopeKind', live.scopeKind || run.scopeKind || state.activeScopeKind);
      fact('taskId', live.taskId || run.taskId);
      fact('sessionId', live.sessionId || run.sessionId);
      fact('platform', live.platform || run.platform);
      fact('startedAt', formatDateTime(live.startedAt || run.startedAt));
      fact('updatedAt', formatDateTime(live.updatedAt || run.updatedAt));
      fact('bundleDir', live.bundleDir || run.bundleDir);
      fact('recommendedNextStep', live.recommendedNextStep);
      fact('bundleStatus', state.bundleSummary?.status);
      fact('deliveryVideoSource', state.bundleSummary?.deliveryVideoSource);
      fact(
        'summaryIssues',
        Array.isArray(state.bundleSummary?.summaryFileIssues)
          ? state.bundleSummary.summaryFileIssues.length
          : '',
      );
    }

    function renderHeaderSummary() {
      const live = state.liveState || {};
      const run = selectedRun() || {};
      const counts = live.counts || {};
      const status = live.status || run.status || 'unknown';
      els.selectedStatus.textContent = status;
      els.selectedStatusDot.className = `dot ${statusClass(status)}`;
      if (!state.hasLoadedRuns) {
        els.runCount.textContent = '...';
        els.eventCount.textContent = '...';
        els.artifactCount.textContent = '...';
        return;
      }
      const visibleRuns = state.returnedRunCount || state.runs.length;
      const filteredRuns = state.filteredRunCount || visibleRuns;
      els.runCount.textContent = state.hasMoreRuns
        ? `${visibleRuns}/${filteredRuns}`
        : String(filteredRuns);
      els.eventCount.textContent = String(state.scopeEventCount || counts.eventCount || state.events.length || 0);
      els.artifactCount.textContent = String(collectArtifacts().length || counts.artifactCount || 0);
    }

    function renderTimelineContext() {
      clearNode(els.timelineContext);
      const run = selectedRun() || {};
      const live = state.liveState || {};
      const addPill = (label, value, className = '') => {
        const pill = document.createElement('span');
        pill.className = `context-pill${className ? ` ${className}` : ''}`;
        appendText(pill, `${label}: `);
        appendElement(pill, 'strong', textValue(value) || 'unknown');
        els.timelineContext.appendChild(pill);
      };
      const allRuns = state.activeScopeId === 'all' || state.selectedScopeId === 'all';
      addPill('scope', live.scopeLabel || run.scopeLabel || activeScopeLabel(), allRuns ? 'warn' : '');
      addPill('mode', scopeModeLabel());
      addPill('isolation', allRuns ? 'mixed sessions' : (live.scopeKind || run.scopeKind || state.activeScopeKind || 'session'));
      addPill('session', live.sessionId || run.sessionId);
      addPill('run', live.runId || run.runId || state.selectedRunId);
    }

    function eventMatchesFilter(event) {
      if (state.eventFilter === 'all') return true;
      if (state.eventFilter === 'failed') return event.status === 'failed' || event.error;
      if (state.eventFilter === 'artifact') {
        return (event.artifactRefs || []).length > 0 || (event.captureRefs || []).length > 0;
      }
      return true;
    }

    function eventFilterLabel() {
      if (state.eventFilter === 'failed') return 'error';
      if (state.eventFilter === 'artifact') return 'artifact';
      return 'all';
    }

    function syncEventFilterButtons() {
      for (const button of document.querySelectorAll('[data-filter]')) {
        const active = button.dataset.filter === state.eventFilter;
        button.classList.toggle('active', active);
        button.setAttribute('aria-pressed', active ? 'true' : 'false');
      }
      const expandButton = document.getElementById('expandTimeline');
      expandButton.classList.toggle('active', state.expandAll);
      expandButton.setAttribute('aria-pressed', state.expandAll ? 'true' : 'false');
    }

    function renderEventDetails(container, event) {
      const facts = document.createElement('dl');
      facts.className = 'facts';
      const add = (label, value) => {
        if (value === undefined || value === null || value === '') return;
        const dt = document.createElement('dt');
        dt.textContent = label;
        const dd = document.createElement('dd');
        dd.textContent = textValue(value);
        facts.appendChild(dt);
        facts.appendChild(dd);
      };
      add('step', event.workflowStepId);
      add('stepType', event.workflowStepType);
      add('command', event.commandId);
      add('commandType', event.commandType);
      add('stage', event.stage);
      add('time', formatDateTime(event.timestamp));
      const details = event.details || {};
      add('parentStep', details.parentWorkflowStepId);
      add('rootStep', details.rootWorkflowStepId);
      add('relation', details.relation);
      add('depth', details.workflowStepDepth);
      add('attempt', details.attempt && details.maxAttempts ? `${details.attempt}/${details.maxAttempts}` : details.attempt);
      add('iteration', details.iteration && details.maxIterations ? `${details.iteration}/${details.maxIterations}` : details.iteration);
      if (facts.children.length) {
        const metaPanel = createInlinePanel(
          'Metadata',
          `${Math.floor(facts.children.length / 2)} field(s)`,
          'event-meta-panel',
        );
        metaPanel.body.appendChild(facts);
        container.appendChild(metaPanel.panel);
      }

      const artifacts = [...(event.captureRefs || []), ...(event.artifactRefs || [])];
      if (artifacts.length) {
        const artifactPanel = createInlinePanel(
          'Artifacts',
          `${artifacts.length} linked`,
          'event-artifacts-panel',
        );
        const grid = document.createElement('div');
        grid.className = 'artifact-grid';
        for (const artifact of artifacts.slice(0, 6)) {
          grid.appendChild(renderArtifactCard(artifact, event, true));
        }
        artifactPanel.body.appendChild(grid);
        container.appendChild(artifactPanel.panel);
      }
    }

    function ensureEventDetailsRendered(item, event) {
      if (!item.open || item.querySelector(':scope > .event-details')) return;
      const details = document.createElement('div');
      details.className = 'event-details';
      renderEventDetails(details, event);
      item.appendChild(details);
    }

    function renderTimeline() {
      const latestKey = eventKey(state.events[state.events.length - 1]);
      const shouldKeepTailVisible = Boolean(els.timelineScroll) && (
        !state.selectedEventKey ||
        state.selectedEventKey === latestKey ||
        els.timelineScroll.scrollHeight - els.timelineScroll.scrollTop - els.timelineScroll.clientHeight < 48
      );
      clearNode(els.timeline);
      if (!state.hasLoadedRuns) {
        syncEventFilterButtons();
        els.timelineSummary.textContent = 'loading events';
        const loading = document.createElement('div');
        loading.className = 'empty';
        loading.textContent = 'loading events...';
        els.timeline.appendChild(loading);
        return;
      }
      syncEventFilterButtons();
      const matchingEvents = state.events.filter(eventMatchesFilter);
      const events = matchingEvents.slice(-TIMELINE_RENDER_LIMIT);
      const totalEventCount = Number(state.scopeEventCount || state.liveState?.counts?.eventCount || state.events.length || 0);
      const loadedPrefix = totalEventCount > state.events.length
        ? `${state.events.length}/${totalEventCount} loaded, `
        : '';
      const eventCountLabel = state.eventFilter === 'all'
        ? `${matchingEvents.length} event(s)`
        : `${matchingEvents.length}/${state.events.length} event(s) match ${eventFilterLabel()} filter`;
      const run = selectedRun() || {};
      const runLabel = run.displayName || run.taskId || run.runId || state.selectedRunId || 'no run selected';
      const scopeLabel = run.scopeLabel || state.liveState?.scopeLabel || activeScopeLabel();
      const modeLabel = scopeModeLabel();
      const summary = matchingEvents.length > events.length
        ? `${loadedPrefix}showing latest ${events.length} of ${eventCountLabel}, oldest to newest`
        : `${loadedPrefix}${eventCountLabel}, oldest to newest`;
      els.timelineSummary.textContent = `${summary} | ${modeLabel}${scopeLabel ? ` | scope ${scopeLabel}` : ''} | selected ${runLabel}`;
      if (!events.length) {
        const empty = document.createElement('div');
        empty.className = 'empty';
        empty.textContent = state.events.length
          ? 'no events match the active filter'
          : 'no events recorded yet';
        els.timeline.appendChild(empty);
        return;
      }
      for (const event of events) {
        const item = document.createElement('details');
        const key = eventKey(event);
        const selected = key === state.selectedEventKey;
        const expanded = dynamicPanelOpen('event', key, state.expandAll || selected);
        item.className = `event collapsible-panel ${statusClass(event.status)}${expanded ? ' expanded' : ''}`;
        item.open = expanded;
        item.dataset.dynamicPanelKind = 'event';
        item.dataset.dynamicPanelId = key;
        item.setAttribute('aria-selected', selected ? 'true' : 'false');
        item.addEventListener('toggle', () => {
          setDynamicPanelOpen('event', key, item.open);
          item.classList.toggle('expanded', item.open);
          ensureEventDetailsRendered(item, event);
        });

        const summary = document.createElement('summary');
        summary.className = 'event-summary panel-summary';
        summary.setAttribute('aria-label', [
          `event ${event.seq || ''}`,
          event.type || 'event',
          event.status || 'unknown'
        ].filter(Boolean).join(' | '));
        const summaryContent = document.createElement('div');
        summaryContent.className = 'event-summary-content';

        const head = document.createElement('div');
        head.className = 'event-head';
        const title = document.createElement('div');
        title.className = 'event-title';
        appendText(title, `#${event.seq}`, 'badge');
        appendElement(title, 'strong', event.type || 'event');
        appendText(title, event.status || 'unknown', `badge ${statusBadgeClass(event.status)}`);
        if (event.runId && state.runs.length > 1) appendText(title, event.runId, 'badge');
        const details = event.details || {};
        if (event.workflowStepId) appendText(title, event.workflowStepId, 'badge');
        if (details.parentWorkflowStepId) appendText(title, `in ${details.parentWorkflowStepId}`, 'badge');
        if (details.relation === 'retry' && details.attempt) {
          appendText(title, `try ${details.attempt}/${details.maxAttempts || '?'}`, 'badge');
        }
        if (details.relation === 'loop' && details.iteration) {
          appendText(title, `loop ${details.iteration}/${details.maxIterations || '?'}`, 'badge');
        }
        if ((event.artifactRefs || []).length || (event.captureRefs || []).length) {
          appendText(title, `${(event.artifactRefs || []).length + (event.captureRefs || []).length} artifact`, 'badge good');
        }
        head.appendChild(title);
        appendText(head, formatTime(event.timestamp), 'meta');
        summaryContent.appendChild(head);

        if (event.description || event.error?.message || event.recommendedNextStep) {
          const description = document.createElement('div');
          description.className = 'event-description';
          description.textContent = event.error?.message || event.description || event.recommendedNextStep;
          summaryContent.appendChild(description);
        }
        summary.appendChild(summaryContent);
        item.appendChild(summary);

        ensureEventDetailsRendered(item, event);

        const select = () => {
          selectTimelineEvent(event);
          renderTimeline();
          renderRuns();
          renderFacts();
          renderOverview();
          renderInspector();
          refreshSelected().catch((error) => setStatus(`error: ${error.message}`));
        };
        summary.onclick = () => {
          setTimeout(() => {
            setDynamicPanelOpen('event', key, item.open);
            select();
          }, 0);
        };
        els.timeline.appendChild(item);
      }
      pruneDynamicPanelState(
        'event',
        new Set(events.map((event) => dynamicPanelKey('event', eventKey(event)))),
      );
      if (shouldKeepTailVisible) {
        els.timelineScroll.scrollTop = els.timelineScroll.scrollHeight;
      }
    }

    function renderArtifactCard(artifact, event = null, eager = false) {
      const displayArtifact = {
        ...artifact,
        runId: artifactRunId(artifact, event?.runId || state.selectedRunId),
        eventKey: artifact?.eventKey || (event ? eventKey(event) : null),
        eventSeq: artifact?.eventSeq || event?.seq
      };
      const card = document.createElement('details');
      card.className = 'artifact collapsible-panel';
      const artifactPanelId = `${displayArtifact.runId || ''}|${artifactPath(displayArtifact)}`;
      card.open = dynamicPanelOpen(
        'artifact',
        artifactPanelId,
        eager || artifactPriority(displayArtifact) <= 2,
      );
      card.dataset.dynamicPanelKind = 'artifact';
      card.dataset.dynamicPanelId = artifactPanelId;
      card.addEventListener('toggle', () => {
        setDynamicPanelOpen('artifact', artifactPanelId, card.open);
      });
      const summary = document.createElement('summary');
      summary.className = 'artifact-summary panel-summary';
      const caption = document.createElement('div');
      caption.className = 'artifact-caption';
      appendElement(caption, 'strong', artifactLabel(displayArtifact));
      appendText(caption, artifactPath(displayArtifact));
      appendText(caption, [
        displayArtifact.runId,
        displayArtifact.workflowStepId || event?.workflowStepId,
        displayArtifact.eventSeq || event?.seq ? `event #${displayArtifact.eventSeq || event?.seq}` : '',
        displayArtifact.capturedAt || event?.timestamp ? formatDateTime(displayArtifact.capturedAt || event?.timestamp) : ''
      ].filter(Boolean).join(' | '));
      summary.appendChild(caption);
      card.appendChild(summary);

      const body = document.createElement('div');
      body.className = 'artifact-body';
      renderArtifactPreview(body, displayArtifact, {eager});
      const url = artifactUrl(state.selectedRunId, displayArtifact);
      if (url) {
        const link = document.createElement('a');
        link.className = 'artifact-open';
        link.href = url;
        link.target = '_blank';
        link.rel = 'noreferrer';
        link.textContent = 'open artifact';
        link.onclick = (event) => event.stopPropagation();
        body.appendChild(link);
      }
      card.appendChild(body);
      summary.onclick = () => {
        setTimeout(() => {
          setDynamicPanelOpen('artifact', artifactPanelId, card.open);
          selectArtifactEvent(displayArtifact, event);
          renderAll();
        }, 0);
      };
      return card;
    }

    function renderArtifacts() {
      const artifacts = collectArtifacts();
      clearNode(els.artifactGallery);
      els.artifactSummary.textContent = artifacts.length
        ? `${artifacts.length} linked artifact(s)`
        : 'no artifacts';
      if (!artifacts.length) {
        const empty = document.createElement('div');
        empty.className = 'empty';
        empty.textContent = 'Screenshots, keyframes, recordings, and diagnostics appear here when a run produces artifact refs.';
        els.artifactGallery.appendChild(empty);
        return;
      }
      for (const [index, artifact] of artifacts.slice(0, 60).entries()) {
        const event = eventForArtifact(artifact);
        els.artifactGallery.appendChild(renderArtifactCard(artifact, event, index < EAGER_ARTIFACT_COUNT));
      }
      pruneDynamicPanelState(
        'artifact',
        new Set(
          artifacts
            .slice(0, 60)
            .map((artifact) => dynamicPanelKey('artifact', `${artifactRunId(artifact)}|${artifactPath(artifact)}`)),
        ),
      );
    }

    function renderInspectorTabs() {
      for (const [id, tab] of [
        ['event', document.getElementById('tabEvent')],
        ['state', document.getElementById('tabState')],
        ['yaml', document.getElementById('tabYaml')]
      ]) {
        tab.setAttribute('aria-selected', state.inspectorTab === id ? 'true' : 'false');
      }
    }

    function renderInspector() {
      renderInspectorTabs();
      if (state.inspectorTab === 'state') {
        renderJsonTree(els.inspector, {
          liveState: state.liveState,
          bundleSummary: state.bundleSummary,
          job: state.job
        });
        return;
      }
      if (state.inspectorTab === 'yaml') {
        renderUnknownTree(els.inspector, els.launchPayload.value);
        return;
      }
      const event = selectedEvent();
      if (!event) {
        clearNode(els.inspector);
        appendElement(
          els.inspector,
          'div',
          'select a timeline event to inspect full event JSON',
          'empty',
        );
        return;
      }
      renderJsonTree(els.inspector, event);
    }

    function countArtifactRefs(items) {
      if (!Array.isArray(items)) return 0;
      return items.reduce((count, item) => {
        return count +
          (Array.isArray(item?.artifactRefs) ? item.artifactRefs.length : 0) +
          (Array.isArray(item?.captureRefs) ? item.captureRefs.length : 0);
      }, 0);
    }

    function renderSignature() {
      const run = selectedRun() || {};
      const live = state.liveState || {};
      const counts = live.counts || {};
      const lastEvent = state.events[state.events.length - 1] || {};
      const firstEvent = state.events[0] || {};
      return [
        state.selectedRunId || '',
        state.selectedEventKey || '',
        state.selectedEventSeq || '',
        state.inspectorTab,
        state.eventFilter,
        state.expandAll ? '1' : '0',
        state.selectedScopeId || '',
        state.scopeMode || '',
        state.requestedScope || '',
        state.currentScopeId || '',
        state.activeScopeId || '',
        state.activeScopeKind || '',
        state.activeScopeLabel || '',
        state.filteredRunCount || 0,
        state.returnedRunCount || 0,
        state.totalRunCount || 0,
        state.hasMoreRuns ? 'more' : '',
        state.scopes.length,
        state.runs.length,
        run.updatedAt || '',
        run.status || '',
        live.status || '',
        live.stage || '',
        live.updatedAt || '',
        live.currentStep?.workflowStepId || live.currentStep?.commandId || '',
        live.currentStep?.workflowStepType || live.currentStep?.commandType || '',
        counts.eventCount || state.events.length || 0,
        counts.errorCount || 0,
        counts.artifactCount || '',
        state.bundleSummary?.status || '',
        state.bundleSummary?.deliveryVideoSource || '',
        state.bundleSummary?.primaryScreenshotRef || '',
        state.bundleSummary?.primaryRecordingRef || '',
        state.bundleSummary?.traceSummary?.entryCount || '',
        state.bundleSummary?.traceSummary?.reason || '',
        Array.isArray(state.bundleSummary?.summaryFileIssues) ? state.bundleSummary.summaryFileIssues.length : 0,
        Array.isArray(state.bundleSummary?.artifactRefs) ? state.bundleSummary.artifactRefs.length : 0,
        state.job?.status || '',
        state.job?.updatedAt || '',
        state.events.length,
        state.scopeEventCount || 0,
        state.returnedScopeEventCount || 0,
        state.hasMoreScopeEvents ? 'more-events' : '',
        firstEvent.seq || '',
        eventKey(firstEvent),
        lastEvent.seq || '',
        eventKey(lastEvent),
        lastEvent.status || '',
        lastEvent.type || '',
        lastEvent.timestamp || '',
        countArtifactRefs(state.events)
      ].join('|');
    }

    function renderAll() {
      const signature = renderSignature();
      if (signature === state.lastRenderedSignature) {
        renderHeaderSummary();
        return;
      }
      state.lastRenderedSignature = signature;
      renderHeaderSummary();
      renderScopes();
      renderRuns();
      renderOverview();
      renderFacts();
      renderTimelineContext();
      renderTimeline();
      renderArtifacts();
      renderInspector();
      renderPayloadPreview();
    }

    function resetEventCursor() {
      state.events = [];
      state.scopeEventCount = 0;
      state.returnedScopeEventCount = 0;
      state.hasMoreScopeEvents = false;
      state.eventsByteOffset = 0;
      state.eventsPartialLine = '';
      state.eventsHaveLoaded = false;
      state.lastFetchedEventCount = null;
      state.lastScopeEventsKey = '';
    }

    function resetSelectedRunCaches(options = {}) {
      state.liveState = null;
      state.bundleSummary = null;
      state.job = null;
      state.lastLiveStateText = '';
      state.lastBundleSummaryKey = '';
      state.lastRenderedSignature = '';
      if (options.clearEvents) {
        state.selectedEventKey = null;
        state.selectedEventSeq = null;
        resetEventCursor();
      }
    }

    function parseEventsText(text, options = {}) {
      const previousLastKey = eventKey(state.events[state.events.length - 1]);
      const wasFollowingTail = !state.selectedEventKey ||
        state.selectedEventKey === previousLastKey;
      const combined = state.eventsPartialLine + text;
      const lines = combined.split(/\n/);
      state.eventsPartialLine = lines.pop() || '';
      const events = [];
      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          const event = JSON.parse(line);
          if (options.runId && event.runId && event.runId !== options.runId) {
            continue;
          }
          event.eventKey = eventKey(event);
          events.push(event);
        } catch (_) {
          // Ignore partial lines while a writer is appending.
        }
      }
      if (!events.length) return false;
      state.events = [...state.events, ...events].slice(-MAX_EVENTS);
      const selectedStillLoaded = state.events.some((event) => eventKey(event) === state.selectedEventKey);
      if ((wasFollowingTail || !selectedStillLoaded) && state.events.length) {
        const latestEvent = state.events[state.events.length - 1];
        followTimelineEvent(latestEvent);
        if (latestEvent.runId && state.selectedRunId !== latestEvent.runId) {
          selectRun(latestEvent.runId);
        }
      }
      return true;
    }

    function initialTailWholeLines(text, rangeStart) {
      if (rangeStart <= 0 || !text) return text;
      if (text[0] === '\n') return text.slice(1);
      const firstLineBreak = text.indexOf('\n');
      return firstLineBreak < 0 ? '' : text.slice(firstLineBreak + 1);
    }

    async function fetchEventsIncremental(encodedRunId, eventCount, runId, revision) {
      const headers = {};
      if (state.eventsHaveLoaded) {
        headers.range = `bytes=${state.eventsByteOffset}-`;
      } else {
        headers.range = `bytes=-${INITIAL_EVENT_TAIL_BYTES}`;
      }
      const response = await fetchTextResponse(
        `/api/runs/${encodedRunId}/events.ndjson`,
        {headers}
      );
      const text = await response.text();
      if (!isCurrentSelection(revision, runId)) return false;
      const contentRange = response.headers.get('content-range') || '';
      const rangeMatch = contentRange.match(/^bytes (\d+)-(\d+)\/(\d+)$/);
      const contentLength = Number(response.headers.get('content-length') || 0);
      const rangeStart = rangeMatch ? Number(rangeMatch[1]) : 0;
      const rangeEnd = rangeMatch ? Number(rangeMatch[2]) : Math.max(0, contentLength - 1);
      const totalLength = rangeMatch ? Number(rangeMatch[3]) : contentLength;
      const fileWasRewritten = state.eventsHaveLoaded && totalLength < state.eventsByteOffset;
      const resetFromFullBody = response.status === 200 || !state.eventsHaveLoaded || fileWasRewritten;
      if (resetFromFullBody && rangeStart === 0) {
        state.events = [];
        state.eventsPartialLine = '';
      }
      const eventText = !state.eventsHaveLoaded && response.status === 206
        ? initialTailWholeLines(text, rangeStart)
        : text;
      const changed = parseEventsText(eventText, {runId});
      state.eventsByteOffset = rangeMatch ? rangeEnd + 1 : totalLength;
      state.eventsHaveLoaded = true;
      state.lastFetchedEventCount = eventCount;
      return changed;
    }

    async function refreshScopeEvents() {
      const revision = state.selectionRevision;
      const params = new URLSearchParams();
      params.set('limit', String(MAX_EVENTS));
      params.set('runLimit', String(RUN_PAGE_LIMIT));
      const requestedScopeId = state.selectedScopeId || state.pinnedScopeId || '';
      if (requestedScopeId) {
        params.set('scope', requestedScopeId);
      } else if (isFollowingLatestScope()) {
        params.set('scope', 'latest');
      } else if (state.activeScopeId) {
        params.set('scope', state.activeScopeId);
      } else {
        params.set('scope', 'current');
      }
      const requestKey = params.toString();
      const result = await fetchJson(`/api/events?${requestKey}`);
      if (revision !== state.selectionRevision) return;
      const events = Array.isArray(result.events) ? result.events : [];
      state.scopeEventCount = Number(result.eventCount || events.length || 0);
      state.returnedScopeEventCount = Number(result.returnedEventCount || events.length || 0);
      state.hasMoreScopeEvents = Boolean(result.hasMoreEvents || result.hasMoreRuns);
      const nextEvents = events.map((event) => ({...event, eventKey: eventKey(event)})).slice(-MAX_EVENTS);
      const nextKey = [
        requestKey,
        result.scopeId || '',
        result.eventCount || 0,
        result.returnedEventCount || 0,
        nextEvents[0]?.eventKey || '',
        nextEvents[nextEvents.length - 1]?.eventKey || '',
        nextEvents[nextEvents.length - 1]?.timestamp || ''
      ].join('|');
      if (nextKey === state.lastScopeEventsKey) return;
      const previousLastKey = eventKey(state.events[state.events.length - 1]);
      const wasFollowingTail = !state.selectedEventKey ||
        state.selectedEventKey === previousLastKey;
      state.events = nextEvents;
      state.lastScopeEventsKey = nextKey;
      const selectedStillLoaded = state.events.some((event) => eventKey(event) === state.selectedEventKey);
      if ((wasFollowingTail || !selectedStillLoaded) && state.events.length) {
        const latestEvent = state.events[state.events.length - 1];
        followTimelineEvent(latestEvent);
        if (latestEvent.runId && state.selectedRunId !== latestEvent.runId) {
          selectRun(latestEvent.runId);
        }
      }
    }

    async function refreshRuns() {
      const requestedScopeId = state.selectedScopeId || state.pinnedScopeId || '';
      const followLatest = !requestedScopeId && isFollowingLatestScope();
      const revision = state.selectionRevision;
      const scopeKey = requestedScopeKey();
      const runParams = new URLSearchParams();
      runParams.set('limit', String(RUN_PAGE_LIMIT));
      if (requestedScopeId) {
        runParams.set('scope', requestedScopeId);
      } else if (followLatest) {
        runParams.set('scope', 'latest');
      } else if (initialScope === 'current' && !state.hasResolvedInitialScope) {
        runParams.set('scope', 'current');
      }
      const runPath = runParams.toString()
        ? `/api/runs?${runParams.toString()}`
        : '/api/runs?';
      const index = await fetchJson(runPath);
      if (scopeKey !== requestedScopeKey() || revision !== state.selectionRevision) {
        return;
      }
      state.hasLoadedRuns = true;
      state.scopes = index.scopes || [];
      state.currentScopeId = index.currentScopeId || '';
      state.activeScopeId = index.scopeId || '';
      state.activeScopeKind = index.scopeKind || '';
      state.activeScopeLabel = index.scopeLabel || '';
      state.scopeMode = followLatest ? 'latest' : index.scopeMode || state.scopeMode;
      state.requestedScope = followLatest ? 'latest' : index.requestedScope || state.requestedScope;
      state.totalRunCount = Number(index.runCount || 0);
      state.filteredRunCount = Number(index.filteredRunCount || (index.runs || []).length || 0);
      state.returnedRunCount = Number(index.returnedRunCount || (index.runs || []).length || 0);
      state.hasMoreRuns = Boolean(index.hasMoreRuns);
      if (!state.hasResolvedInitialScope && initialScope === 'current' && index.scopeId && index.scopeId !== 'all') {
        state.selectedScopeId = index.scopeId;
        state.pinnedScopeId = index.scopeId;
        state.scopeMode = 'scope';
        state.requestedScope = index.scopeId;
        state.hasResolvedInitialScope = true;
        replaceUrlScope(index.scopeId);
      } else if (!state.selectedScopeId && !state.pinnedScopeId && index.scopeId && index.scopeId !== 'all') {
        state.currentScopeId = index.scopeId;
      }
      state.runs = index.runs || [];
      if (!state.selectedRunId && state.runs.length) {
        selectRun(state.runs[0].runId);
      }
      if (state.selectedRunId && !state.runs.some((run) => run.runId === state.selectedRunId)) {
        selectRun(state.runs[0]?.runId || null);
      }
    }

    async function refreshSelected() {
      const runId = state.selectedRunId;
      const revision = state.selectionRevision;
      if (!runId) {
        resetSelectedRunCaches();
        renderAll();
        return;
      }
      const encodedRunId = encodeURIComponent(runId);
      try {
        const nextLiveState = await fetchJson(`/api/runs/${encodedRunId}/state`);
        if (!isCurrentSelection(revision, runId)) return;
        const liveStateText = JSON.stringify(nextLiveState);
        if (liveStateText !== state.lastLiveStateText) {
          state.liveState = nextLiveState;
          state.lastLiveStateText = liveStateText;
        }
        state.job = null;
        const run = selectedRun() || {};
        const bundleSummaryKey = nextLiveState.bundleDir || run.bundleDir || '';
        if (!bundleSummaryKey) {
          state.bundleSummary = null;
          state.lastBundleSummaryKey = '';
        } else {
          const counts = nextLiveState.counts || {};
          const summaryRefreshKey = [
            bundleSummaryKey,
            nextLiveState.updatedAt || '',
            nextLiveState.status || '',
            counts.eventCount || 0,
            counts.artifactCount || 0,
            run.updatedAt || ''
          ].join('|');
          if (summaryRefreshKey !== state.lastBundleSummaryKey) {
            const nextBundleSummary = await fetchJson(`/api/runs/${encodedRunId}/bundle-summary`);
            if (!isCurrentSelection(revision, runId)) return;
            state.bundleSummary = nextBundleSummary;
            state.lastBundleSummaryKey = summaryRefreshKey;
          }
        }
      } catch (error) {
        try {
          const nextJob = await fetchJson(`/api/runs/${encodedRunId}/job`);
          if (!isCurrentSelection(revision, runId)) return;
          resetSelectedRunCaches();
          state.job = nextJob;
        } catch (_) {
          throw error;
        }
      }
      renderAll();
    }

    async function tick() {
      try {
        await refreshRuns();
        await refreshScopeEvents();
        if (!state.selectedRunId && state.events.length) {
          selectRun(state.events[state.events.length - 1].runId);
        }
        await refreshSelected();
        setStatus(`${state.runs.length} run(s) | ${state.selectedRunId || 'none selected'} | ${formatTime(new Date().toISOString())}`);
      } catch (error) {
        setStatus(`error: ${error.message}`);
      }
    }

    async function parseWorkflow() {
      const payload = launcherPayload();
      const source = payload.scriptText || payload.script || els.launchPayload.value;
      const result = await postJson('/api/workflows/parse', {
        source: typeof source === 'string' ? source : JSON.stringify(source),
        platform: payload.platform
      });
      renderLaunchResult(result);
    }

    async function submitRun() {
      const result = await postJson('/api/runs', launcherPayload());
      renderLaunchResult(result);
      if (result.runId) {
        selectScope(result.sessionId || '');
        selectRun(result.runId);
      }
      await tick();
    }

    function formatPayloadAsJson() {
      try {
        const payload = launcherPayload();
        els.launchPayload.value = JSON.stringify(payload, null, 2);
        renderPayloadPreview({force: true});
      } catch (error) {
        renderLaunchResult(`error: ${error.message}`);
      }
    }

    function formatPayloadAsYaml() {
      const text = els.launchPayload.value.trim();
      if (text.startsWith('{')) {
        try {
          const decoded = JSON.parse(text);
          els.launchKind.value = decoded.kind || els.launchKind.value;
          if (decoded.scriptText || decoded.configText) {
            els.launchPayload.value = decoded.scriptText || decoded.configText;
          }
        } catch (error) {
          renderLaunchResult(`error: ${error.message}`);
        }
      }
      renderPayloadPreview({force: true});
    }

    document.getElementById('refreshNow').onclick = (event) => {
      event.stopPropagation();
      tick();
    };
    document.getElementById('selectLatest').onclick = (event) => {
      event.stopPropagation();
      selectScope('');
      tick();
    };
    document.getElementById('copyRunId').onclick = async (event) => {
      event.stopPropagation();
      if (!state.selectedRunId || !navigator.clipboard) return;
      await navigator.clipboard.writeText(state.selectedRunId);
    };
    document.getElementById('parseWorkflow').onclick = () => parseWorkflow().catch((error) => renderLaunchResult(`error: ${error.message}`));
    document.getElementById('submitRun').onclick = () => submitRun().catch((error) => renderLaunchResult(`error: ${error.message}`));
    document.getElementById('formatJson').onclick = formatPayloadAsJson;
    document.getElementById('formatYaml').onclick = formatPayloadAsYaml;
    document.getElementById('expandTimeline').onclick = () => {
      state.expandAll = !state.expandAll;
      for (const event of state.events) {
        setDynamicPanelOpen('event', eventKey(event), state.expandAll);
      }
      renderTimeline();
    };
    els.collapsePanels.onclick = () => setPanelGroupOpen(false);
    els.expandPanels.onclick = () => setPanelGroupOpen(true);
    els.mediaViewerClose.onclick = closeMediaViewer;
    els.mediaViewerBackdrop.onclick = closeMediaViewer;
    els.mediaViewerSize.onclick = toggleMediaViewerSize;
    els.mediaViewerCopy.onclick = () => copyMediaViewerLink().catch(() => {
      els.mediaViewerCopy.textContent = 'copy failed';
      setTimeout(() => {
        els.mediaViewerCopy.textContent = 'copy link';
      }, 1200);
    });
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && !els.mediaViewer.hidden) {
        event.preventDefault();
        closeMediaViewer();
      }
    });
    els.runSearch.oninput = renderRuns;
    els.scopeSelect.onchange = () => {
      selectScope(els.scopeSelect.value);
      renderAll();
      tick();
    };
    els.launchPayload.oninput = () => renderPayloadPreview();
    els.launchKind.onchange = () => renderPayloadPreview();
    els.launcherPanel.addEventListener('toggle', () => {
      if (els.launcherPanel.open && state.payloadPreviewDirty) {
        renderPayloadPreview({force: true});
      }
    });

    for (const button of document.querySelectorAll('[data-filter]')) {
      button.onclick = () => {
        state.eventFilter = button.dataset.filter;
        renderTimeline();
      };
    }
    document.getElementById('tabEvent').onclick = () => { state.inspectorTab = 'event'; renderInspector(); };
    document.getElementById('tabState').onclick = () => { state.inspectorTab = 'state'; renderInspector(); };
    document.getElementById('tabYaml').onclick = () => { state.inspectorTab = 'yaml'; renderInspector(); };

    restorePanelState();
    applyDensityLayout();
    wirePanelStatePersistence();
    renderAll();
    renderPayloadPreview();
    tick();
    state.timer = setInterval(tick, AUTO_REFRESH_MS);
    addEventListener('resize', applyDensityLayout);
    addEventListener('pagehide', () => clearInterval(state.timer));
  </script>
</body>
</html>
''';
