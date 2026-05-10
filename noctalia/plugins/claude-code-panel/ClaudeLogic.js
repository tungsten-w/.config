.pragma library

// ClaudeLogic.js — pure helpers for the Claude Code ACP integration.
// No QML/Qt deps. Safe to unit-test in any JS runtime.

// ============================================================================
// System prompt
// ============================================================================
// ACP's NewSessionRequest does NOT accept a systemPrompt field (spec only has
// cwd + mcpServers), and claude-code-acp silently drops unknown params. So we
// inject our context as a hidden prefix on the first user turn of each session
// via firstTurnPrefix() — version-independent and guaranteed to be seen.

var NOCTALIA_SYSTEM_PROMPT =
"You are Claude running inside the **claude-code-panel** plugin of **Noctalia Shell** " +
"(a Quickshell-based Wayland desktop). Your responses stream into a side panel via ACP.\n" +
"\n" +
"## Desktop control — Noctalia IPC\n" +
"Invoke IPC from Bash:\n" +
"```bash\n" +
"qs -c noctalia-shell ipc call <target> <function> [args...]\n" +
"```\n" +
"\n" +
"Discovery (use first when unsure):\n" +
"- `qs -c noctalia-shell ipc show` — list every target and its function signatures\n" +
"- `qs -c noctalia-shell ipc call state all` — full JSON snapshot (screens, settings, widgets)\n" +
"\n" +
"Common targets (non-exhaustive — run `ipc show` for the authoritative list):\n" +
"- **Appearance**: `darkMode`, `nightLight`, `colorScheme`, `wallpaper`\n" +
"- **Shell UI**: `bar`, `dock`, `controlCenter`, `launcher`, `settings`, `calendar`, " +
"`desktopWidgets`, `systemMonitor`\n" +
"- **Notifications**: `notifications`, `toast`\n" +
"- **Hardware**: `brightness`, `volume`, `monitors`, `wifi`, `bluetooth`, `airplaneMode`, " +
"`network`, `battery`\n" +
"- **Power/session**: `powerProfile`, `lockScreen`, `sessionMenu`, `idleInhibitor`\n" +
"- **Media**: `media` (playPause, next, previous, seekRelative, seekByRatio)\n" +
"- **Other**: `location`, `plugin`\n" +
"\n" +
"Many functions take a `<screen>` argument (e.g. `wallpaper random eDP-1`). Get screen " +
"names from `ipc call state all`. When the user doesn't specify one, apply to **all** screens.\n" +
"\n" +
"## Conventions\n" +
"- **IPC first** for desktop actions (\"dark mode\", \"lock screen\", \"set wallpaper\") — " +
"immediate, reversible, no config mutation.\n" +
"- **Absolute paths only.** Qt's QProcess does not expand `~`.\n" +
"- **Panel-aware output.** Narrow column; keep answers concise. Markdown renders.\n" +
"- **On IPC error** or unknown-arg response, run `ipc show` to verify the signature.\n" +
"- **Code tasks**: behave as standard Claude Code. The Noctalia context is additive.";

// Compose the effective system-prompt text from settings.
function composeSystemPrompt(settings) {
  var userPrompt = (settings && settings.appendSystemPrompt) ? String(settings.appendSystemPrompt).trim() : "";
  var inject = !(settings && settings.injectNoctaliaContext === false);
  if (!inject) { return userPrompt; }
  if (userPrompt === "") { return NOCTALIA_SYSTEM_PROMPT; }
  return NOCTALIA_SYSTEM_PROMPT + "\n\n## User-provided instructions\n" + userPrompt;
}

// Build the hidden prefix that rides along on the first user turn of a session.
// Wrapped in a <system> block so the model treats it as instructions, not chat.
// Returns "" when no prompt is configured.
function firstTurnPrefix(settings) {
  var sys = composeSystemPrompt(settings);
  if (!sys || sys.trim() === "") { return ""; }
  return "<system>\n" + sys + "\n</system>\n\n";
}

// ============================================================================
// Path helpers
// ============================================================================

// Expand a leading `~` or `~/` to the given home directory. Qt's QProcess does
// NOT perform shell-level tilde expansion on workingDirectory — chdir("~/Foo")
// fails with ENOENT, which surfaces as a misleading "binary not found" error.
function expandHome(path, home) {
  if (!path) { return path; }
  var s = String(path).trim();
  if (!home) { return s; }
  if (s === "~") { return home; }
  if (s.indexOf("~/") === 0) { return home + s.substring(1); }
  return s;
}

// ============================================================================
// Markdown block parser
// ============================================================================
// Splits a markdown string into an ordered list of blocks so the renderer can
// give code blocks dedicated styling (mono font, dark slab, per-block copy
// button, language tag) while leaving prose to Qt's native MarkdownText.
//
// Returns an array of:
//   { kind: "text", text: "...prose..." }
//   { kind: "code", lang: "python", text: "...code body..." }
//
// Behaviour notes:
// - Only *closed* fenced blocks are extracted. While a reply is mid-stream and
//   a fence has only opened, the partial fence stays inside a "text" block;
//   once the closing ``` arrives, the next re-parse picks it up. This avoids
//   flickering between styles during streaming.
// - Tildes (~~~) are accepted as alternate fence markers, matching CommonMark.
// - Trailing newline inside the code body is trimmed so the slab doesn't have
//   a phantom empty last line.
function parseMarkdownBlocks(text) {
  if (!text) { return []; }
  var src = String(text);
  var blocks = [];
  var fence = /(^|\n)(```|~~~)([^\n`~]*)\n([\s\S]*?)\n\2(?=\n|$)/g;
  var lastIdx = 0;
  var m;
  while ((m = fence.exec(src)) !== null) {
    var start = m.index + m[1].length;   // skip the leading newline (if any)
    if (start > lastIdx) {
      var pre = src.substring(lastIdx, start);
      if (pre.replace(/\s/g, "") !== "") {
        blocks.push({ kind: "text", text: pre.replace(/^\n+|\n+$/g, "") });
      }
    }
    blocks.push({
      kind: "code",
      lang: (m[3] || "").trim(),
      text: m[4]
    });
    lastIdx = fence.lastIndex;
  }
  if (lastIdx < src.length) {
    var tail = src.substring(lastIdx);
    if (tail.replace(/\s/g, "") !== "") {
      blocks.push({ kind: "text", text: tail.replace(/^\n+/, "") });
    }
  }
  // Empty-input fast path: still emit a single text block so the renderer has
  // exactly one delegate to bind against.
  if (blocks.length === 0) { blocks.push({ kind: "text", text: src }); }
  return blocks;
}

// ============================================================================
// Tool display helpers
// ============================================================================

// Summarize tool input for display (one-line preview).
function summarizeToolInput(name, input) {
  if (!input || typeof input !== "object") { return ""; }
  switch (name) {
    case "Bash":      return input.command || "";
    case "Read":      return input.file_path || "";
    case "Write":     return input.file_path || "";
    case "Edit":      return input.file_path || "";
    case "Glob":      return input.pattern || "";
    case "Grep":      return (input.pattern || "") + (input.path ? " in " + input.path : "");
    case "WebFetch":  return input.url || "";
    case "WebSearch": return input.query || "";
    case "Task":      return input.description || input.subagent_type || "";
    default:
      try { return JSON.stringify(input).slice(0, 240); } catch (e) { return ""; }
  }
}

// Safety classification for a tool invocation. Drives the UI warning colour.
// Returns "safe" | "write" | "exec" | "network".
function classifyTool(name) {
  if (!name) { return "safe"; }
  if (name === "Bash") { return "exec"; }
  if (name === "Write" || name === "Edit" || name === "NotebookEdit") { return "write"; }
  if (name === "WebFetch" || name === "WebSearch") { return "network"; }
  if (name.indexOf("mcp__") === 0) { return "network"; }
  return "safe";
}

// ============================================================================
// ACP (Agent Client Protocol) — JSON-RPC 2.0 over stdio, newline-delimited
// ============================================================================
// Three message kinds:
//   request       → { id, method, params }, expects a response with same id
//   response      → { id, result | error }, correlated to prior request
//   notification  → { method, params } with no id; fire-and-forget

// Reserved ids: 1=initialize, 2=session/new. Everything else starts at 10.
var _acpIdCounter = 10;
function nextAcpId() { return _acpIdCounter++; }

function makeAcpRequest(method, params) {
  return JSON.stringify({
    jsonrpc: "2.0",
    id: _acpIdCounter++,
    method: method,
    params: params || {}
  }) + "\n";
}

function makeAcpRequestWithId(id, method, params) {
  return JSON.stringify({
    jsonrpc: "2.0",
    id: id,
    method: method,
    params: params || {}
  }) + "\n";
}

function makeAcpResponse(id, result) {
  return JSON.stringify({ jsonrpc: "2.0", id: id, result: result }) + "\n";
}

function makeAcpError(id, code, message) {
  return JSON.stringify({
    jsonrpc: "2.0",
    id: id,
    error: { code: code || -32000, message: message || "Error" }
  }) + "\n";
}

// Classify an incoming ACP JSON message.
//   "request"  → { id, method, params }   (agent → client, needs response)
//   "response" → { id, result | error }   (response to a prior request)
//   "notify"   → { method, params }       (one-way; usually session/update)
//   "raw"      → not a valid ACP frame
function parseAcpLine(line) {
  if (!line) return null;
  var trimmed = String(line).trim();
  if (trimmed === "") return null;
  var msg;
  try { msg = JSON.parse(trimmed); } catch (e) { return { kind: "raw", line: trimmed }; }
  if (!msg || typeof msg !== "object") return { kind: "raw", line: trimmed };
  if (msg.method && msg.id !== undefined && msg.id !== null) {
    return { kind: "request", id: msg.id, method: msg.method, params: msg.params || {} };
  }
  if (msg.method) {
    return { kind: "notify", method: msg.method, params: msg.params || {} };
  }
  if (msg.id !== undefined && (msg.result !== undefined || msg.error !== undefined)) {
    return { kind: "response", id: msg.id, result: msg.result, error: msg.error };
  }
  return { kind: "raw", line: trimmed };
}

// Convert an ACP session/update notification's inner `update` into a normalized
// event the QML side can route through applyEvent().
//
// Discriminator is `update.sessionUpdate` (not `update.type`). Several update
// kinds put their payload directly on `update` instead of a nested object —
// e.g. { sessionUpdate: "tool_call", toolCallId: "...", title, status, content }
// rather than { sessionUpdate: "tool_call", toolCall: { ... } }. Handle both.
function normalizeAcpUpdate(update) {
  if (!update || typeof update !== "object") { return null; }
  var t = update.sessionUpdate || update.type;
  if (!t) { return null; }

  if (t === "agent_message_chunk" && update.content) {
    return { kind: "assistant_text", text: _contentBlockToText(update.content), append: true };
  }
  if (t === "agent_thought_chunk" && update.content) {
    return { kind: "thinking_chunk", text: _contentBlockToText(update.content) };
  }
  if (t === "user_message_chunk" && update.content) {
    return { kind: "user_echo", text: _contentBlockToText(update.content) };
  }
  if (t === "tool_call") {
    var tc = update.toolCall || update;
    return {
      kind: "tool_use",
      id: tc.toolCallId || tc.toolUseId || tc.id || "",
      name: tc.toolName || tc.title || tc.kind || tc.name || "",
      input: tc.input || tc.rawInput || tc.arguments || {},
      status: tc.status || "pending",
      content: _flattenToolContent(tc.content)
    };
  }
  if (t === "tool_call_update") {
    var tu = update.toolCallUpdate || update;
    return {
      kind: "tool_result",
      toolUseId: tu.toolCallId || tu.toolUseId || tu.id || "",
      content: _flattenToolContent(tu.content),
      isError: !!tu.isError,
      status: tu.status || ""
    };
  }
  if (t === "plan") {
    var p = update.plan || update;
    return { kind: "plan", entries: p.entries || [] };
  }
  if (t === "usage_update") {
    return { kind: "usage", used: update.used, size: update.size, cost: update.cost };
  }
  if (t === "available_commands_update") {
    return { kind: "available_commands", commands: update.availableCommands || [] };
  }
  if (t === "current_mode_update") {
    var cm = update.currentModeUpdate || update;
    return { kind: "current_mode", modeId: cm.currentModeId || cm.modeId || "" };
  }
  if (t === "session_info_update") {
    var si = update.sessionInfoUpdate || update;
    return { kind: "session_info", title: si.title || "", updatedAt: si.updatedAt || "" };
  }
  return { kind: "raw", update: update };
}

// Flatten an ACP tool-call `content` array (text blocks + nested content blocks)
// into a single string.
function _flattenToolContent(content) {
  if (!content) { return ""; }
  if (typeof content === "string") { return content; }
  if (!Array.isArray(content)) { return _contentBlockToText(content); }
  var out = "";
  for (var i = 0; i < content.length; i++) {
    var c = content[i];
    if (!c) { continue; }
    if (c.type === "text" && typeof c.text === "string") { out += c.text; continue; }
    if (c.type === "content" && c.content) { out += _contentBlockToText(c.content); continue; }
    if (typeof c.text === "string") { out += c.text; }
  }
  return out;
}

function _contentBlockToText(block) {
  if (!block) return "";
  if (typeof block === "string") return block;
  if (block.type === "text" && typeof block.text === "string") return block.text;
  if (typeof block.text === "string") return block.text;
  return "";
}

// Build a permission-response `result` payload.
//   decision: "allow_once" | "allow_always" | "reject_once" | "reject_always" | "cancelled"
function makePermissionOutcome(decision) {
  if (decision === "cancelled") {
    return { outcome: { outcome: "cancelled" } };
  }
  return { outcome: { outcome: "selected", optionId: decision } };
}

// ============================================================================
// Persist + restore
// ============================================================================

function processLoadedState(content) {
  if (!content || String(content).trim() === "") { return null; }
  try {
    var c = JSON.parse(content);
    return {
      messages: c.messages || [],
      sessionId: c.sessionId || "",
      lastModel: c.lastModel || "",
      lastPermissionMode: c.lastPermissionMode || "default",
      inputText: c.inputText || "",
      inputCursor: c.inputCursor || 0
    };
  } catch (err) {
    return { error: err.toString() };
  }
}

function prepareStateForSave(state, maxHistory) {
  var max = maxHistory && maxHistory > 0 ? maxHistory : 200;
  var msgs = (state.messages || []).slice(-max);
  return JSON.stringify({
    messages: msgs,
    sessionId: state.sessionId || "",
    lastModel: state.lastModel || "",
    lastPermissionMode: state.lastPermissionMode || "default",
    inputText: state.inputText || "",
    inputCursor: state.inputCursor || 0,
    timestamp: Math.floor(Date.now() / 1000)
  }, null, 2);
}
