import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var pluginApi: null

  readonly property int refreshInterval: pluginApi?.pluginSettings?.refreshInterval ?? 5000

  property bool moniqueInstalled: false
  property string moniquePath: ""
  property string activeProfile: ""
  property var profiles: []
  property bool isRefreshing: false

  Timer {
    id: updateTimer
    interval: root.refreshInterval
    running: root.moniqueInstalled
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    checkInstalled()
  }

  function checkInstalled() {
    root.isRefreshing = true
    whichProcess.running = true
  }

  function refresh() {
    if (root.isRefreshing) return
    root.isRefreshing = true
    currentProfileProcess.running = true
  }

  function switchProfile(name) {
    switchProcess.profileName = name
    switchProcess.running = true
  }

  Process {
    id: whichProcess
    command: ["which", "monique"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      if (exitCode === 0) {
        var resolved = String(whichProcess.stdout.text || "").trim()
        if (resolved !== "") {
          root.moniquePath = resolved
          root.moniqueInstalled = true
          root.isRefreshing = false
          root.refresh()
          listProfilesProcess.running = true
          updateTimer.start()
          return
        }
      }
      root.moniqueInstalled = false
      root.isRefreshing = false
      Logger.w("Monique", "monique not found in PATH")
    }
  }

  Process {
    id: listProfilesProcess
    command: [root.moniquePath, "--list-profiles"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      if (exitCode === 0) {
        try {
          root.profiles = JSON.parse(String(listProfilesProcess.stdout.text || "[]").trim())
        } catch (e) {
          root.profiles = []
          Logger.w("Monique", "Failed to parse profiles: " + e)
        }
      }
    }
  }

  Process {
    id: currentProfileProcess
    command: [root.moniquePath, "--current-profile"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      root.isRefreshing = false
      if (exitCode === 0) {
        root.activeProfile = String(currentProfileProcess.stdout.text || "").trim()
      } else {
        root.activeProfile = ""
      }
    }
  }

  Process {
    id: switchProcess

    property string profileName: ""

    command: [root.moniquePath, "--switch-profile", profileName]
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.activeProfile = switchProcess.profileName
        ToastService.showNotice(
          pluginApi?.tr("toast.title"),
          pluginApi?.tr("toast.switched", { profile: switchProcess.profileName }),
          "device-desktop"
        )
      } else {
        var err = String(switchProcess.stderr.text || "").trim()
        Logger.e("Monique", "Switch failed: " + err)
        ToastService.showWarning(
          pluginApi?.tr("toast.title"),
          err || pluginApi?.tr("toast.error")
        )
      }
    }
  }
}
