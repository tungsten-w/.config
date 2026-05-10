import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property int editRefreshInterval:
    pluginApi?.pluginSettings?.refreshInterval ||
    pluginApi?.manifest?.metadata?.defaultSettings?.refreshInterval ||
    3000

  property bool editShowProfileLabel:
    pluginApi?.pluginSettings?.showProfileLabel ??
    pluginApi?.manifest?.metadata?.defaultSettings?.showProfileLabel ??
    false

  property string editActiveColor:
    pluginApi?.pluginSettings?.activeColor ||
    pluginApi?.manifest?.metadata?.defaultSettings?.activeColor ||
    "primary"

  spacing: Style.marginM

  NText {
    text: pluginApi?.tr("settings.title")
    font.pointSize: Style.fontSizeXL
    font.bold: true
  }

  NText {
    text: pluginApi?.tr("settings.description")
    color: Color.mSecondary
    Layout.fillWidth: true
    wrapMode: Text.Wrap
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  NToggle {
    label: pluginApi?.tr("settings.show-profile-label")
    description: pluginApi?.tr("settings.show-profile-label-desc")
    checked: root.editShowProfileLabel
    onToggled: checked => root.editShowProfileLabel = checked
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  NColorChoice {
    label: pluginApi?.tr("settings.active-color")
    description: pluginApi?.tr("settings.active-color-desc")
    currentKey: root.editActiveColor
    onSelected: key => root.editActiveColor = key
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  NLabel {
    label: pluginApi?.tr("settings.refresh-interval")
    description: pluginApi?.tr("settings.refresh-interval-desc") + " (" + root.editRefreshInterval + " ms)"
  }

  NSlider {
    Layout.fillWidth: true
    from: 1000
    to: 30000
    stepSize: 1000
    value: root.editRefreshInterval
    onValueChanged: root.editRefreshInterval = value
  }

  function saveSettings() {
    if (!pluginApi) return

    pluginApi.pluginSettings.refreshInterval = root.editRefreshInterval
    pluginApi.pluginSettings.activeColor = root.editActiveColor
    pluginApi.pluginSettings.showProfileLabel = root.editShowProfileLabel

    pluginApi.saveSettings()
    Logger.i("Monique", "Settings saved")
  }
}
