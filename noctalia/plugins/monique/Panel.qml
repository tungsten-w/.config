import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  readonly property var mainInstance: pluginApi?.mainInstance

  property real contentPreferredWidth: 280 * Style.uiScaleRatio
  property real contentPreferredHeight: contentColumn.implicitHeight + Style.marginM * 2

  anchors.fill: parent

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: contentColumn
      anchors {
        top: parent.top
        left: parent.left
        right: parent.right
        margins: Style.marginM
      }
      spacing: Style.marginM

      // Header
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: headerContent.implicitHeight + Style.marginM * 2

        RowLayout {
          id: headerContent
          anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Style.marginM
          }
          spacing: Style.marginS

          NIcon {
            icon: "device-desktop"
            pointSize: Style.fontSizeL
            color: Color.mPrimary
          }

          NText {
            text: pluginApi?.tr("panel.title")
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          NText {
            text: (mainInstance?.activeProfile ?? "") !== ""
              ? mainInstance?.activeProfile
              : pluginApi?.tr("panel.no-profile")
            pointSize: Style.fontSizeS
            color: (mainInstance?.activeProfile ?? "") !== ""
              ? Color.mPrimary
              : Color.mOnSurfaceVariant
          }
        }
      }

      // Avviso monique non installato
      Rectangle {
        Layout.fillWidth: true
        visible: !(mainInstance?.moniqueInstalled ?? true)
        Layout.preferredHeight: notInstalledLayout.implicitHeight + Style.marginM * 2
        color: Qt.alpha(Color.mError, 0.1)
        radius: Style.radiusM
        border.width: Style.borderS
        border.color: Qt.alpha(Color.mError, 0.3)

        RowLayout {
          id: notInstalledLayout
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          NIcon {
            icon: "alert-circle"
            pointSize: Style.fontSizeM
            color: Color.mError
          }

          NText {
            text: pluginApi?.tr("panel.not-installed")
            pointSize: Style.fontSizeS
            color: Color.mError
            Layout.fillWidth: true
            wrapMode: Text.Wrap
          }
        }
      }

      // Lista profili
      NBox {
        Layout.fillWidth: true
        visible: (mainInstance?.moniqueInstalled ?? false) && (mainInstance?.profiles?.length ?? 0) > 0
        Layout.preferredHeight: profilesColumn.implicitHeight + Style.marginS * 2

        ColumnLayout {
          id: profilesColumn
          anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Style.marginS
          }
          spacing: Style.marginXS

          Repeater {
            model: mainInstance?.profiles ?? []

            NButton {
              required property string modelData
              Layout.fillWidth: true
              text: modelData
              icon: modelData === (mainInstance?.activeProfile ?? "") ? "check" : "device-desktop"
              backgroundColor: modelData === (mainInstance?.activeProfile ?? "")
                ? Qt.alpha(Color.mPrimary, 0.15)
                : "transparent"
              textColor: modelData === (mainInstance?.activeProfile ?? "")
                ? Color.mPrimary
                : Color.mOnSurface
              enabled: mainInstance?.moniqueInstalled ?? false

              onClicked: {
                mainInstance?.switchProfile(modelData)
                pluginApi?.closePanel(pluginApi?.panelOpenScreen)
              }
            }
          }
        }
      }

      // Nessun profilo salvato
      NText {
        Layout.fillWidth: true
        visible: (mainInstance?.moniqueInstalled ?? false) && (mainInstance?.profiles?.length ?? 0) === 0
        text: pluginApi?.tr("panel.no-profiles")
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
      }
    }
  }
}
