import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import "ClaudeLogic.js" as Logic

// ============================================================================
// ACP-based Claude Code client.
// Speaks Agent Client Protocol (JSON-RPC 2.0 over stdio) with `claude-code-acp`,
// the official Zed-industries bridge that wraps the regular claude CLI and
// exposes it over ACP. This replaces the earlier `claude -p` one-shot path so
// that `session/request_permission` works — i.e. the Yes/Allow-all/No buttons
// in Panel.qml actually gate tool execution instead of just writing hints to
// settings.json after the fact.
// ============================================================================
Item {
  id: root

  property var pluginApi: null

  // ----- Conversation state -----
  property var messages: []
  property bool isGenerating: false
  property string errorMessage: ""
  property bool isManuallyStopped: false
  property string streamingMessageId: ""
  property bool sawPartialThisTurn: false

  readonly property string currentAssistantBuffer: {
    if (!streamingMessageId) return "";
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].id === streamingMessageId) return messages[i].text || "";
    }
    return "";
  }

  // ----- Session state -----
  property string sessionId: ""
  property string lastModel: ""
  property string lastPermissionMode: "default"
  property var lastTools: []
  property var lastMcpServers: []

  // ----- Input persistence -----
  property string inputText: ""
  property int inputCursor: 0

  // ----- CLI health -----
  property bool binaryAvailable: false
  property bool binaryChecked: false
  property string resolvedBinaryPath: ""

  // ----- ACP process lifecycle -----
  // acpPhase: "idle" → "spawning" → "initializing" → "session_new" → "ready"
  property string acpPhase: "idle"
  property var _pendingPrompts: []          // user messages buffered until session ready
  property var _toolUseByCallId: ({})       // toolUseId → message.id (for tool_call_update routing)
  property var _pendingPermissions: ({})    // message.id → { rpcId, options }
  property int _currentPromptId: -1         // id of the in-flight session/prompt request
  property string streamingThinkingId: ""   // live thinking bubble id (separate from assistant text)
  property bool _systemPromptPending: false // inject Noctalia prompt on the next user turn

  // ACP uses `~/.claude-code-acp` state in practice but also reads the same claude config.
  // We leave permissionMode alone; ACP has its own permission negotiation.

  // ----- Cache paths -----
  readonly property string cacheDir: (typeof Settings !== 'undefined' && Settings.cacheDir)
      ? Settings.cacheDir + "plugins/claude-code-panel/" : ""
  readonly property string stateCachePath: cacheDir + "state.json"

  // ----- Settings accessors -----
  readonly property var claudeSettings: pluginApi?.pluginSettings?.claude || ({})
  readonly property string binaryPath: claudeSettings.binary || "claude-code-acp"
  readonly property string workingDir: claudeSettings.workingDir || ""
  readonly property string permissionMode: claudeSettings.permissionMode || "default"
  readonly property bool dangerouslySkip: claudeSettings.dangerouslySkipPermissions === true

  Component.onCompleted: {
    Logger.i("ClaudeCode", "Plugin initialized (ACP mode)");
    ensureCacheDir();
    checkBinary();
  }

  function ensureCacheDir() {
    if (cacheDir) { Quickshell.execDetached(["mkdir", "-p", cacheDir]); }
  }

  // ---------- Binary presence check ----------
  // We prefer `claude-code-acp`; fall back to whatever `binaryPath` the user set.
  Process {
    id: whichProcess
    command: ["which", "claude-code-acp"]
    stdout: StdioCollector {
      onStreamFinished: {
        var resolved = (text || "").trim();
        if (resolved.indexOf("\n") !== -1) { resolved = resolved.split("\n")[0].trim(); }
        root.resolvedBinaryPath = resolved;
        root.binaryAvailable = (resolved !== "");
        root.binaryChecked = true;
        if (!root.binaryAvailable) {
          Logger.w("ClaudeCode", "`claude-code-acp` not found on PATH. Install: npm i -g @zed-industries/claude-code-acp");
        } else {
          Logger.i("ClaudeCode", "Using claude-code-acp at: " + resolved);
          startAcpProcess();
        }
      }
    }
    stderr: StdioCollector {}
  }

  function checkBinary() {
    binaryChecked = false;
    whichProcess.command = ["which", "claude-code-acp"];
    whichProcess.running = true;
  }

  onBinaryPathChanged: checkBinary()

  // ---------- State persistence ----------
  FileView {
    id: stateCacheFile
    path: root.stateCachePath
    watchChanges: false
    onLoaded: loadStateFromCache()
    onLoadFailed: function (error) {
      if (error !== 2) { Logger.e("ClaudeCode", "state load failed: " + error); }
    }
  }

  function loadStateFromCache() {
    var result = Logic.processLoadedState(stateCacheFile.text());
    if (!result || result.error) {
      if (result && result.error) { Logger.e("ClaudeCode", "state parse: " + result.error); }
      return;
    }
    root.messages = result.messages;
    root.sessionId = result.sessionId;
    root.lastModel = result.lastModel;
    root.lastPermissionMode = result.lastPermissionMode;
    root.inputText = result.inputText;
    root.inputCursor = result.inputCursor;
  }

  Timer {
    id: saveStateTimer
    interval: 500
    onTriggered: root.performSaveState()
  }
  property bool saveStateQueued: false

  function saveState() {
    saveStateQueued = true;
    saveStateTimer.restart();
  }

  function performSaveState() {
    if (!saveStateQueued || !cacheDir) { return; }
    saveStateQueued = false;
    try {
      ensureCacheDir();
      var maxHistory = pluginApi?.pluginSettings?.maxHistoryLength || 200;
      var data = Logic.prepareStateForSave({
        messages: root.messages,
        sessionId: root.sessionId,
        lastModel: root.lastModel,
        lastPermissionMode: root.lastPermissionMode,
        inputText: root.inputText,
        inputCursor: root.inputCursor
      }, maxHistory);
      stateCacheFile.setText(data);
    } catch (e) {
      Logger.e("ClaudeCode", "state save: " + e);
    }
  }

  // ---------- Message helpers ----------
  function pushMessage(entry) {
    var withMeta = Object.assign({
      id: Date.now().toString() + "-" + Math.random().toString(36).slice(2, 6),
      timestamp: new Date().toISOString()
    }, entry);
    root.messages = [...root.messages, withMeta];
    saveState();
    return withMeta;
  }

  function clearMessages() {
    root.messages = [];
    root.streamingMessageId = "";
    root.streamingThinkingId = "";
    root._toolUseByCallId = ({});
    root._pendingPermissions = ({});
    saveState();
  }

  function _indexOfMessage(id) {
    for (var i = root.messages.length - 1; i >= 0; i--) {
      if (root.messages[i].id === id) return i;
    }
    return -1;
  }

  function _replaceMessageAt(i, updated) {
    root.messages = [...root.messages.slice(0, i), updated, ...root.messages.slice(i + 1)];
  }

  function ensureStreamingMessage() {
    if (root.streamingMessageId) { return root.streamingMessageId; }
    var entry = pushMessage({ role: "assistant", kind: "text", text: "", streaming: true });
    root.streamingMessageId = entry.id;
    return entry.id;
  }

  function appendToStreaming(text) {
    if (!text) { return; }
    var id = ensureStreamingMessage();
    var idx = _indexOfMessage(id);
    if (idx === -1) { return; }
    var current = root.messages[idx];
    _replaceMessageAt(idx, Object.assign({}, current, { text: (current.text || "") + text }));
    saveState();
  }

  function setStreamingText(text) {
    var id = ensureStreamingMessage();
    var idx = _indexOfMessage(id);
    if (idx === -1) { return; }
    var current = root.messages[idx];
    _replaceMessageAt(idx, Object.assign({}, current, { text: text || "" }));
    saveState();
  }

  function finalizeStreaming() {
    if (!root.streamingMessageId) { return; }
    var idx = _indexOfMessage(root.streamingMessageId);
    root.streamingMessageId = "";
    if (idx === -1) { return; }
    var current = root.messages[idx];
    if (!current.text || current.text.trim() === "") {
      root.messages = [...root.messages.slice(0, idx), ...root.messages.slice(idx + 1)];
    } else {
      _replaceMessageAt(idx, Object.assign({}, current, { streaming: false }));
    }
    saveState();
  }

  function newSession() {
    stopAcpProcess();
    root.sessionId = "";
    root.messages = [];
    root.streamingMessageId = "";
    root._toolUseByCallId = ({});
    root._pendingPermissions = ({});
    root.errorMessage = "";
    saveState();
    ToastService.showNotice(pluginApi?.tr("toast.sessionCleared"));
    if (root.binaryAvailable) { startAcpProcess(); }
  }

  // ==========================================================================
  // ACP process + JSON-RPC plumbing
  // ==========================================================================
  Process {
    id: acpProcess
    stdinEnabled: true
    running: false

    property string stderrBuffer: ""
    property string stdoutBuffer: ""   // accumulates bytes until newline for NDJSON framing

    stdout: SplitParser {
      onRead: function (line) { root._onAcpLine(line); }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text && text.trim() !== "") {
          Logger.w("ClaudeCode", "acp stderr: " + text);
          acpProcess.stderrBuffer = text;
        }
      }
    }

    onStarted: {
      Logger.i("ClaudeCode", "claude-code-acp started (pid=" + acpProcess.processId + ")");
      root._sendInitialize();
    }

    onExited: function (exitCode, exitStatus) {
      Logger.i("ClaudeCode", "acp exited code=" + exitCode + " status=" + exitStatus);
      root._onAcpExited(exitCode);
    }
  }

  function startAcpProcess() {
    if (acpProcess.running) { return; }
    if (!root.binaryAvailable) {
      root.errorMessage = "claude-code-acp not found. Install with: npm i -g @zed-industries/claude-code-acp";
      return;
    }
    root.acpPhase = "spawning";
    var home = Quickshell.env("HOME") || "";
    var cwd = root.workingDir ? Logic.expandHome(root.workingDir, home) : (home || "/tmp");
    acpProcess.workingDirectory = cwd;
    acpProcess.command = [root.resolvedBinaryPath];
    acpProcess.stderrBuffer = "";
    acpProcess.stdoutBuffer = "";
    acpProcess.running = true;
  }

  function stopAcpProcess() {
    if (acpProcess.running) {
      acpProcess.running = false;
    }
    root.acpPhase = "idle";
    root._currentPromptId = -1;
    root.isGenerating = false;
    _finalizeThinking();
    finalizeStreaming();
  }

  function _onAcpExited(code) {
    var wasReady = root.acpPhase === "ready";
    root.acpPhase = "idle";
    root.isGenerating = false;
    finalizeStreaming();
    if (!root.isManuallyStopped && code !== 0 && wasReady) {
      root.errorMessage = "claude-code-acp exited unexpectedly (code " + code + ")" +
        (acpProcess.stderrBuffer ? ": " + acpProcess.stderrBuffer.trim() : "");
    }
    root.isManuallyStopped = false;
  }

  // Write a JSON-RPC frame (already newline-terminated) to the agent's stdin.
  function _acpWrite(frame) {
    if (!acpProcess.running) {
      Logger.w("ClaudeCode", "acp write while not running: " + frame.slice(0, 120));
      return;
    }
    try {
      Logger.i("ClaudeCode", "→ " + frame.slice(0, 240).replace(/\n$/, ""));
      acpProcess.write(frame);
    } catch (e) {
      Logger.e("ClaudeCode", "acp write failed: " + e);
      root.errorMessage = "Failed to write to agent (Quickshell Process.write). " +
                          "This build of Quickshell may not support stdinEnabled.";
    }
  }

  // ---------- Handshake ----------
  function _sendInitialize() {
    root.acpPhase = "initializing";
    var req = Logic.makeAcpRequestWithId(1, "initialize", {
      protocolVersion: 1,
      clientInfo: {
        name: "noctalia-claude-code-panel",
        version: "1.0.0",
        title: "Noctalia Claude Code Panel"
      },
      clientCapabilities: {
        fs: { readTextFile: true, writeTextFile: true },
        terminal: false
      }
    });
    _acpWrite(req);
  }

  function _sendSessionNew() {
    root.acpPhase = "session_new";
    var home = Quickshell.env("HOME") || "";
    var cwd = root.workingDir ? Logic.expandHome(root.workingDir, home) : (home || "/tmp");
    // ACP's NewSessionRequest spec only accepts { cwd, mcpServers }. Any systemPrompt
    // field is silently dropped by claude-code-acp. We instead inject the Noctalia
    // context as a hidden prefix on the first user turn (see _dispatchPrompt).
    root._systemPromptPending = true;
    var req = Logic.makeAcpRequestWithId(2, "session/new", {
      cwd: cwd,
      mcpServers: []
    });
    _acpWrite(req);
  }

  // ---------- Incoming line dispatch ----------
  function _onAcpLine(line) {
    // Echo every non-empty stdout line at INFO so we can see the full wire traffic while
    // stabilizing the ACP integration. Drop this back to `d` once things are solid.
    if (line && String(line).trim() !== "") {
      Logger.i("ClaudeCode", "← " + String(line).slice(0, 400));
    }
    var msg = Logic.parseAcpLine(line);
    if (!msg) { return; }
    if (msg.kind === "raw") {
      Logger.w("ClaudeCode", "acp raw (unparsed): " + msg.line);
      return;
    }
    if (msg.kind === "response") {
      _handleAcpResponse(msg);
      return;
    }
    if (msg.kind === "request") {
      _handleAcpRequest(msg);
      return;
    }
    if (msg.kind === "notify") {
      _handleAcpNotification(msg);
      return;
    }
  }

  function _handleAcpResponse(msg) {
    if (msg.error) {
      Logger.e("ClaudeCode", "acp response error id=" + msg.id + ": " + JSON.stringify(msg.error));

      // Build a human-readable message. claude-code-acp tucks the actually-useful
      // string under error.data.details (e.g. "Invalid permissions.defaultMode: auto.").
      var baseMsg = msg.error.message || "Agent error";
      var details = msg.error.data && msg.error.data.details ? msg.error.data.details : "";
      var humanMsg = details ? (baseMsg + ": " + details) : baseMsg;

      // Initialize (id=1) or session/new (id=2): the panel can't make progress
      // without these. Surface the error, reset phase, and drop queued prompts
      // so the user sees what's wrong instead of a silent "queued forever".
      if (msg.id === 1 || msg.id === 2) {
        var hint = "";
        if (details && details.indexOf("permissions.defaultMode") !== -1) {
          hint = "\nFix: edit ~/.claude/settings.json — `permissions.defaultMode` must be one of " +
                 "default | acceptEdits | plan | bypassPermissions.";
        }
        root.errorMessage = (msg.id === 1 ? "Failed to initialize agent: " : "Failed to start session: ") + humanMsg + hint;
        root.acpPhase = "idle";
        root.isGenerating = false;
        root._pendingPrompts = [];
        finalizeStreaming();
        return;
      }

      if (msg.id === root._currentPromptId) {
        root.isGenerating = false;
        finalizeStreaming();
        root.errorMessage = humanMsg;
        root._currentPromptId = -1;
      }
      return;
    }

    // initialize
    if (msg.id === 1) {
      var caps = msg.result || {};
      Logger.i("ClaudeCode", "initialize ok; protocolVersion=" + caps.protocolVersion);
      _sendSessionNew();
      return;
    }

    // session/new
    if (msg.id === 2) {
      var sr = msg.result || {};
      if (sr.sessionId) {
        root.sessionId = sr.sessionId;
        root.acpPhase = "ready";
        Logger.i("ClaudeCode", "session ready: " + sr.sessionId);
        _flushPendingPrompts();
      } else {
        root.errorMessage = "session/new returned no sessionId";
        Logger.e("ClaudeCode", root.errorMessage);
      }
      return;
    }

    // session/prompt completion
    if (msg.id === root._currentPromptId) {
      root.isGenerating = false;
      _finalizeThinking();
      finalizeStreaming();
      root._currentPromptId = -1;
      // Drain queued prompts, if any arrived while the last turn was in flight.
      if (root._pendingPrompts.length > 0) { _flushPendingPrompts(); }
      saveState();
      return;
    }
  }

  function _handleAcpRequest(msg) {
    // The only agent→client request we currently care about is permission.
    if (msg.method === "session/request_permission") {
      _presentPermission(msg.id, msg.params);
      return;
    }
    // Politely NACK anything else.
    _acpWrite(Logic.makeAcpError(msg.id, -32601, "Method not implemented: " + msg.method));
  }

  function _handleAcpNotification(msg) {
    if (msg.method !== "session/update") { return; }
    var params = msg.params || {};
    var update = params.update;
    var ev = Logic.normalizeAcpUpdate(update);
    if (!ev) { return; }
    root._applyNormalizedEvent(ev);
  }

  // ---------- Route normalized events into the existing message model ----------
  function _applyNormalizedEvent(ev) {
    if (!ev) { return; }
    switch (ev.kind) {
      case "assistant_text":
        // Finalize any in-progress thinking bubble when real assistant text starts.
        if (root.streamingThinkingId) { _finalizeThinking(); }
        if (ev.append) { appendToStreaming(ev.text); }
        else { setStreamingText((streamingMessageId ? currentAssistantBuffer : "") + (ev.text || "")); }
        break;
      case "thinking_chunk":
        // Stream thought chunks into a single dedicated bubble (don't spam a new
        // message per chunk). Skip leading empty chunks the agent sometimes emits.
        if (!ev.text) { break; }
        _appendToThinking(ev.text);
        break;
      case "user_echo":
        // Agent's own echo of the user prompt — we already displayed it, skip.
        break;
      case "tool_use": {
        _finalizeThinking();
        finalizeStreaming();
        var entry = pushMessage({
          role: "assistant",
          kind: "tool_use",
          text: Logic.summarizeToolInput(ev.name, ev.input),
          meta: {
            toolName: ev.name,
            toolId: ev.id,
            input: ev.input,
            classification: Logic.classifyTool(ev.name),
            status: ev.status || "pending"
          }
        });
        if (ev.id) {
          var map = Object.assign({}, root._toolUseByCallId);
          map[ev.id] = entry.id;
          root._toolUseByCallId = map;
        }
        root.sawPartialThisTurn = false;
        break;
      }
      case "tool_result": {
        // Update the tool_use bubble status, then push a result bubble.
        if (ev.toolUseId && root._toolUseByCallId[ev.toolUseId]) {
          var useMsgId = root._toolUseByCallId[ev.toolUseId];
          var idx = _indexOfMessage(useMsgId);
          if (idx !== -1) {
            var current = root.messages[idx];
            var nextMeta = Object.assign({}, current.meta || {}, {
              status: ev.status || "completed",
              isError: ev.isError
            });
            _replaceMessageAt(idx, Object.assign({}, current, { meta: nextMeta }));
          }
        }
        pushMessage({
          role: "tool",
          kind: "tool_result",
          text: ev.content || "",
          meta: { toolUseId: ev.toolUseId, isError: ev.isError, status: ev.status || "" }
        });
        break;
      }
      case "plan":
        var lines = [];
        for (var i = 0; i < (ev.entries || []).length; i++) {
          var e = ev.entries[i];
          var marker = e.status === "completed" ? "[x]" : (e.status === "in_progress" ? "[~]" : "[ ]");
          lines.push(marker + " " + (e.content || ""));
        }
        pushMessage({ role: "assistant", kind: "text", text: `**${pluginApi?.tr("panel.planTitle")}**\n\n${lines.join("\n")}` });
        break;
      case "usage":
      case "available_commands":
      case "current_mode":
      case "session_info":
        // Telemetry / metadata — log only. Surface later if the user wants a cost widget.
        break;
      case "raw":
        Logger.w("ClaudeCode", "acp unhandled update: " + JSON.stringify(ev.update).slice(0, 240));
        break;
    }
  }

  // ---------- Thinking stream helpers ----------
  function _ensureThinkingMessage() {
    if (root.streamingThinkingId) { return root.streamingThinkingId; }
    var entry = pushMessage({ role: "assistant", kind: "thinking", text: "", streaming: true });
    root.streamingThinkingId = entry.id;
    return entry.id;
  }

  function _appendToThinking(text) {
    var id = _ensureThinkingMessage();
    var idx = _indexOfMessage(id);
    if (idx === -1) { return; }
    var current = root.messages[idx];
    _replaceMessageAt(idx, Object.assign({}, current, { text: (current.text || "") + text }));
    saveState();
  }

  function _finalizeThinking() {
    if (!root.streamingThinkingId) { return; }
    var idx = _indexOfMessage(root.streamingThinkingId);
    root.streamingThinkingId = "";
    if (idx === -1) { return; }
    var current = root.messages[idx];
    if (!current.text || current.text.trim() === "") {
      root.messages = [...root.messages.slice(0, idx), ...root.messages.slice(idx + 1)];
    } else {
      _replaceMessageAt(idx, Object.assign({}, current, { streaming: false }));
    }
    saveState();
  }

  // ---------- Permission presentation ----------
  function _presentPermission(rpcId, params) {
    finalizeStreaming();
    var tc = params.toolCall || {};
    var toolName = tc.toolName || tc.title || "tool";
    var input = tc.input || tc.rawInput || {};
    var options = params.options || [];

    var entry = pushMessage({
      role: "assistant",
      kind: "tool_use",
      text: Logic.summarizeToolInput(toolName, input),
      meta: {
        toolName: toolName,
        toolId: tc.toolUseId || tc.toolCallId || "",
        input: input,
        classification: Logic.classifyTool(toolName),
        status: "awaiting_permission",
        permissionPending: true,
        permissionOptions: options
      }
    });

    var map = Object.assign({}, root._pendingPermissions);
    map[entry.id] = { rpcId: rpcId, options: options };
    root._pendingPermissions = map;

    if (tc.toolUseId || tc.toolCallId) {
      var key = tc.toolUseId || tc.toolCallId;
      var m2 = Object.assign({}, root._toolUseByCallId);
      m2[key] = entry.id;
      root._toolUseByCallId = m2;
    }
  }

  // Called by Panel.qml buttons. `decision` is one of the ACP optionKinds:
  //   "allow_once" | "allow_always" | "reject_once" | "reject_always" | "cancelled"
  // We resolve to an actual optionId from the options array by matching `kind`,
  // so we remain correct even if the agent renames labels.
  function respondToPermission(messageId, decision) {
    var pending = root._pendingPermissions[messageId];
    if (!pending) {
      Logger.w("ClaudeCode", "respondToPermission: no pending entry for " + messageId);
      return;
    }
    var optionId = decision;
    if (decision !== "cancelled") {
      var opts = pending.options || [];
      var pick = null;
      for (var i = 0; i < opts.length; i++) {
        if (opts[i].kind === decision) { pick = opts[i]; break; }
      }
      // Fallbacks if the preferred kind isn't offered:
      //   allow_always → allow_once; reject_always → reject_once
      if (!pick) {
        var fallbackKind = decision === "allow_always" ? "allow_once"
                         : (decision === "reject_always" ? "reject_once" : "");
        if (fallbackKind) {
          for (var j = 0; j < opts.length; j++) {
            if (opts[j].kind === fallbackKind) { pick = opts[j]; break; }
          }
        }
      }
      if (!pick) { pick = opts[0]; }
      optionId = pick ? pick.optionId : decision;
    }

    var result = Logic.makePermissionOutcome(decision === "cancelled" ? "cancelled" : optionId);
    // Note: makePermissionOutcome wraps non-"cancelled" strings as an optionId.
    _acpWrite(Logic.makeAcpResponse(pending.rpcId, result));

    // Stamp the bubble with the decision so the UI updates.
    var idx = _indexOfMessage(messageId);
    if (idx !== -1) {
      var current = root.messages[idx];
      var approvalLabel =
          decision === "allow_once"    ? "allow"     :
          decision === "allow_always"  ? "allow-all" :
          decision === "reject_once"   ? "deny"      :
          decision === "reject_always" ? "deny-all"  : "cancelled";
      var nextMeta = Object.assign({}, current.meta || {}, {
        approval: approvalLabel,
        permissionPending: false,
        status: decision.indexOf("allow") === 0 ? "running" : "rejected"
      });
      _replaceMessageAt(idx, Object.assign({}, current, { meta: nextMeta }));
    }

    var nm = Object.assign({}, root._pendingPermissions);
    delete nm[messageId];
    root._pendingPermissions = nm;
  }

  // Back-compat shims for Panel.qml — they call the older names.
  function approveOnce(messageId)                      { respondToPermission(messageId, "allow_once"); }
  function approveAllForSession(messageId, classification) { respondToPermission(messageId, "allow_always"); }
  function denyToolUse(messageId)                      { respondToPermission(messageId, "reject_once"); }

  // ---------- Sending ----------
  function sendMessage(userText) {
    if (!userText || userText.trim() === "") { return; }
    Logger.i("ClaudeCode", "sendMessage: phase=" + root.acpPhase +
             " session=" + (root.sessionId || "(none)") +
             " running=" + acpProcess.running +
             " generating=" + root.isGenerating);
    if (!binaryAvailable) {
      root.errorMessage = "claude-code-acp not available";
      ToastService.showError(root.errorMessage);
      return;
    }

    var text = userText.trim();
    pushMessage({ role: "user", kind: "text", text: text });

    if (root.acpPhase !== "ready") {
      // Queue until handshake finishes. startAcpProcess runs during onStarted.
      Logger.i("ClaudeCode", "phase not ready; queued. pending=" + (root._pendingPrompts.length + 1));
      root._pendingPrompts = root._pendingPrompts.concat([text]);
      if (!acpProcess.running && root.binaryAvailable) { startAcpProcess(); }
      return;
    }

    _dispatchPrompt(text);
  }

  function _flushPendingPrompts() {
    if (root.acpPhase !== "ready") { return; }
    var pending = root._pendingPrompts.slice();
    root._pendingPrompts = [];
    for (var i = 0; i < pending.length; i++) {
      _dispatchPrompt(pending[i]);
    }
  }

  function _dispatchPrompt(text) {
    if (!root.sessionId) {
      Logger.w("ClaudeCode", "_dispatchPrompt: no sessionId, dropping");
      return;
    }
    if (root.isGenerating) {
      Logger.i("ClaudeCode", "_dispatchPrompt: already generating, queued");
      root._pendingPrompts = root._pendingPrompts.concat([text]);
      return;
    }
    Logger.i("ClaudeCode", "_dispatchPrompt: sending prompt to session " + root.sessionId);
    root.isGenerating = true;
    root.isManuallyStopped = false;
    root.errorMessage = "";
    root.streamingMessageId = "";
    root.sawPartialThisTurn = false;

    var promptId = Logic.nextAcpId();
    root._currentPromptId = promptId;

    // First turn of a fresh session gets the Noctalia system prefix prepended.
    // Wrapped in <system>…</system> so the model treats it as instructions.
    var effectiveText = text;
    if (root._systemPromptPending) {
      var prefix = Logic.firstTurnPrefix(root.claudeSettings);
      if (prefix) { effectiveText = prefix + text; }
      root._systemPromptPending = false;
    }

    var frame = Logic.makeAcpRequestWithId(promptId, "session/prompt", {
      sessionId: root.sessionId,
      prompt: [{ type: "text", text: effectiveText }]
    });
    _acpWrite(frame);
  }

  function stopGeneration() {
    if (!acpProcess.running) {
      root.isGenerating = false;
      finalizeStreaming();
      return;
    }
    // ACP defines session/cancel as a notification.
    var frame = JSON.stringify({
      jsonrpc: "2.0",
      method: "session/cancel",
      params: { sessionId: root.sessionId }
    }) + "\n";
    _acpWrite(frame);
    root.isManuallyStopped = true;
    root.isGenerating = false;
    finalizeStreaming();
    ToastService.showNotice(pluginApi?.tr("toast.stopped"));
  }

  // ---------- Clipboard ----------
  function copyToClipboard(text) {
    if (typeof text !== "string" || text === "") { return; }
    const script = `if command -v wl-copy >/dev/null 2>&1; then printf %s "$1" | wl-copy; elif command -v xclip >/dev/null 2>&1; then printf %s "$1" | xclip -selection clipboard; elif command -v xsel >/dev/null 2>&1; then printf %s "$1" | xsel -b -i; fi`;
    Quickshell.execDetached(["sh", "-c", script, "--", text]);
    ToastService.showNotice(pluginApi?.tr("toast.copied"));
  }

  // ---------- Slash commands ----------
  function handleSlashCommand(raw) {
    if (!raw || raw[0] !== "/") { return false; }
    var parts = raw.trim().split(/\s+/);
    var cmd = parts[0].toLowerCase();
    var rest = parts.slice(1).join(" ");

    switch (cmd) {
      case "/help":
        pushMessage({
          role: "assistant",
          kind: "text",
          text: [
            "**Local commands**",
            "- `/help` — this list",
            "- `/clear` — clear chat history (local only; session persists)",
            "- `/new` — start a new Claude session",
            "- `/stop` — stop the current run",
            "- `/model <name>` — switch model (restarts session)",
            "- `/cwd <absolute-path>` — working directory",
            "- `/session` — show current session id",
            "- `/copy` — copy last assistant message",
            "",
            "Any other `/command` is passed through to the agent."
          ].join("\n")
        });
        return true;

      case "/clear":
        clearMessages();
        ToastService.showNotice(pluginApi?.tr("toast.historyCleared"));
        return true;

      case "/new":
        newSession();
        return true;

      case "/stop":
        stopGeneration();
        return true;

      case "/model":
        if (!rest) {
          pushMessage({ role: "assistant", kind: "text", text: (pluginApi?.tr("cmd.modelCurrent")) + (lastModel || claudeSettings.model || pluginApi?.tr("cmd.modelDefault")) + "`" });
          return true;
        }
        setClaudeField("model", rest);
        pushMessage({ role: "assistant", kind: "text", text: pluginApi?.tr("cmd.modelSet") + rest + "`" });
        newSession();
        return true;

      case "/cwd":
        if (!rest) {
          pushMessage({ role: "assistant", kind: "text", text: pluginApi?.tr("cmd.cwdCurrent") + "`" + (claudeSettings.workingDir || pluginApi?.tr("cmd.cwdDefault")) + "`" });
          return true;
        }
        setClaudeField("workingDir", rest);
        pushMessage({ role: "assistant", kind: "text", text: pluginApi?.tr("cmd.cwdSet") + rest + "`." });
        newSession();
        return true;

      case "/session":
        pushMessage({ role: "assistant", kind: "text", text: sessionId ? (pluginApi?.tr("cmd.sessionActive") + "`" + sessionId + "`") : pluginApi?.tr("cmd.sessionNone") });
        return true;

      case "/copy":
        for (var i = messages.length - 1; i >= 0; i--) {
          var msg = messages[i];
          if (msg.role === "assistant" && msg.kind === "text" && msg.text) {
            copyToClipboard(msg.text);
            return true;
          }
        }
        ToastService.showNotice("No assistant message to copy");
        return true;

      default:
        return false; // pass through to agent
    }
  }

  function setClaudeField(key, value) {
    if (!pluginApi) { return; }
    if (!pluginApi.pluginSettings.claude) { pluginApi.pluginSettings.claude = {}; }
    pluginApi.pluginSettings.claude[key] = value;
    pluginApi.saveSettings();
  }

  // ---------- IPC ----------
  IpcHandler {
    target: "plugin:claude-code-panel"

    function toggle() {
      if (pluginApi) { pluginApi.withCurrentScreen(function (s) { pluginApi.togglePanel(s); }); }
    }
    function open() {
      if (pluginApi) { pluginApi.withCurrentScreen(function (s) { pluginApi.openPanel(s); }); }
    }
    function close() {
      if (pluginApi) { pluginApi.withCurrentScreen(function (s) { pluginApi.closePanel(s); }); }
    }
    function send(message: string) {
      if (!message || message.trim() === "") { return; }
      if (message[0] === "/") {
        if (root.handleSlashCommand(message.trim())) { return; }
      }
      root.sendMessage(message);
    }
    function stop() { root.stopGeneration(); }
    function clear() {
      root.clearMessages();
      ToastService.showNotice(pluginApi?.tr("toast.historyCleared"));
    }
    function newSession() { root.newSession(); }
    function setModel(m: string)           { if (m) { root.setClaudeField("model", m); } }
    function setPermissionMode(mode: string) {
      if (["default","acceptEdits","plan","bypassPermissions"].indexOf(mode) === -1) { return; }
      root.setClaudeField("permissionMode", mode);
    }
    function setWorkingDir(path: string)   { root.setClaudeField("workingDir", path || ""); }
    function copyLast() {
      for (var i = root.messages.length - 1; i >= 0; i--) {
        var msg = root.messages[i];
        if (msg.role === "assistant" && msg.kind === "text" && msg.text) {
          root.copyToClipboard(msg.text);
          return;
        }
      }
    }
  }
}
