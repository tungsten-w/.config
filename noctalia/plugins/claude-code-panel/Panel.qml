import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI
import "ClaudeLogic.js" as Logic

Item {
  id: root

  property var pluginApi: null

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property var geometryPlaceholder: panelContainer

  readonly property string _panelPosition: pluginApi?.pluginSettings?.panelPosition ?? "right"
  readonly property bool _detached: pluginApi?.pluginSettings?.panelDetached ?? true
  readonly property string _attachmentStyle: pluginApi?.pluginSettings?.attachmentStyle || "connected"
  readonly property bool _isFloatingAttached: !_detached && _attachmentStyle === "floating"
  readonly property bool allowAttach: !_detached

  readonly property bool panelAnchorRight: _panelPosition === "right"
  readonly property bool panelAnchorLeft: _panelPosition === "left"
  readonly property bool panelAnchorHorizontalCenter:
      (_detached && _panelPosition === "center") ||
      (_isFloatingAttached && (_panelPosition === "top" || _panelPosition === "bottom"))
  readonly property bool panelAnchorVerticalCenter:
      _detached || (_isFloatingAttached && (_panelPosition === "left" || _panelPosition === "right"))
  readonly property bool panelAnchorTop: !_detached && _panelPosition === "top"
  readonly property bool panelAnchorBottom: !_detached && _panelPosition === "bottom"

  property int _panelWidth: pluginApi?.pluginSettings?.panelWidth ?? 620
  property real _panelHeightRatio: pluginApi?.pluginSettings?.panelHeightRatio ?? 0.9
  property real contentPreferredWidth: _panelWidth
  property real contentPreferredHeight: screen ? (screen.height * _panelHeightRatio) : 720 * Style.uiScaleRatio
  property real uiScale: pluginApi?.pluginSettings?.scale ?? 1

  anchors.fill: parent

  readonly property string permissionMode: mainInstance?.permissionMode || "default"
  readonly property bool dangerouslySkip: mainInstance?.dangerouslySkip || false
  readonly property bool isGenerating: mainInstance?.isGenerating || false

  // ----- Slash-command autocomplete -----
  // Static catalog mirrors Main.qml handleSlashCommand(). If you add a slash
  // command there, add it here too.
  readonly property var slashCommands: [
    { cmd: "/help",    desc: pluginApi?.tr("panel.slashHelp") },
    { cmd: "/clear",   desc: pluginApi?.tr("panel.slashClear") },
    { cmd: "/new",     desc: pluginApi?.tr("panel.slashNew") },
    { cmd: "/stop",    desc: pluginApi?.tr("panel.slashStop") },
    { cmd: "/model",   desc: pluginApi?.tr("panel.slashModel") },
    { cmd: "/cwd",     desc: pluginApi?.tr("panel.slashCwd") },
    { cmd: "/session", desc: pluginApi?.tr("panel.slashSession") },
    { cmd: "/copy",    desc: pluginApi?.tr("panel.slashCopy") }
  ]
  property var slashMenuMatches: []
  property int slashMenuIndex: 0
  property bool slashMenuOpen: false

  // Recompute matches from the current input. Menu shows only while the user is
  // still editing the first token (no space yet) and it starts with `/`.
  function _updateSlashMenu(text, cursorPos) {
    var first = (text || "").split(/\s/)[0];
    if (!first || first[0] !== "/" || cursorPos > first.length) {
      slashMenuOpen = false;
      slashMenuMatches = [];
      return;
    }
    var needle = first.toLowerCase();
    var out = [];
    for (var i = 0; i < slashCommands.length; i++) {
      if (slashCommands[i].cmd.indexOf(needle) === 0) { out.push(slashCommands[i]); }
    }
    slashMenuMatches = out;
    slashMenuOpen = out.length > 0;
    if (slashMenuIndex >= out.length) { slashMenuIndex = 0; }
  }

  // Replace the first token with the selected command + trailing space.
  function _applySlashCompletion() {
    if (!slashMenuOpen || slashMenuMatches.length === 0) { return false; }
    var pick = slashMenuMatches[slashMenuIndex];
    if (!pick) { return false; }
    var rest = inputArea.text.indexOf(" ") >= 0
      ? inputArea.text.substring(inputArea.text.indexOf(" "))
      : "";
    inputArea.text = pick.cmd + (rest || " ");
    inputArea.cursorPosition = pick.cmd.length + 1;
    slashMenuOpen = false;
    return true;
  }

  function bannerColor() {
    if (dangerouslySkip || permissionMode === "bypassPermissions") { return Color.mError; }
    if (permissionMode === "acceptEdits") { return Color.mSecondary; }
    if (permissionMode === "plan") { return Color.mTertiary; }
    return Color.mPrimary;
  }

  function bannerText() {
    if (dangerouslySkip || permissionMode === "bypassPermissions") {
      return pluginApi?.tr("panel.bannerBypass");
    }
    if (permissionMode === "acceptEdits") { return pluginApi?.tr("panel.bannerAccept"); }
    if (permissionMode === "plan") { return pluginApi?.tr("panel.bannerPlan"); }
    return pluginApi?.tr("panel.bannerDefault");
  }

  // Palette shims — Noctalia exposes mPrimary/mSecondary/mSurface/mSurfaceVariant but NOT
  // the Material3 `*Container` slots. We fake them with tinted surfaces so bubbles don't
  // collapse to white (QML's undefined-color fallback).
  function tintOf(base, amount) {
    if (!base) { return Color.mSurface; }
    return Qt.rgba(base.r, base.g, base.b, amount);
  }

  Rectangle {
    id: panelContainer
    width: contentPreferredWidth
    height: contentPreferredHeight
    color: "transparent"
    anchors.horizontalCenter: (_detached && _panelPosition === "center" && parent) ? parent.horizontalCenter : undefined
    anchors.verticalCenter: (_detached && _panelPosition === "center" && parent) ? parent.verticalCenter : undefined
    y: (_detached && (_panelPosition === "left" || _panelPosition === "right")) ? (root.height - contentPreferredHeight) / 2 : 0

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      // ----- Header -----
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: headerRow.implicitHeight + Style.marginS * 2
        color: Color.mSurfaceVariant
        radius: Style.radiusM

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginS
          spacing: Style.marginM

          ClaudeLogo {
            tint: Color.mPrimary
            Layout.preferredWidth: Style.fontSizeL * 1.6
            Layout.preferredHeight: Style.fontSizeL * 1.6
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS
            NText {
              text: pluginApi?.tr("panel.title")
              font.weight: Font.Bold
              pointSize: Style.fontSizeM
              color: Color.mOnSurface
            }
            NText {
              Layout.fillWidth: true
              elide: Text.ElideMiddle
              text: {
                var parts = [];
                var sid = mainInstance?.sessionId || "";
                parts.push(sid ? pluginApi?.tr("panel.sessionIdValue", { id: sid.slice(0, 8) }) : pluginApi?.tr("panel.noSession"));
                if (mainInstance?.lastModel) { parts.push(mainInstance.lastModel); }
                var wd = mainInstance?.workingDir || "";
                if (wd) { parts.push(pluginApi?.tr("panel.cwdValue", { path: wd })); }
                return parts.join(" · ");
              }
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }
          }

          NButton {
            text: pluginApi?.tr("panel.newSession")
            icon: "plus"
            onClicked: mainInstance?.newSession()
            enabled: !!mainInstance
          }
        }
      }

      // ----- Permission banner -----
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: bannerRow.implicitHeight + Style.marginS * 2
        color: root.tintOf(root.bannerColor(), 0.14)
        border.color: root.bannerColor()
        border.width: Style.borderS
        radius: Style.radiusM

        RowLayout {
          id: bannerRow
          anchors.fill: parent
          anchors.margins: Style.marginS
          spacing: Style.marginS

          NIcon {
            icon: root.dangerouslySkip || root.permissionMode === "bypassPermissions" ? "alert-triangle" : "shield"
            color: root.bannerColor()
          }
          NText {
            Layout.fillWidth: true
            text: root.bannerText() || ""
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            color: Color.mOnSurface
            pointSize: Style.fontSizeS
          }
          NText {
            text: root.permissionMode
            color: root.bannerColor()
            font.weight: Font.Bold
            pointSize: Style.fontSizeXS
          }
        }
      }

      // ----- Binary missing warning -----
      Rectangle {
        Layout.fillWidth: true
        visible: !!(mainInstance && mainInstance.binaryChecked && !mainInstance.binaryAvailable)
        Layout.preferredHeight: visible ? binaryHelp.implicitHeight + Style.marginS * 2 : 0
        color: Qt.rgba(0.9, 0.2, 0.2, 0.15)
        border.color: Color.mError
        radius: Style.radiusM
        NText {
          id: binaryHelp
          anchors.fill: parent
          anchors.margins: Style.marginS
          text: pluginApi?.tr("panel.acpNotFound")
          wrapMode: Text.WordWrap
          color: Color.mOnSurface
          pointSize: Style.fontSizeXS
        }
      }

      // ----- Conversation -----
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurfaceVariant
        radius: Style.radiusL
        clip: true

        NListView {
          id: list
          anchors.fill: parent
          anchors.leftMargin: Style.marginS
          anchors.rightMargin: Style.marginS
          anchors.topMargin: Style.marginS
          // Width of the scrollbar lane the delegates must NOT paint into.
          // The NListView scrollbar overlays the inside of the list, so any
          // delegate using list.availableWidth would otherwise be drawn under
          // the scrollbar thumb — clicks on a bottom-right widget would land
          // on the scrollbar instead of the widget. Trim delegate width by
          // exactly this amount (see `delegate.width` below).
          readonly property int _scrollbarLane: Math.round(12 * Style.uiScaleRatio)
          // Small static separation from the input row.
          anchors.bottomMargin: Style.marginS
          // The real tail-gap below the last bubble lives *inside* the list,
          // contributed by the last delegate via `MessageBubble.tailGap` —
          // see the `delegate` block below. That keeps the gap inside the
          // conversation container and scrolling with content.
          readonly property int _tailGap: Math.round(28 * Style.uiScaleRatio)
          spacing: Style.marginS
          model: mainInstance?.messages || []
          cacheBuffer: 400
          boundsBehavior: Flickable.StopAtBounds
          reserveScrollbarSpace: true
          interactive: true
          verticalPolicy: ScrollBar.AlwaysOn   // make the scrollbar a real, draggable control
          gradientColor: Color.mSurfaceVariant
          // Disable NListView's custom WheelHandler branch — its smooth-scroll animation
          // stalls on tall conversations and swallows wheel events. `1.0` reroutes wheel to
          // the stock ListView handler, which just works.
          wheelScrollMultiplier: 1.0

          // Auto-scroll that respects the user: stickBottom flips off when they scroll up.
          property bool stickBottom: true
          readonly property real _bottomThreshold: 32

          function scrollToEnd() {
            if (count <= 0) return;
            positionViewAtEnd();
          }

          function isAtBottom() {
            return (contentY + height) >= (contentHeight - _bottomThreshold);
          }

          onCountChanged: {
            if (stickBottom) { Qt.callLater(scrollToEnd); }
          }
          onContentHeightChanged: {
            // Last bubble growing mid-stream — follow it down if we're already at the bottom.
            if (stickBottom) { Qt.callLater(scrollToEnd); }
          }
          onMovingChanged: {
            // User finished a scroll gesture — lock/unlock auto-follow.
            if (!moving) { stickBottom = isAtBottom(); }
          }
          onFlickingChanged: {
            if (!flicking) { stickBottom = isAtBottom(); }
          }

          delegate: MessageBubble {
            // Reserve the scrollbar lane so the bubble (and its bottom-right
            // copy button) never sit under the scrollbar thumb.
            width: list.availableWidth - list._scrollbarLane
            entry: modelData
            pluginApi: root.pluginApi
            mainInstance: root.mainInstance
            // Only the final delegate grows itself, producing a scrollable
            // gap inside the conversation container below the last message.
            tailGap: index === list.count - 1 ? list._tailGap : 0
          }

          // Jump-to-bottom pill, appears only when auto-follow is off.
          Rectangle {
            visible: !list.stickBottom && list.count > 0
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: Style.marginS
            width: jumpRow.implicitWidth + Style.marginM * 2
            height: jumpRow.implicitHeight + Style.marginS * 2
            radius: height / 2
            color: Color.mPrimary
            opacity: jumpMouse.containsMouse ? 1.0 : 0.85
            z: 10

            RowLayout {
              id: jumpRow
              anchors.centerIn: parent
              spacing: Style.marginXS
              NIcon { icon: "arrow-down"; color: Color.mOnPrimary; pointSize: Style.fontSizeXS }
              NText { text: pluginApi?.tr("panel.jumpToLatest"); color: Color.mOnPrimary; pointSize: Style.fontSizeXS }
            }
            MouseArea {
              id: jumpMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { list.stickBottom = true; list.scrollToEnd(); }
            }
          }
        }
      }

      // Thin streaming indicator bar (shown while generating; actual text streams inline into the last bubble)
      Rectangle {
        Layout.fillWidth: true
        visible: !!(mainInstance && mainInstance.isGenerating)
        Layout.preferredHeight: visible ? 3 : 0
        color: "transparent"
        Rectangle {
          anchors.fill: parent
          color: Color.mPrimary
          opacity: 0.8
          radius: Style.marginXXS
          SequentialAnimation on opacity {
            running: parent.visible
            loops: Animation.Infinite
            NumberAnimation { from: 0.35; to: 1.0; duration: 650; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 1.0; to: 0.35; duration: 650; easing.type: Easing.InOutQuad }
          }
        }
      }

      // ----- Error strip -----
      Rectangle {
        Layout.fillWidth: true
        visible: !!(mainInstance && mainInstance.errorMessage !== "")
        Layout.preferredHeight: visible ? errText.implicitHeight + Style.marginS * 2 : 0
        color: Qt.rgba(0.9, 0.2, 0.2, 0.15)
        border.color: Color.mError
        radius: Style.radiusM
        NText {
          id: errText
          anchors.fill: parent
          anchors.margins: Style.marginS
          text: mainInstance?.errorMessage || ""
          wrapMode: Text.Wrap
          color: Color.mError
          pointSize: Style.fontSizeXS
        }
      }

      // ----- Input row -----
      // Multi-line editor: Enter submits, Shift+Enter inserts a newline, auto-grows up to
      // `maxInputHeight` then scrolls internally. Ctrl+Enter also submits for muscle-memory.
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        Rectangle {
          id: inputBox
          Layout.fillWidth: true
          readonly property int minInputHeight: Math.round(42 * Style.uiScaleRatio)
          readonly property int maxInputHeight: Math.round(200 * Style.uiScaleRatio)
          Layout.preferredHeight: Math.max(minInputHeight, Math.min(maxInputHeight, inputArea.contentHeight + Style.marginS * 2 + 4))
          radius: Style.radiusM
          color: Color.mSurface
          border.color: inputArea.activeFocus ? Color.mSecondary : Color.mOutline
          border.width: Style.borderS
          Behavior on border.color { ColorAnimation { duration: Style.animationFast } }

          // Slash-command autocomplete popup. Lives inside inputBox so it anchors
          // to the editor; positioned just above it and only visible on demand.
          Rectangle {
            id: slashMenu
            visible: root.slashMenuOpen && root.slashMenuMatches.length > 0
            width: parent.width
            // Row height × entries, clamped. Each row is one entry; ~32 px scaled.
            readonly property int rowHeight: Math.round(32 * Style.uiScaleRatio)
            readonly property int maxRows: 6
            height: Math.min(root.slashMenuMatches.length, maxRows) * rowHeight + Style.marginS * 2
            y: -height - Math.round(4 * Style.uiScaleRatio)
            radius: Style.radiusM
            color: Color.mSurface
            border.color: Color.mOutline
            border.width: Style.borderS
            z: 1000

            ListView {
              id: slashMenuList
              anchors.fill: parent
              anchors.margins: Style.marginS
              model: root.slashMenuMatches
              currentIndex: root.slashMenuIndex
              clip: true
              interactive: slashMenu.height >= slashMenu.maxRows * slashMenu.rowHeight
              boundsBehavior: Flickable.StopAtBounds
              onCurrentIndexChanged: {
                if (currentIndex !== root.slashMenuIndex && currentIndex >= 0) {
                  root.slashMenuIndex = currentIndex;
                }
              }

              delegate: Rectangle {
                width: slashMenuList.width
                height: slashMenu.rowHeight
                readonly property bool active: index === root.slashMenuIndex
                color: active ? Qt.alpha(Color.mSecondary, 0.18) : "transparent"
                radius: Style.radiusS

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Style.marginS
                  anchors.rightMargin: Style.marginS
                  spacing: Style.marginS

                  NText {
                    text: modelData.cmd
                    color: Color.mPrimary
                    pointSize: Style.fontSizeS
                    Layout.preferredWidth: Math.round(90 * Style.uiScaleRatio)
                  }
                  NText {
                    text: modelData.desc
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeXS
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  onEntered: root.slashMenuIndex = index
                  onClicked: {
                    root.slashMenuIndex = index;
                    root._applySlashCompletion();
                    inputArea.forceActiveFocus();
                  }
                }
              }
            }
          }

          Flickable {
            id: inputFlick
            anchors.fill: parent
            anchors.margins: Style.marginS
            contentWidth: width
            contentHeight: inputArea.contentHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: true

            // Keep caret in view while typing multi-line content.
            function ensureCaretVisible() {
              var r = inputArea.cursorRectangle;
              var bottom = r.y + r.height;
              if (bottom > contentY + height) { contentY = bottom - height; }
              else if (r.y < contentY) { contentY = r.y; }
            }

            ScrollBar.vertical: ScrollBar {
              policy: (inputFlick.contentHeight > inputFlick.height) ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
              width: Math.round(5 * Style.uiScaleRatio)
              contentItem: Rectangle {
                radius: width / 2
                color: Qt.alpha(Color.mOnSurfaceVariant, 0.7)
              }
            }

            TextArea {
              id: inputArea
              width: inputFlick.width
              wrapMode: TextEdit.Wrap
              selectByMouse: true
              persistentSelection: true
              placeholderText: pluginApi?.tr("panel.inputPlaceholder")
              placeholderTextColor: Qt.alpha(Color.mOnSurfaceVariant, 0.6)
              color: Color.mOnSurface
              background: null
              topPadding: 0
              bottomPadding: 0
              leftPadding: 0
              rightPadding: 0
              font.pointSize: Style.fontSizeS * Style.uiScaleRatio
              text: mainInstance?.inputText || ""
              onTextChanged: {
                if (mainInstance && mainInstance.inputText !== text) {
                  mainInstance.inputText = text;
                  mainInstance.saveState();
                }
                root._updateSlashMenu(text, cursorPosition);
              }
              onCursorRectangleChanged: inputFlick.ensureCaretVisible()
              onCursorPositionChanged: root._updateSlashMenu(text, cursorPosition)
              onActiveFocusChanged: { if (!activeFocus) { root.slashMenuOpen = false; } }

              Keys.onPressed: function (event) {
                // Slash-menu navigation takes priority over editor defaults.
                if (root.slashMenuOpen && root.slashMenuMatches.length > 0) {
                  if (event.key === Qt.Key_Down) {
                    root.slashMenuIndex = (root.slashMenuIndex + 1) % root.slashMenuMatches.length;
                    event.accepted = true; return;
                  }
                  if (event.key === Qt.Key_Up) {
                    root.slashMenuIndex = (root.slashMenuIndex - 1 + root.slashMenuMatches.length) % root.slashMenuMatches.length;
                    event.accepted = true; return;
                  }
                  if (event.key === Qt.Key_Escape) {
                    root.slashMenuOpen = false;
                    event.accepted = true; return;
                  }
                  if (event.key === Qt.Key_Tab) {
                    root._applySlashCompletion();
                    event.accepted = true; return;
                  }
                  // Enter while menu open: complete instead of submit (unless Shift).
                  if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                      && !(event.modifiers & Qt.ShiftModifier)) {
                    root._applySlashCompletion();
                    event.accepted = true; return;
                  }
                }

                // Submit: plain Enter or Ctrl+Enter. Shift+Enter → newline (default behavior).
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  if (event.modifiers & Qt.ShiftModifier) {
                    // let TextArea insert a newline
                    return;
                  }
                  root.submit();
                  event.accepted = true;
                }
              }
            }
          }
        }

        NButton {
          text: isGenerating ? (pluginApi?.tr("panel.stop")) : (pluginApi?.tr("panel.send"))
          icon: isGenerating ? "square" : "send"
          enabled: !!mainInstance && (mainInstance.binaryAvailable || isGenerating)
          onClicked: isGenerating ? mainInstance.stopGeneration() : root.submit()
          Layout.alignment: Qt.AlignBottom
        }
      }
    }
  }

  function submit() {
    if (!mainInstance) { return; }
    var t = inputArea.text;
    if (!t || t.trim() === "") { return; }
    var trimmed = t.trim();
    // Local slash command? Handle and bail without touching Claude.
    if (trimmed[0] === "/" && mainInstance.handleSlashCommand(trimmed)) {
      inputArea.text = "";
      mainInstance.inputText = "";
      mainInstance.inputCursor = 0;
      mainInstance.saveState();
      return;
    }
    mainInstance.sendMessage(trimmed);
    inputArea.text = "";
    mainInstance.inputText = "";
    mainInstance.inputCursor = 0;
    mainInstance.saveState();
  }

  Component.onCompleted: {
    Logger.i("ClaudeCode", "Panel ready");
  }

  onVisibleChanged: {
    if (visible) { Qt.callLater(function () { inputArea.forceActiveFocus(); }); }
  }

  // ====================================================================
  // ApprovalBtn — compact, uniformly-sized approve/deny pill used on tool_use bubbles.
  // Declared at root scope (not inside a RowLayout, where inline components fail to
  // register and silently nuke the delegate tree — which is why the list went empty).
  // ====================================================================
  component ApprovalBtn: Rectangle {
    id: btn
    property alias label: btnLbl.text
    property alias numeral: btnNum.text
    property string iconName: "check"
    property color accent: Color.mSecondary
    property string tooltip: ""
    signal clicked

    readonly property int _minW: Math.round(88 * Style.uiScaleRatio)
    Layout.preferredHeight: btnRow.implicitHeight + Style.marginXS * 2
    Layout.minimumWidth: _minW
    Layout.preferredWidth: btnRow.implicitWidth + Style.marginS * 2
    Layout.fillWidth: true
    radius: Style.radiusS
    color: btnMouse.containsMouse ? Qt.alpha(accent, 0.30) : Qt.alpha(accent, 0.16)
    border.color: accent
    border.width: Style.borderS
    Behavior on color { ColorAnimation { duration: Style.animationFast } }

    RowLayout {
      id: btnRow
      anchors.centerIn: parent
      spacing: Style.marginXXS
      NText {
        id: btnNum
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
        font.family: "monospace"
      }
      NIcon { icon: btn.iconName; color: btn.accent; pointSize: Style.fontSizeXS }
      NText {
        id: btnLbl
        color: Color.mOnSurface
        font.weight: Font.Medium
        pointSize: Style.fontSizeXS
        elide: Text.ElideRight
      }
    }

    ToolTip.visible: btnMouse.containsMouse && btn.tooltip !== ""
    ToolTip.text: btn.tooltip
    ToolTip.delay: 500

    MouseArea {
      id: btnMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.clicked()
    }
  }

  // ====================================================================
  // ClaudeLogo — real Anthropic Claude mark, recolored to match the theme.
  // The SVG ships white (`fill="#ffffff"`); MultiEffect.colorization recolors it in-place.
  // ====================================================================
  component ClaudeLogo: Item {
    id: logoRoot
    property color tint: Color.mPrimary

    implicitWidth: 16 * Style.uiScaleRatio
    implicitHeight: 16 * Style.uiScaleRatio

    // Rasterize the SVG once at a high fixed resolution. Qt will downscale that pixmap
    // to the actual on-screen size with mipmap + smooth filtering. Without this, small
    // sizes (~14px bubble header) would rasterize the SVG at 14px and look chunky.
    readonly property int _rasterPx: 256

    Image {
      id: logoImage
      anchors.fill: parent
      source: Qt.resolvedUrl("assets/claude.svg")
      sourceSize.width: logoRoot._rasterPx
      sourceSize.height: logoRoot._rasterPx
      fillMode: Image.PreserveAspectFit
      smooth: true
      mipmap: true
      antialiasing: true
      // Tint via layer + MultiEffect. Pin the layer texture to the same high resolution
      // or the effect would re-sample the Image at the item's tiny display size.
      layer.enabled: true
      layer.textureSize: Qt.size(logoRoot._rasterPx, logoRoot._rasterPx)
      layer.smooth: true
      layer.mipmap: true
      layer.effect: MultiEffect {
        colorization: 1.0
        colorizationColor: logoRoot.tint
      }
    }
  }

  // ====================================================================
  // MessageBubble — rich per-message rendering with markdown + copy button
  // ====================================================================
  component MessageBubble: Item {
    id: bubbleRoot
    property var entry
    property var pluginApi
    property var mainInstance
    // Extra empty space the delegate adds *below* its bubble. Used to give the
    // last message a scrollable tail-gap inside the conversation container —
    // NListView shadows both `footer:` and content `bottomMargin`, so the
    // delegate has to grow itself.
    property real tailGap: 0

    implicitHeight: bubble.implicitHeight + tailGap

    // Bubble fill. Noctalia doesn't expose Material3 `*Container` tokens, so for the
    // "soft accent" bubbles (user / tool_use) we mix the accent colour with the surface
    // manually — otherwise they fall through to QML's undefined-color default (white).
    function bubbleColor() {
      if (!entry) return Color.mSurface;
      if (entry.role === "user")       { return Qt.rgba(Color.mPrimary.r,   Color.mPrimary.g,   Color.mPrimary.b,   0.14); }
      if (entry.kind === "tool_use")   { return Qt.rgba(Color.mSecondary.r, Color.mSecondary.g, Color.mSecondary.b, 0.12); }
      if (entry.kind === "thinking")   { return Qt.rgba(Color.mTertiary.r,  Color.mTertiary.g,  Color.mTertiary.b,  0.10); }
      if (entry.role === "tool")       { return Color.mSurface; }
      return Color.mSurface;
    }

    function borderColor() {
      if (!entry) return "transparent";
      if (entry.role === "user")     return Qt.alpha(Color.mPrimary,   0.45);
      if (entry.kind === "tool_use") return Qt.alpha(Color.mSecondary, 0.45);
      if (entry.kind === "thinking") return Qt.alpha(Color.mTertiary,  0.35);
      if (entry.role === "tool" && entry.meta && entry.meta.isError) return Qt.alpha(Color.mError, 0.6);
      return Qt.alpha(Color.mOutline, 0.8);
    }

    function headerIcon() {
      if (!entry) return "circle";
      if (entry.role === "user") return "user";
      if (entry.kind === "tool_use") return "tool";
      if (entry.kind === "tool_result") return "circle-check";
      if (entry.kind === "thinking") return "brain";
      return "sparkles";
    }

    function headerIconColor() {
      if (!entry) return Color.mOnSurface;
      if (entry.kind === "tool_use") {
        var c = entry.meta ? entry.meta.classification : "safe";
        if (c === "exec") return Color.mError;
        if (c === "write") return Color.mSecondary;
        if (c === "network") return Color.mTertiary;
      }
      if (entry.role === "tool" && entry.meta && entry.meta.isError) return Color.mError;
      return Color.mOnSurface;
    }

    function headerLabel() {
      if (!entry) return "";
      if (entry.role === "user") return "You";
      if (entry.role === "tool") return pluginApi?.tr("panel.toolResult");
      if (entry.kind === "tool_use") return (pluginApi?.tr("panel.toolUse")) + " · " + (entry.meta ? entry.meta.toolName : "");
      if (entry.kind === "thinking") return "Thinking";
      return "Claude";
    }

    // Preformatted (monospace, no markdown) for tool I/O; markdown everywhere else.
    function isCodeLike() {
      if (!entry) return false;
      return entry.kind === "tool_use" || entry.kind === "tool_result";
    }

    Rectangle {
      id: bubble
      width: parent.width
      radius: Style.radiusM
      color: bubbleRoot.bubbleColor()
      border.color: bubbleRoot.borderColor()
      border.width: Style.borderS
      implicitHeight: inner.implicitHeight + Style.marginS * 2

      // Hover-reveal for the floating copy button. HoverHandler is preferred over
      // MouseArea here because it doesn't intercept clicks/selection on the body.
      HoverHandler {
        id: bubbleHover
      }

      ColumnLayout {
        id: inner
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: Style.marginXS

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginXS

          // Real Claude logo on plain assistant replies; fall back to themed glyphs for
          // tool_use / thinking / user / tool_result so each bubble still reads at a glance.
          Loader {
            readonly property bool useLogo: entry && entry.role === "assistant" && entry.kind !== "tool_use" && entry.kind !== "thinking"
            Layout.preferredWidth: Style.fontSizeS * Style.uiScaleRatio * 1.5
            Layout.preferredHeight: Style.fontSizeS * Style.uiScaleRatio * 1.5
            sourceComponent: useLogo ? logoComp : glyphComp

            Component {
              id: logoComp
              ClaudeLogo { tint: Color.mPrimary }
            }
            Component {
              id: glyphComp
              NIcon {
                icon: bubbleRoot.headerIcon()
                pointSize: Style.fontSizeS
                color: bubbleRoot.headerIconColor()
              }
            }
          }
          NText {
            text: bubbleRoot.headerLabel()
            font.weight: Font.Medium
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
          }
          Item { Layout.fillWidth: true }
          NText {
            visible: !!(entry && entry.timestamp)
            text: entry && entry.timestamp ? entry.timestamp.slice(11, 19) : ""
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            opacity: 0.6
          }
        }

        // ---------- Body: block-aware rendering ----------
        // Tool I/O renders as one preformatted block; assistant prose is parsed
        // into alternating text + code blocks so each gets the right treatment.
        // `TextEdit` is used everywhere instead of NText so selection works
        // natively (the previous transparent-overlay trick made selected text
        // unreadable). Markdown is rendered by Qt itself once streaming ends.
        Repeater {
          id: bodyBlocks
          // Three cases:
          // 1. Tool I/O: one preformatted block, never markdown.
          // 2. Streaming prose: one plain-text block — re-parsing on every
          //    chunk would tear down/recreate all delegates per token.
          // 3. Finalized prose: parse into text + code blocks.
          model: {
            if (bubbleRoot.isCodeLike()) {
              return [{ kind: "tool", text: (entry && entry.text) || "" }];
            }
            if (entry && entry.streaming === true) {
              var t = (!entry.text || entry.text === "") ? "_…_" : entry.text;
              return [{ kind: "text", text: t }];
            }
            return Logic.parseMarkdownBlocks((entry && entry.text) || "");
          }

          // ----- Prose block (or plain tool output): selectable, markdown after stream end
          delegate: Loader {
            Layout.fillWidth: true
            Layout.maximumWidth: bubble.width - Style.marginS * 2
            sourceComponent: modelData.kind === "code" ? codeBlockComp : textBlockComp
            property var blockData: modelData
          }
        }

        Component {
          id: textBlockComp
          TextEdit {
            text: blockData.text || ""
            readOnly: true
            selectByMouse: true
            persistentSelection: true
            wrapMode: TextEdit.WordWrap
            // PlainText while streaming; MarkdownText (or PlainText for tool I/O)
            // once finalized so we don't keep re-parsing partial markdown.
            textFormat: {
              if (blockData.kind === "tool") return TextEdit.PlainText;
              if (entry && entry.streaming === true) return TextEdit.PlainText;
              return TextEdit.MarkdownText;
            }
            color: Color.mOnSurface
            font.pointSize: Style.fontSizeS * Style.uiScaleRatio
            font.family: blockData.kind === "tool"
                           ? "monospace"
                           : (Settings.data.ui.fontDefault || "sans-serif")
            selectionColor: Qt.alpha(Color.mPrimary, 0.45)
            selectedTextColor: Color.mOnPrimary
            onLinkActivated: function (url) { Qt.openUrlExternally(url); }
            // Render-as-rich URLs; passes Qt's safety check.
            HoverHandler {
              cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
            }
          }
        }

        // ----- Fenced code block: dark slab, monospace, language tag, copy button
        Component {
          id: codeBlockComp
          Rectangle {
            id: codeSlab
            implicitHeight: codeCol.implicitHeight + Style.marginS * 2
            color: Qt.alpha(Color.mShadow, 0.7)
            border.color: Qt.alpha(Color.mOutline, 0.55)
            border.width: Style.borderS
            radius: Style.radiusS

            ColumnLayout {
              id: codeCol
              anchors.fill: parent
              anchors.margins: Style.marginS
              spacing: Style.marginXS

              // Header: language tag + copy button. Both are Layout-managed
              // so they collapse cleanly on narrow panels.
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                  text: (blockData.lang && blockData.lang !== "") ? blockData.lang : "code"
                  pointSize: Style.fontSizeXS
                  font.weight: Font.DemiBold
                  font.family: "monospace"
                  color: Color.mOnSurfaceVariant
                  opacity: 0.85
                }
                Item { Layout.fillWidth: true }

                Rectangle {
                  id: codeCopy
                  property bool flashed: false
                  implicitWidth: codeCopyRow.implicitWidth + Style.marginS * 2
                  implicitHeight: codeCopyRow.implicitHeight + Style.marginXXS * 2
                  radius: height / 2
                  color: codeCopyArea.containsMouse
                           ? Color.mSecondary
                           : Qt.alpha(Color.mSurface, 0.55)
                  border.color: Qt.alpha(Color.mOutline, 0.6)
                  border.width: Style.borderS
                  Behavior on color { ColorAnimation { duration: Style.animationFast } }

                  RowLayout {
                    id: codeCopyRow
                    anchors.centerIn: parent
                    spacing: Style.marginXXS
                    NIcon {
                      icon: codeCopy.flashed ? "check" : "copy"
                      pointSize: Style.fontSizeXS
                      color: codeCopyArea.containsMouse ? Color.mOnSecondary : Color.mOnSurfaceVariant
                    }
                    NText {
                      text: codeCopy.flashed
                              ? pluginApi?.tr("panel.copied")
                              : pluginApi?.tr("panel.copy")
                      pointSize: Style.fontSizeXS
                      color: codeCopyArea.containsMouse ? Color.mOnSecondary : Color.mOnSurfaceVariant
                    }
                  }

                  Timer {
                    id: codeCopyFlash
                    interval: 1200
                    onTriggered: codeCopy.flashed = false
                  }

                  MouseArea {
                    id: codeCopyArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (bubbleRoot.mainInstance) {
                        bubbleRoot.mainInstance.copyToClipboard(blockData.text || "");
                        codeCopy.flashed = true;
                        codeCopyFlash.restart();
                      }
                    }
                  }
                }
              }

              // Code body. TextEdit gives native selection + correct copy text
              // (without the surrounding ```fence``` markers).
              TextEdit {
                Layout.fillWidth: true
                text: blockData.text || ""
                readOnly: true
                selectByMouse: true
                persistentSelection: true
                wrapMode: TextEdit.NoWrap
                textFormat: TextEdit.PlainText
                font.family: "monospace"
                font.pointSize: Style.fontSizeXS * Style.uiScaleRatio
                color: Color.mOnSurface
                selectionColor: Qt.alpha(Color.mPrimary, 0.45)
                selectedTextColor: Color.mOnPrimary
                // Allow horizontal pan with the mouse wheel + shift, since long
                // lines are common in code.
                clip: true
              }
            }
          }
        }

        // Blinking caret while this bubble is streaming — its own short row below the body
        Item {
          id: caretRow
          Layout.fillWidth: true
          Layout.preferredHeight: 14
          visible: !!(entry && entry.streaming === true)
          Rectangle {
            width: 8
            height: 14
            color: Color.mPrimary
            radius: Style.marginXXXS
            anchors.left: parent ? parent.left : undefined
            SequentialAnimation on opacity {
              // `parent` briefly goes null during ListView delegate recycling; guard.
              running: caretRow ? caretRow.visible : false
              loops: Animation.Infinite
              NumberAnimation { from: 1.0; to: 0.1; duration: 500 }
              NumberAnimation { from: 0.1; to: 1.0; duration: 500 }
            }
          }
        }

        // Tool-use details (arg preview in mono) — only when entry has structured input
        Rectangle {
          Layout.fillWidth: true
          visible: !!(entry && entry.kind === "tool_use" && entry.meta && entry.meta.input && Object.keys(entry.meta.input).length > 0)
          Layout.preferredHeight: visible ? (argsText.implicitHeight + Style.marginXS * 2) : 0
          color: Qt.alpha(Color.mShadow, 0.55)   // dark slab that actually contrasts with mOnSurface text
          border.color: Qt.alpha(Color.mOutline, 0.6)
          border.width: Style.borderS
          radius: Style.radiusS

          NText {
            id: argsText
            anchors.fill: parent
            anchors.margins: Style.marginXS
            text: {
              if (!entry || entry.kind !== "tool_use" || !entry.meta) return "";
              try { return JSON.stringify(entry.meta.input, null, 2); }
              catch (e) { return ""; }
            }
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            font.family: "monospace"
            pointSize: Style.fontSizeXS
            color: Color.mOnSurface
          }
        }

        // Inline approve / allow-all / deny row — shown only when ACP has asked for
        // permission on this tool call (entry.meta.permissionPending === true). Clicking
        // a button sends a real `session/request_permission` response back to the agent,
        // which then either runs or aborts the tool. No more after-the-fact hints.
        Item {
          id: approvalRow
          Layout.fillWidth: true
          Layout.preferredHeight: approvalVisible ? approvalCol.implicitHeight : 0

          readonly property string classification: entry && entry.meta ? (entry.meta.classification || "safe") : "safe"
          readonly property string decision: entry && entry.meta ? (entry.meta.approval || "") : ""
          readonly property bool permissionPending: entry && entry.meta ? (entry.meta.permissionPending === true) : false
          readonly property bool approvalVisible:
              entry && entry.kind === "tool_use" &&
              permissionPending &&
              decision === ""

          visible: approvalVisible

          ColumnLayout {
            id: approvalCol
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Style.marginXS

            NText {
              Layout.fillWidth: true
              Layout.topMargin: Style.marginXS
              text: {
                var verb = "this action";
                if (approvalRow.classification === "exec") verb = "running this command";
                else if (approvalRow.classification === "write") verb = "this file edit";
                else if (approvalRow.classification === "network") verb = "this network call";
                return "Approve " + verb + "?";
              }
              color: Color.mOnSurface
              font.weight: Font.Medium
              pointSize: Style.fontSizeXS
              wrapMode: Text.WordWrap
              elide: Text.ElideNone
            }

            // Three compact buttons. Min-widths prevent the "Allow all" button from
            // overflowing on narrow panels; labels are kept short and the long form is
            // shown as a tooltip on hover instead.
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginXS

              ApprovalBtn {
                numeral: "1."
                iconName: "check"
                accent: Color.mSecondary
                label: pluginApi?.tr("panel.permitYes")
                tooltip: {
                  if (approvalRow.classification === "exec")    return pluginApi?.tr("panel.tipYesExec");
                  if (approvalRow.classification === "network") return pluginApi?.tr("panel.tipYesNetwork");
                  return pluginApi?.tr("panel.tipYesDefault");
                }
                onClicked: {
                  if (bubbleRoot.mainInstance && entry) {
                    bubbleRoot.mainInstance.approveOnce(entry.id);
                  }
                }
              }

              ApprovalBtn {
                numeral: "2."
                iconName: "circle-check"
                accent: Color.mTertiary
                label: pluginApi?.tr("panel.permitAllowAll")
                tooltip: {
                  if (approvalRow.classification === "write")   return pluginApi?.tr("panel.tipAllowAllWrite");
                  if (approvalRow.classification === "exec")    return pluginApi?.tr("panel.tipAllowAllExec");
                  if (approvalRow.classification === "network") return pluginApi?.tr("panel.tipAllowAllNetwork");
                  return pluginApi?.tr("panel.tipAllowAllDefault");
                }
                onClicked: {
                  if (bubbleRoot.mainInstance && entry) {
                    bubbleRoot.mainInstance.approveAllForSession(entry.id, approvalRow.classification);
                  }
                }
              }

              ApprovalBtn {
                numeral: "3."
                iconName: "x"
                accent: Color.mError
                label: pluginApi?.tr("panel.permitNo")
                tooltip: pluginApi?.tr("panel.tipNo")
                onClicked: {
                  if (bubbleRoot.mainInstance && entry) {
                    bubbleRoot.mainInstance.denyToolUse(entry.id);
                  }
                }
              }
            }
          }
        }

        // Persistent badge after a decision has been recorded.
        Rectangle {
          Layout.fillWidth: true
          visible: !!(entry && entry.kind === "tool_use" && entry.meta && entry.meta.approval && entry.meta.approval !== "")
          Layout.preferredHeight: visible ? decisionLbl.implicitHeight + Style.marginXS * 2 : 0
          radius: Style.radiusS
          color: "transparent"

          NText {
            id: decisionLbl
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: {
              if (!entry || !entry.meta) return "";
              var d = entry.meta.approval;
              var tool = entry.meta.toolName || "this tool";
              if (d === "allow")      return "✓ Approved — " + tool + " running";
              if (d === "allow-all")  return "✓✓ Approved (always) — all further " + tool + " calls allowed this session";
              if (d === "deny")       return "✗ Denied";
              if (d === "deny-all")   return "✗✗ Denied (always) — further " + tool + " calls blocked this session";
              if (d === "cancelled")  return "… Cancelled";
              return "";
            }
            color: {
              if (!entry || !entry.meta) return Color.mOnSurface;
              if (entry.meta.approval === "deny") return Color.mError;
              return Color.mSecondary;
            }
            pointSize: Style.fontSizeXS
            font.weight: Font.Medium
            elide: Text.ElideNone
          }
        }
      }

      // Floating copy button — bottom-right corner of the bubble. Hover-revealed
      // so it doesn't compete with the body. Pill-shaped with icon + label so it
      // reads unambiguously as an interactive control.
      Rectangle {
        id: copyBtn
        visible: !!(entry && entry.text && entry.text !== "")
        opacity: bubbleHover.hovered || copyMouse.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Style.animationFast } }
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Style.marginXS
        anchors.bottomMargin: Style.marginXS
        implicitWidth: copyRow.implicitWidth + Style.marginS * 2
        implicitHeight: copyRow.implicitHeight + Style.marginXS * 2
        width: implicitWidth
        height: implicitHeight
        radius: height / 2
        color: copyMouse.pressed
                 ? Qt.darker(Color.mSecondary, 1.1)
                 : copyMouse.containsMouse
                   ? Color.mSecondary
                   : Qt.alpha(Color.mSurface, 0.92)
        border.color: copyMouse.containsMouse
                        ? Color.mSecondary
                        : Qt.alpha(Color.mOutline, 0.7)
        border.width: Style.borderS
        Behavior on color { ColorAnimation { duration: Style.animationFast } }

        readonly property bool _justCopied: copyBtn._copyFlash
        property bool _copyFlash: false

        RowLayout {
          id: copyRow
          anchors.centerIn: parent
          spacing: Style.marginXXS

          NIcon {
            icon: copyBtn._copyFlash ? "check" : "copy"
            pointSize: Style.fontSizeXS
            color: copyMouse.containsMouse ? Color.mOnSecondary : Color.mOnSurfaceVariant
          }
          NText {
            text: copyBtn._copyFlash
                    ? pluginApi?.tr("panel.copied")
                    : pluginApi?.tr("panel.copy")
            pointSize: Style.fontSizeXS
            font.weight: Font.Medium
            color: copyMouse.containsMouse ? Color.mOnSecondary : Color.mOnSurfaceVariant
          }
        }

        Timer {
          id: copyFlashTimer
          interval: 1200
          onTriggered: copyBtn._copyFlash = false
        }

        MouseArea {
          id: copyMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (bubbleRoot.mainInstance && entry && entry.text) {
              bubbleRoot.mainInstance.copyToClipboard(entry.text);
              copyBtn._copyFlash = true;
              copyFlashTimer.restart();
            }
          }
        }
      }
    }
  }
}
