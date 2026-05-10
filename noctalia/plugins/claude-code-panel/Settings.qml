import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

// Settings.qml — overhauled layout.
//
// Structure: vertical tab rail on the left + per-tab content on the right.
// Each tab groups related controls into card-style Sections so the eye can
// chunk them. Danger Zone is its own tab with a red accent so it can never
// be flipped accidentally while scrolling.
Item {
  id: root
  implicitWidth: 720
  implicitHeight: 560
  property var pluginApi: null

  readonly property var cs: pluginApi?.pluginSettings?.claude || ({})

  // ---- Save indicator state -------------------------------------------------
  // Each effectful set()/setTop() flips `_saveBlinking` true and starts the
  // fade-out timer. Two guards prevent spurious flashes:
  //   `_initialized`   blocks the burst of onValueChanged / onToggled signals
  //                    that QtQuick fires while bindings settle on first paint.
  //   value-equality   `set()` / `setTop()` only count as a change when the
  //                    new value differs from the current one — so re-asserting
  //                    the same value (during binding setup, after a host
  //                    Apply, etc.) doesn't trigger a flash.
  property bool _saveBlinking: false
  property bool _initialized: false
  Component.onCompleted: Qt.callLater(function () { root._initialized = true; })

  Timer {
    id: _saveTimer
    interval: 1400
    onTriggered: root._saveBlinking = false
  }
  function _flashSaved() {
    if (!_initialized) { return; }
    _saveBlinking = true;
    _saveTimer.restart();
  }

  // Loose equality check that handles arrays + objects without bringing in a
  // deep-equal helper. Sufficient for the simple value shapes in claudeSettings.
  function _same(a, b) {
    if (a === b) { return true; }
    if (Array.isArray(a) && Array.isArray(b)) {
      if (a.length !== b.length) { return false; }
      for (var i = 0; i < a.length; i++) { if (a[i] !== b[i]) { return false; } }
      return true;
    }
    return false;
  }

  function set(key, value) {
    if (!pluginApi) { return; }
    if (!pluginApi.pluginSettings.claude) { pluginApi.pluginSettings.claude = {}; }
    if (_same(pluginApi.pluginSettings.claude[key], value)) { return; }
    pluginApi.pluginSettings.claude[key] = value;
    pluginApi.saveSettings();
    _flashSaved();
  }

  function setTop(key, value) {
    if (!pluginApi) { return; }
    if (_same(pluginApi.pluginSettings[key], value)) { return; }
    pluginApi.pluginSettings[key] = value;
    pluginApi.saveSettings();
    _flashSaved();
  }

  function parseList(raw) {
    if (!raw) { return []; }
    return String(raw).split(/[,\n]/).map(function (s) { return s.trim(); }).filter(function (s) { return s !== ""; });
  }

  // ---- Permission-mode visual state -----------------------------------------
  // Color + label for the small status pill next to the dropdown. Reading the
  // pill color is faster than parsing the dropdown text.
  function _modeColor(m) {
    if (cs.dangerouslySkipPermissions === true || m === "bypassPermissions") return Color.mError;
    if (m === "acceptEdits") return Color.mSecondary;
    if (m === "plan")        return Color.mTertiary;
    return Color.mPrimary;
  }
  function _modeBadge(m) {
    if (cs.dangerouslySkipPermissions === true || m === "bypassPermissions") {
      return pluginApi?.tr("settings.modeBadgeBypass") ;
    }
    if (m === "acceptEdits") return pluginApi?.tr("settings.modeBadgeAccept") ;
    if (m === "plan")        return pluginApi?.tr("settings.modeBadgePlan")   ;
    return pluginApi?.tr("settings.modeBadgeDefault") ;
  }

  // Tab catalog. Add a tab here and a corresponding StackLayout entry below.
  readonly property var _tabs: [
    { key: "general",     icon: "settings",     label: pluginApi?.tr("settings.tabGeneral")             },
    { key: "permissions", icon: "shield",       label: pluginApi?.tr("settings.tabPermissions")     },
    { key: "session",     icon: "cpu",          label: pluginApi?.tr("settings.tabSession")     },
    { key: "mcp",         icon: "plug",         label: pluginApi?.tr("settings.tabMcp")                     },
    { key: "panel",       icon: "layout",       label: pluginApi?.tr("settings.tabPanel")                 },
    { key: "danger",      icon: "alert-circle", label: pluginApi?.tr("settings.tabDanger")          }
  ]
  property int currentTab: 0

  // Reusable Section card (heading + content slot).
  // The default property alias points at the inner ColumnLayout's data so any
  // children declared inside `Section { ... }` are laid out vertically with
  // proper spacing — not stacked at (0,0) like a bare Item child list.
  component Section: ColumnLayout {
    id: section
    property string title: ""
    property color accent: Color.mOutline
    default property alias _content: contentCol.data

    Layout.fillWidth: true
    spacing: Style.marginXS

    NText {
      visible: section.title !== ""
      text: section.title
      pointSize: Style.fontSizeXS
      font.weight: Font.DemiBold
      color: Color.mOnSurfaceVariant
      Layout.leftMargin: Style.marginXS
    }
    Rectangle {
      Layout.fillWidth: true
      radius: Style.radiusM
      color: Qt.alpha(Color.mSurface, 0.6)
      border.color: section.accent
      border.width: Style.borderS
      implicitHeight: contentCol.implicitHeight + Style.marginM * 2

      ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM
      }
    }
  }

  // ============================================================================
  // Layout
  // ============================================================================
  RowLayout {
    anchors.fill: parent
    spacing: 0

    // ---- Tab rail (left) ----
    Rectangle {
      Layout.fillHeight: true
      Layout.preferredWidth: Math.round(180 * Style.uiScaleRatio)
      color: Qt.alpha(Color.mSurfaceVariant, 0.5)
      border.color: Color.mOutline
      border.width: 0
      radius: 0

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: Style.marginXS

        Repeater {
          model: root._tabs
          delegate: Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(38 * Style.uiScaleRatio)
            radius: Style.radiusM
            readonly property bool active: index === root.currentTab
            readonly property bool danger: modelData.key === "danger"
            color: active
                     ? (danger ? Qt.alpha(Color.mError, 0.18) : Qt.alpha(Color.mPrimary, 0.16))
                     : (tabHover.containsMouse ? Color.mHover : "transparent")
            border.color: active ? (danger ? Color.mError : Color.mPrimary) : "transparent"
            border.width: active ? Style.borderS : 0
            Behavior on color { ColorAnimation { duration: Style.animationFast } }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.marginM
              anchors.rightMargin: Style.marginS
              spacing: Style.marginS

              NIcon {
                icon: modelData.icon
                pointSize: Style.fontSizeS
                color: parent.parent.active
                         ? (parent.parent.danger ? Color.mError : Color.mPrimary)
                         : Color.mOnSurfaceVariant
              }
              NText {
                text: modelData.label
                pointSize: Style.fontSizeS
                font.weight: parent.parent.active ? Font.DemiBold : Font.Normal
                color: parent.parent.danger && !parent.parent.active
                         ? Color.mError
                         : Color.mOnSurface
                Layout.fillWidth: true
                elide: Text.ElideRight
              }
            }

            MouseArea {
              id: tabHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.currentTab = index
            }
          }
        }

        Item { Layout.fillHeight: true }

        // Reset button at the bottom of the rail.
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.round(34 * Style.uiScaleRatio)
          radius: Style.radiusM
          color: resetHover.containsMouse ? Qt.alpha(Color.mError, 0.12) : "transparent"
          border.color: Qt.alpha(Color.mError, 0.6)
          border.width: Style.borderS

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginM
            spacing: Style.marginS
            NIcon { icon: "rotate-ccw"; pointSize: Style.fontSizeXS; color: Color.mError }
            NText {
              text: pluginApi?.tr("settings.resetDefaults") 
              pointSize: Style.fontSizeXS
              color: Color.mError
              Layout.fillWidth: true
              elide: Text.ElideRight
            }
          }
          MouseArea {
            id: resetHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: resetConfirm.open()
          }
        }
      }
    }

    // ---- Tab content (right) ----
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      NScrollView {
        id: scroller
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

      StackLayout {
        width: scroller.availableWidth
        currentIndex: root.currentTab

        // ============== GENERAL ==============
        ColumnLayout {
          spacing: Style.marginM
          Layout.margins: Style.marginM

          Section {
            title: pluginApi?.tr("settings.groupBinary") 
            NTextInput {
              Layout.fillWidth: true
              label: pluginApi?.tr("settings.binary")
              text: cs.binary || "claude"
              onEditingFinished: set("binary", text)
            }
          }

          Section {
            title: pluginApi?.tr("settings.groupWorkspace") 
            NTextInput {
              Layout.fillWidth: true
              label: pluginApi?.tr("settings.workingDir")
              description: pluginApi?.tr("settings.workingDirHelp")
              text: cs.workingDir 
              placeholderText: "/home/you/project"
              onEditingFinished: set("workingDir", text)
            }
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginXS
              NLabel {
                label: pluginApi?.tr("settings.additionalDirs")
                description: pluginApi?.tr("settings.additionalDirsHelp")
              }
              TextArea {
                id: addlDirsArea
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(72 * Style.uiScaleRatio)
                text: (cs.additionalDirs || []).join("\n")
                placeholderText: "/home/you/notes\n/tmp/scratch"
                // QtQuick.Controls.TextArea has no editingFinished — commit on
                // focus loss instead. Without this, multi-line edits silently
                // never save.
                onActiveFocusChanged: {
                  if (!activeFocus) { set("additionalDirs", parseList(text)); }
                }
              }
            }
          }

          NText {
            text: pluginApi?.tr("settings.restartHint") 
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXS
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.leftMargin: Style.marginXS
            opacity: 0.8
          }
        }

        // ============== PERMISSIONS ==============
        ColumnLayout {
          spacing: Style.marginM
          Layout.margins: Style.marginM

          Section {
            title: pluginApi?.tr("settings.permissionMode")

            // Mode picker + live status pill on the same row.
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              NComboBox {
                Layout.fillWidth: true
                model: [
                  { key: "default",           name: pluginApi?.tr("settings.permModeDefault") },
                  { key: "acceptEdits",       name: pluginApi?.tr("settings.permModeAccept") },
                  { key: "plan",              name: pluginApi?.tr("settings.permModePlan") },
                  { key: "bypassPermissions", name: pluginApi?.tr("settings.permModeBypass") }
                ]
                currentKey: cs.permissionMode || "default"
                onSelected: key => {
                  if (key === "bypassPermissions" && (cs.requireConfirmBypass !== false)) {
                    bypassConfirm.forSkip = false;
                    bypassConfirm.open();
                  } else {
                    set("permissionMode", key);
                  }
                }
              }

              Rectangle {
                Layout.preferredHeight: Math.round(28 * Style.uiScaleRatio)
                Layout.preferredWidth: badgeText.implicitWidth + Style.marginM * 2
                radius: height / 2
                color: Qt.alpha(root._modeColor(cs.permissionMode || "default"), 0.18)
                border.color: root._modeColor(cs.permissionMode || "default")
                border.width: Style.borderS

                NText {
                  id: badgeText
                  anchors.centerIn: parent
                  text: root._modeBadge(cs.permissionMode || "default")
                  pointSize: Style.fontSizeXS
                  font.weight: Font.DemiBold
                  color: root._modeColor(cs.permissionMode || "default")
                }
              }
            }
          }

          Section {
            title: pluginApi?.tr("settings.groupTools") 
            NTextInput {
              Layout.fillWidth: true
              label: pluginApi?.tr("settings.allowedTools")
              description: pluginApi?.tr("settings.allowedToolsHelp")
              text: (cs.allowedTools || []).join(",")
              placeholderText: "Read,Edit,Bash(git:*),WebFetch"
              onEditingFinished: set("allowedTools", parseList(text))
            }
            NTextInput {
              Layout.fillWidth: true
              label: pluginApi?.tr("settings.disallowedTools")
              text: (cs.disallowedTools || []).join(",")
              placeholderText: "Bash(rm:*),WebFetch"
              onEditingFinished: set("disallowedTools", parseList(text))
            }
          }
        }

        // ============== SESSION & MODEL ==============
        ColumnLayout {
          spacing: Style.marginM
          Layout.margins: Style.marginM

          Section {
            title: pluginApi?.tr("settings.groupModel") 

            // Side-by-side primary + fallback to keep the relationship obvious.
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginM
              NTextInput {
                Layout.fillWidth: true
                label: pluginApi?.tr("settings.model")
                description: pluginApi?.tr("settings.modelHelp")
                text: cs.model 
                placeholderText: "claude-opus-4-7"
                onEditingFinished: set("model", text)
              }
              NTextInput {
                Layout.fillWidth: true
                label: pluginApi?.tr("settings.fallbackModel")
                text: cs.fallbackModel 
                placeholderText: "claude-sonnet-4-6"
                onEditingFinished: set("fallbackModel", text)
              }
            }
          }

          Section {
            title: pluginApi?.tr("settings.groupSession") 
            NCheckbox {
              Layout.fillWidth: true
              label: pluginApi?.tr("settings.autoResume")
              checked: cs.autoResume !== false
              onToggled: checked => set("autoResume", checked)
            }
            NSpinBox {
              Layout.fillWidth: true
              label: pluginApi?.tr("settings.maxTurns")
              from: 0
              to: 9999
              stepSize: 1
              value: cs.maxTurns || 0
              onValueChanged: set("maxTurns", value)
            }
            NCheckbox {
              Layout.fillWidth: true
              label: pluginApi?.tr("settings.includePartialMessages")
              checked: cs.includePartialMessages === true
              onToggled: checked => set("includePartialMessages", checked)
            }
          }

          Section {
            title: pluginApi?.tr("settings.groupSystemPrompt") 
            NCheckbox {
              Layout.fillWidth: true
              label: pluginApi?.tr("settings.injectNoctaliaContext")
              description: pluginApi?.tr("settings.injectNoctaliaContextHelp")
              checked: cs.injectNoctaliaContext !== false
              onToggled: checked => set("injectNoctaliaContext", checked)
            }
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginXS
              NLabel { label: pluginApi?.tr("settings.appendSystemPrompt") }
              TextArea {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(80 * Style.uiScaleRatio)
                text: cs.appendSystemPrompt 
                onActiveFocusChanged: {
                  if (!activeFocus) { set("appendSystemPrompt", text); }
                }
              }
            }
          }
        }

        // ============== MCP ==============
        ColumnLayout {
          spacing: Style.marginM
          Layout.margins: Style.marginM

          Section {
            title: pluginApi?.tr("settings.sectionMcp") 
            NTextInput {
              Layout.fillWidth: true
              label: pluginApi?.tr("settings.mcpConfigPath")
              text: cs.mcpConfigPath 
              placeholderText: "/home/you/.config/claude/mcp.json"
              onEditingFinished: set("mcpConfigPath", text)
            }
            NCheckbox {
              Layout.fillWidth: true
              label: pluginApi?.tr("settings.mcpStrict")
              checked: cs.strictMcpConfig === true
              onToggled: checked => set("strictMcpConfig", checked)
            }
          }
        }

        // ============== PANEL ==============
        ColumnLayout {
          spacing: Style.marginM
          Layout.margins: Style.marginM

          Section {
            title: pluginApi?.tr("settings.groupLayout") 
            NComboBox {
              Layout.fillWidth: true
              label: pluginApi?.tr("settings.panelPosition")
              model: [
                { key: "right",  name: "right" },
                { key: "left",   name: "left" },
                { key: "center", name: "center" },
                { key: "top",    name: "top" },
                { key: "bottom", name: "bottom" }
              ]
              currentKey: pluginApi?.pluginSettings?.panelPosition || "right"
              onSelected: key => setTop("panelPosition", key)
            }
            NCheckbox {
              Layout.fillWidth: true
              label: pluginApi?.tr("settings.panelDetached")
              checked: pluginApi?.pluginSettings?.panelDetached ?? true
              onToggled: checked => setTop("panelDetached", checked)
            }
          }

          Section {
            title: pluginApi?.tr("settings.groupSize") 
            NSpinBox {
              Layout.fillWidth: true
              label: pluginApi?.tr("settings.panelWidth")
              from: 320
              to: 1600
              stepSize: 10
              value: pluginApi?.pluginSettings?.panelWidth ?? 620
              onValueChanged: setTop("panelWidth", value)
            }
            NSpinBox {
              Layout.fillWidth: true
              label: pluginApi?.tr("settings.panelHeightRatio")
              from: 30
              to: 100
              stepSize: 1
              value: Math.round((pluginApi?.pluginSettings?.panelHeightRatio ?? 0.9) * 100)
              onValueChanged: setTop("panelHeightRatio", value / 100)
            }
          }
        }

        // ============== DANGER ZONE ==============
        ColumnLayout {
          spacing: Style.marginM
          Layout.margins: Style.marginM

          Rectangle {
            Layout.fillWidth: true
            radius: Style.radiusM
            color: Qt.alpha(Color.mError, 0.10)
            border.color: Color.mError
            border.width: Style.borderS
            implicitHeight: dangerCol.implicitHeight + Style.marginM * 2

            ColumnLayout {
              id: dangerCol
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginS

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                NIcon { icon: "alert-triangle"; color: Color.mError; pointSize: Style.fontSizeM }
                NText {
                  text: pluginApi?.tr("settings.dangerHeading") 
                  font.weight: Font.Bold
                  pointSize: Style.fontSizeM
                  color: Color.mError
                }
              }
              NText {
                text: pluginApi?.tr("settings.dangerSubheading") 
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
              }

              NCheckbox {
                Layout.fillWidth: true
                label: pluginApi?.tr("settings.dangerouslySkip")
                description: pluginApi?.tr("settings.dangerouslySkipHelp")
                checked: cs.dangerouslySkipPermissions === true
                onToggled: checked => {
                  if (checked) { bypassConfirm.forSkip = true; bypassConfirm.open(); }
                  else         { set("dangerouslySkipPermissions", false); }
                }
              }
              NCheckbox {
                Layout.fillWidth: true
                label: pluginApi?.tr("settings.confirmBypass")
                checked: cs.requireConfirmBypass !== false
                onToggled: checked => set("requireConfirmBypass", checked)
              }
            }
          }
        }
      }
      } // /NScrollView

      // Floating "Saved ✓" pill — appears near the bottom-right of the settings
      // pane (where Apply/Save buttons typically live), pops in on each save,
      // fades out after the timer. Anchored as a sibling of the NScrollView so
      // it overlays content without affecting layout.
      Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Style.marginM
        anchors.bottomMargin: Style.marginM
        z: 100
        opacity: root._saveBlinking ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        // Subtle slide-up while appearing. Behavior must live on a regular
        // property — not inside the Translate — so we drive Translate via
        // a bound property and animate that.
        property real _slideY: root._saveBlinking ? 0 : 6
        Behavior on _slideY { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        transform: Translate { y: _slideY }

        implicitWidth: savedRow.implicitWidth + Style.marginM * 2
        implicitHeight: savedRow.implicitHeight + Style.marginS * 2
        radius: height / 2
        color: Color.mSecondary
        border.color: Qt.darker(Color.mSecondary, 1.2)
        border.width: Style.borderS

        RowLayout {
          id: savedRow
          anchors.centerIn: parent
          spacing: Style.marginXS
          NIcon {
            icon: "check"
            pointSize: Style.fontSizeXS
            color: Color.mOnSecondary
          }
          NText {
            text: pluginApi?.tr("settings.savedFlash") 
            pointSize: Style.fontSizeXS
            font.weight: Font.DemiBold
            color: Color.mOnSecondary
          }
        }
      }
    } // /Item (right pane wrapper)
  } // /RowLayout

  // ============================================================================
  // Dialogs
  // ============================================================================

  Dialog {
    id: bypassConfirm
    modal: true
    title: "Confirm"
    width: 420
    property bool forSkip: false

    contentItem: ColumnLayout {
      spacing: Style.marginS
      NText {
        text: bypassConfirm.forSkip
              ? pluginApi?.tr("dialog.bypassSkipWarning")
              : pluginApi?.tr("dialog.bypassModeWarning")
        wrapMode: Text.Wrap
        Layout.fillWidth: true
        color: Color.mError
      }
      NText {
        text: pluginApi?.tr("dialog.proceed")
        font.weight: Font.Bold
      }
    }

    standardButtons: Dialog.Ok | Dialog.Cancel
    onAccepted: {
      if (forSkip) {
        set("dangerouslySkipPermissions", true);
        ToastService.showError(pluginApi?.tr("toast.bypassEnabled"));
      } else {
        set("permissionMode", "bypassPermissions");
        ToastService.showError(pluginApi?.tr("toast.bypassEnabled"));
      }
      forSkip = false;
    }
    onRejected: {
      ToastService.showNotice(pluginApi?.tr("toast.bypassCancelled"));
      forSkip = false;
    }
  }

  Dialog {
    id: resetConfirm
    modal: true
    title: pluginApi?.tr("settings.resetDefaults") 
    width: 420
    contentItem: NText {
      text: pluginApi?.tr("settings.resetConfirm") 
      wrapMode: Text.Wrap
    }
    standardButtons: Dialog.Ok | Dialog.Cancel
    onAccepted: {
      // Wipe the claude block and known top-level overrides; saveSettings()
      // re-emits defaults from the manifest schema.
      pluginApi.pluginSettings.claude = {};
      pluginApi.saveSettings();
    }
  }
}
