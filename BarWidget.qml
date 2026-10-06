import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// DeepSeek Harness bar toggle.
//
// Left click  -> start/stop `dsh web` (the whole point of the plugin).
// Right click -> open the running web UI in the default browser.
//
// The icon is full color while the server runs and dimmed while it is stopped,
// so the bar reads at a glance. All process work is delegated to the bundled
// `bin/omarchy-dsh` helper; this widget only polls and paints.
BarWidget {
  id: root
  moduleName: "devmercenario.dsh"

  readonly property string pluginDir: Qt.resolvedUrl(".").toString()
    .replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string helper: pluginDir + "/bin/omarchy-dsh"

  readonly property string dshBin: root.setting("dshBin", "dsh")
  readonly property string dshHost: root.setting("host", "127.0.0.1")
  readonly property int dshPort: Number(root.setting("port", 3080))
  readonly property real idleOpacity: Number(root.setting("idleOpacity", 0.35))
  readonly property string glyph: root.setting("glyph", "")
  readonly property int refreshMs: Math.max(2, Number(root.setting("refreshIntervalSec", 5))) * 1000

  property bool running: false
  property bool busy: false
  property string statusText: "unknown"

  function commandFor(verb) {
    var c = [helper, verb]
    if (verb === "status")
      c.push("--json")
    c.push("--bin", dshBin, "--host", dshHost, "--port", String(dshPort))
    return c
  }

  function refresh() {
    if (!statusProc.running)
      statusProc.running = true
  }

  function runVerb(verb) {
    if (actionProc.running)
      return
    busy = true
    actionProc.command = commandFor(verb)
    actionProc.running = true
  }

  function applyStatus(output) {
    var parsed = null
    try {
      parsed = JSON.parse(String(output || "").trim())
    } catch (e) {
      parsed = null
    }
    if (parsed && typeof parsed.running === "boolean") {
      running = parsed.running
      statusText = parsed.running ? "running" : "stopped"
    } else {
      running = false
      statusText = "unknown"
    }
    busy = false
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "devmercenario.dsh"

    function toggle(): void {
      root.runVerb("toggle")
    }

    function open(): void {
      root.runVerb("open")
    }

    function refresh(): void {
      root.refresh()
    }

    function status(): string {
      return root.statusText
    }
  }

  Timer {
    interval: root.refreshMs
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: root.commandFor("status")

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }

    onExited: function (exitCode) {
      root.busy = false
    }
  }

  Process {
    id: actionProc
    onExited: function (exitCode) {
      root.refresh()
    }
  }

  Component {
    id: dshIcon

    Image {
      anchors.fill: parent
      source: root.pluginDir + "/assets/dsh.svg"
      sourceSize.width: 64
      sourceSize.height: 64
      fillMode: Image.PreserveAspectFit
      smooth: true
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    iconComponent: root.glyph === "" ? dshIcon : null
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    opacity: root.busy ? 0.6 : (root.running ? 1.0 : root.idleOpacity)
    tooltipText: "DeepSeek Harness: " + root.statusText
      + (root.running ? " — " + root.dshHost + ":" + root.dshPort : "")

    onPressed: function (buttonCode) {
      if (buttonCode === Qt.RightButton)
        root.runVerb("open")
      else
        root.runVerb("toggle")
    }
  }
}
