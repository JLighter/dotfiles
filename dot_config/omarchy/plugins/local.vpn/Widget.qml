import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

// État des tunnels WireGuard dans la barre. La bascule elle-même est déléguée à
// ~/.local/bin/omarchy-vpn : le widget observe, le script décide (notamment la
// politique « un seul full tunnel à la fois »).
BarWidget {
  id: root
  moduleName: "local.vpn"

  readonly property int refreshIntervalSec: settings && settings.refreshIntervalSec ? settings.refreshIntervalSec : 15

  property var activeTunnels: []
  property int tunnelCount: 0
  readonly property bool connected: activeTunnels.length > 0

  // Rien à montrer tant qu'aucune connexion WireGuard n'est déclarée dans
  // NetworkManager — même logique que le widget micro, absent sans source audio.
  visible: tunnelCount > 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (statusProcess.running) return
    statusProcess.command = ["nmcli", "--terse", "--fields", "NAME,TYPE,DEVICE", "connection", "show"]
    statusProcess.running = true
  }

  // Une connexion est montée lorsque NetworkManager lui associe un device.
  // L'état du lien (handshake) demanderait les droits root, hors de portée ici.
  function parseStatus(text) {
    var active = []
    var total = 0
    var lines = String(text || "").trim().split("\n")

    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].split(":")
      if (parts.length < 3 || parts[1] !== "wireguard") continue
      total++
      if (parts[2] !== "") active.push(parts[0])
    }

    root.activeTunnels = active
    root.tunnelCount = total
  }

  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector { id: statusStdout; waitForEnd: true }
    onExited: function (exitCode) {
      if (exitCode === 0) {
        root.parseStatus(statusStdout.text)
      } else {
        root.activeTunnels = []
        root.tunnelCount = 0
      }
    }
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Le menu est un processus détaché : on ne saura pas quand l'utilisateur aura
  // choisi. Deux relectures suffisent à couvrir une bascule sans attendre le
  // prochain tour du timer.
  Timer {
    id: afterMenu
    interval: 1200
    repeat: true
    triggeredOnStart: false
    property int remaining: 0
    onTriggered: {
      root.refresh()
      remaining -= 1
      if (remaining <= 0) stop()
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰒃"
    active: root.connected
    tooltipText: root.connected
                 ? "VPN actif : " + root.activeTunnels.join(", ")
                 : (root.tunnelCount === 1 ? "VPN inactif" : root.tunnelCount + " tunnels, aucun actif")
    onPressed: function (b) {
      root.bar.run("omarchy-vpn")
      afterMenu.remaining = 4
      afterMenu.restart()
    }
  }
}
