import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI
import Quickshell.Io

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property bool pillDirection: BarService.getPillDirection(root)
  readonly property var mainInstance: pluginApi?.mainInstance

  readonly property string activeColorKey: pluginApi?.pluginSettings?.activeColor
    ?? pluginApi?.manifest?.metadata?.defaultSettings?.activeColor
    ?? "primary"

  readonly property bool showProfileLabel: pluginApi?.pluginSettings?.showProfileLabel
    ?? pluginApi?.manifest?.metadata?.defaultSettings?.showProfileLabel
    ?? true

  readonly property bool hasActiveProfile: (mainInstance?.activeProfile ?? "") !== ""

  readonly property color resolvedIconColor: {
    var resolved = Color.resolveColorKeyOptional(activeColorKey)
    if (!resolved || resolved === "transparent" || resolved.a === 0)
      return mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
    return resolved
  }

  readonly property real contentWidth: {
    if (!(mainInstance?.moniqueInstalled ?? false)) {
      return Style.capsuleHeight
    }
    if (hasActiveProfile && showProfileLabel) {
      return contentRow.implicitWidth + Style.marginM * 2
    }
    return Style.capsuleHeight
  }
  readonly property real contentHeight: Style.capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    radius: Style.radiusL

    RowLayout {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.marginS

      NIcon {
        icon: "device-desktop"
        pointSize: Style.toOdd(Style.capsuleHeight * 0.48)
        applyUiScale: false
        color: root.resolvedIconColor
        opacity: 1.0
      }

      NText {
        visible: root.hasActiveProfile && root.showProfileLabel
        text: mainInstance?.activeProfile ?? ""
        pointSize: Style.fontSizeXS
        color: root.resolvedIconColor
        Layout.leftMargin: Style.marginXS
        Layout.rightMargin: Style.marginS
      }
    }
  }

  Process {
    id: openMoniqueProcess
    command: [mainInstance?.moniquePath ?? "monique"]
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("actions.open-monique"),
        "action": "open-monique",
        "icon": "device-desktop-cog",
        "enabled": mainInstance?.moniqueInstalled ?? false
      },
      {
        "label": pluginApi?.tr("actions.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      contextMenu.close()
      PanelService.closeContextMenu(screen)

      if (action === "open-monique") {
        openMoniqueProcess.running = true
      } else if (action === "widget-settings") {
        BarService.openPluginSettings(screen, pluginApi.manifest)
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onEntered: {
      if (root.hasActiveProfile)
        TooltipService.show(root, mainInstance.activeProfile, BarService.getTooltipDirection(root.screen?.name))
    }

    onExited: {
      TooltipService.hide()
    }

    onClicked: mouse => {
      if (mouse.button === Qt.LeftButton) {
        pluginApi?.openPanel(root.screen, root)
      } else if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen)
      }
    }
  }
}
