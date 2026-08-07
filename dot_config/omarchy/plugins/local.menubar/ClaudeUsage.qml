import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Widget d'usage Claude : quota le plus contraignant dans la barre, detail
// complet au clic. Reimplementation de `omarchy.model-usage` cote Claude.
//
// Deux sources, independantes l'une de l'autre :
//   - les quotas viennent de l'endpoint OAuth d'Anthropic, interroge avec le
//     jeton de ~/.claude/.credentials.json ;
//   - les compteurs locaux (prompts, sessions, tokens) viennent du scanner
//     Python embarque, qui parcourt ~/.claude/projects.
//
// Le jeton ne sort jamais d'ici : il part uniquement dans l'en-tete
// Authorization vers api.anthropic.com, n'est jamais passe en argument de
// commande (ce serait lisible dans `ps`) ni journalise.
BarWidget {
  id: root
  moduleName: "local.menubar.claude-usage"

  readonly property int islandSize: bar && bar.islandSize !== undefined ? bar.islandSize : barSize
  readonly property int islandRadius: bar && bar.islandRadius !== undefined ? bar.islandRadius : Style.cornerRadius

  readonly property int revealDuration: bar && bar.revealDuration !== undefined ? bar.revealDuration : 180
  readonly property int revealEasing: Easing.OutCubic

  readonly property color accentColor: bar ? bar.accent : Color.urgent
  readonly property real accentFillOpacity: bar && bar.accentFillOpacity !== undefined ? bar.accentFillOpacity : 0.18
  // Debordement du halo, pour qu'il epouse les bords de l'ilot au lieu d'en
  // laisser voir un liseré tout autour.
  readonly property int haloInsetX: bar && bar.islandPaddingX !== undefined ? bar.islandPaddingX : 0
  readonly property int haloInsetY: bar && bar.islandPaddingY !== undefined ? bar.islandPaddingY : 0
  readonly property color foregroundColor: bar ? bar.foreground : Color.foreground
  readonly property color mutedColor: Qt.darker(foregroundColor, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color islandFill: Qt.rgba(foregroundColor.r, foregroundColor.g, foregroundColor.b, 0.06)

  readonly property string barPosition: bar ? bar.position : "top"
  readonly property int revealDistance: Style.space(12)
  readonly property int revealOffsetX: barPosition === "left"
    ? -revealDistance
    : (barPosition === "right" ? revealDistance : 0)
  readonly property int revealOffsetY: barPosition === "bottom"
    ? revealDistance
    : (barPosition === "top" ? -revealDistance : 0)
  readonly property int transformOriginForBar: {
    if (barPosition === "bottom") return Item.Bottom
    if (barPosition === "left") return Item.Left
    if (barPosition === "right") return Item.Right
    return Item.Top
  }

  // --- Identifiants ----------------------------------------------------------

  property string accessToken: ""
  property real tokenExpiresAtMs: 0
  property string subscriptionType: ""
  property string statusText: ""

  readonly property bool tokenExpired: tokenExpiresAtMs > 0 && Date.now() >= tokenExpiresAtMs
  readonly property bool authenticated: accessToken !== "" && !tokenExpired

  function parseCredentials(content) {
    try {
      var oauth = (JSON.parse(content || "{}").claudeAiOauth) || {}
      accessToken = String(oauth.accessToken || "")
      subscriptionType = String(oauth.subscriptionType || "")

      // `expiresAt` est en millisecondes chez Claude Code, mais on tolere des
      // secondes pour ne pas croire le jeton perime a tort.
      var expires = Number(oauth.expiresAt || 0)
      tokenExpiresAtMs = expires > 0 && expires < 10000000000 ? expires * 1000 : expires

      statusText = accessToken === "" ? "Not signed in" : ""
      if (authenticated) probeUsage(true)
    } catch (e) {
      statusText = "Unreadable credentials"
    }
  }

  FileView {
    path: Quickshell.env("HOME") + "/.claude/.credentials.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parseCredentials(text())
    onLoadFailed: root.statusText = "Not signed in"
  }

  // --- Quotas ----------------------------------------------------------------
  // La reponse expose un tableau `limits` : une entree par quota, avec son
  // pourcentage, sa date de remise a zero et sa portee. On l'affiche tel quel
  // plutot que de coder en dur session/semaine, pour qu'un futur quota
  // apparaisse tout seul.

  property var limits: []
  property var extraUsage: null
  property real lastProbeAtMs: 0
  property bool probing: false
  readonly property int probeMinIntervalMs: 60000

  // Le quota qui compte : le plus consomme de tous.
  readonly property var leadingLimit: {
    var best = null
    for (var i = 0; i < limits.length; i++) {
      var entry = limits[i]
      if (!entry) continue
      if (!best || Number(entry.percent || 0) > Number(best.percent || 0)) best = entry
    }
    return best
  }

  readonly property int leadingPercent: leadingLimit ? Math.round(Number(leadingLimit.percent || 0)) : -1

  function limitLabel(entry) {
    if (!entry) return ""

    var scopeName = entry.scope && entry.scope.model ? String(entry.scope.model.display_name || "") : ""
    var kind = String(entry.kind || "")

    if (kind === "session") return "Session · 5 h"
    if (kind === "weekly_all") return "Weekly · all models"
    if (kind === "weekly_scoped") return scopeName ? "Weekly · " + scopeName : "Weekly · scoped"
    // Repli lisible pour un type de quota encore inconnu.
    return kind.replace(/_/g, " ") + (scopeName ? " · " + scopeName : "")
  }

  // « dans 2 h 15 » plutot qu'une date : c'est le delai qui interesse.
  function formatReset(iso) {
    if (!iso) return ""

    var target = new Date(iso).getTime()
    if (!isFinite(target)) return ""

    var remaining = target - Date.now()
    if (remaining <= 0) return "now"

    var minutes = Math.floor(remaining / 60000)
    var hours = Math.floor(minutes / 60)
    var days = Math.floor(hours / 24)

    if (days >= 1) return days + " d " + (hours % 24) + " h"
    if (hours >= 1) return hours + " h " + (minutes % 60) + " min"
    return minutes + " min"
  }

  // Compare la consommation au temps ecoule dans la fenetre : au-dessus de la
  // diagonale on consomme trop vite pour tenir jusqu'a la remise a zero.
  function paceFor(entry) {
    if (!entry || !entry.resets_at) return ""

    var reset = new Date(entry.resets_at).getTime()
    if (!isFinite(reset)) return ""

    var kind = String(entry.kind || "")
    var period = kind === "session" ? 5 * 3600 * 1000 : 7 * 24 * 3600 * 1000
    var remaining = reset - Date.now()
    if (remaining <= 0 || remaining > period) return ""

    var elapsed = period - remaining
    var expected = Math.max(0, Math.min(1, elapsed / period))
    var used = Math.max(0, Math.min(1, Number(entry.percent || 0) / 100))
    var diff = used - expected

    if (Math.abs(diff) <= 0.02) return "on pace"
    if (diff < 0) return Math.round(-diff * 100) + "% in reserve"

    // En deficit : estimer quand le quota sera epuise au rythme actuel.
    if (used > 0 && elapsed > 0) {
      var eta = elapsed / used * (1 - used)
      if (eta < remaining) return "runs out in " + formatReset(new Date(Date.now() + eta).toISOString())
    }
    return Math.round(diff * 100) + "% ahead"
  }

  function probeUsage(force) {
    if (!authenticated || probing) return

    var now = Date.now()
    if (force !== true && lastProbeAtMs > 0 && (now - lastProbeAtMs) < probeMinIntervalMs) return
    lastProbeAtMs = now
    probing = true

    var request = new XMLHttpRequest()
    request.open("GET", "https://api.anthropic.com/api/oauth/usage")
    request.setRequestHeader("Authorization", "Bearer " + accessToken)
    request.setRequestHeader("anthropic-beta", "oauth-2025-04-20")
    request.setRequestHeader("Accept", "application/json")
    request.onreadystatechange = function() {
      if (request.readyState !== XMLHttpRequest.DONE) return

      root.probing = false
      if (request.status < 200 || request.status >= 300) {
        // 429 = l'endpoint limite les sondes ; les compteurs locaux restent bons.
        root.statusText = request.status === 429 ? "Limits rate-limited" : "Limits unavailable"
        return
      }

      try {
        var payload = JSON.parse(request.responseText || "{}")
        root.limits = Array.isArray(payload.limits) ? payload.limits : []
        root.extraUsage = payload.extra_usage || null
        root.statusText = ""
      } catch (e) {
        root.statusText = "Unreadable limits"
      }
    }
    request.send()
  }

  // --- Compteurs locaux ------------------------------------------------------

  property var stats: ({})

  readonly property int todayPrompts: Number(stats.todayPrompts || 0)
  readonly property int todaySessions: Number(stats.todaySessions || 0)
  readonly property real todayTokens: Number(stats.todayTotalTokens || 0)
  readonly property int totalPrompts: Number(stats.totalPrompts || 0)
  readonly property int totalSessions: Number(stats.totalSessions || 0)
  readonly property var modelUsage: stats.modelUsage || ({})
  readonly property var recentDays: Array.isArray(stats.recentDays) ? stats.recentDays : []

  readonly property var modelNames: {
    var names = []
    for (var name in modelUsage) names.push(name)
    names.sort()
    return names
  }

  function formatCount(value) {
    var n = Number(value || 0)
    if (n >= 1000000000) return (n / 1000000000).toFixed(1) + " G"
    if (n >= 1000000) return (n / 1000000).toFixed(1) + " M"
    if (n >= 1000) return (n / 1000).toFixed(1) + " k"
    return String(Math.round(n))
  }

  Process {
    id: scanner

    // Le scanner vit a cote de ce fichier ; on resout son chemin depuis l'URL
    // du composant plutot que de coder en dur l'emplacement du plugin.
    readonly property string scriptPath: String(Qt.resolvedUrl("claude_usage_scanner.py")).replace(/^file:\/\//, "")

    command: ["python3", scriptPath, Quickshell.env("HOME") + "/.claude/projects"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.stats = JSON.parse(text || "{}")
        } catch (e) {
          root.stats = ({})
        }
      }
    }
  }

  function refresh(force) {
    if (!scanner.running) scanner.running = true
    probeUsage(force === true)
  }

  // Sondage espace : l'icone n'a besoin que d'un ordre de grandeur, et
  // l'endpoint d'Anthropic n'aime pas etre interroge en boucle.
  Timer {
    interval: root.opened ? 60000 : 900000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh(false)
  }

  // --- Ouverture -------------------------------------------------------------

  property bool opened: false

  function open() {
    opened = true
    refresh(true)
  }

  function close() {
    opened = false
  }

  function toggle() {
    opened ? close() : open()
  }

  function closeForPopoutSwitch() {
    close()
  }

  readonly property bool primaryInstance: {
    var window = root.QsWindow ? root.QsWindow.window : null
    var screens = Quickshell.screens
    return !!window && screens.length > 0 && window.screen === screens[0]
  }

  IpcHandler {
    enabled: root.primaryInstance
    target: "menubar.claude"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh(true) }
  }

  // --- Bouton de barre -------------------------------------------------------

  // Au repos, seul le logo occupe la barre ; le chiffre se deplie au survol,
  // comme la jauge du widget de volume, et l'ilot s'etire avec lui.
  readonly property int logoSize: Style.space(13)
  readonly property int logoGap: Style.space(4)
  readonly property bool percentRevealed: widgetHover.hovered || opened
  property int percentExtent: percentRevealed ? percentLabel.implicitWidth + logoGap : 0

  Behavior on percentExtent {
    NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
  }

  implicitWidth: logoGap + logoSize + percentExtent + logoGap
  implicitHeight: root.islandSize

  HoverHandler { id: widgetHover }

  // La barre interroge `tooltipHovered` sur la cible du tooltip pour savoir si
  // elle doit le garder affiche : c'est le widget entier qui joue ce role ici,
  // faute de WidgetButton pour le faire.
  readonly property bool tooltipHovered: widgetHover.hovered
  readonly property string tooltipText: {
    if (!authenticated) return "Claude · " + (statusText || "not signed in")

    var parts = []
    for (var i = 0; i < limits.length; i++) {
      var entry = limits[i]
      if (entry) parts.push(limitLabel(entry) + " " + Math.round(Number(entry.percent || 0)) + "%")
    }
    return parts.length > 0 ? parts.join("\n") : "Claude"
  }

  onTooltipHoveredChanged: {
    if (!bar) return

    if (tooltipHovered) bar.showTooltip(root, tooltipText)
    else bar.hideTooltip(root)
  }

  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: -root.haloInsetX
    anchors.rightMargin: -root.haloInsetX
    anchors.topMargin: -root.haloInsetY
    anchors.bottomMargin: -root.haloInsetY
    radius: root.islandRadius
    color: root.accentColor
    opacity: root.percentRevealed ? root.accentFillOpacity : 0

    Behavior on opacity {
      NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
    }
  }

  Image {
    id: logo

    source: Qt.resolvedUrl("claude.svg")
    width: root.logoSize
    height: width
    // Rasterise au double pour rester net sur un ecran a echelle.
    sourceSize.width: width * 2
    sourceSize.height: width * 2
    smooth: true
    x: root.logoGap
    anchors.verticalCenter: parent.verticalCenter
    opacity: root.authenticated ? 1 : 0.4
  }

  // Le chiffre glisse hors du cadre quand celui-ci se replie, plutot que de
  // retrecir.
  Item {
    x: root.logoGap + root.logoSize
    width: root.percentExtent
    height: parent.height
    clip: true

    Text {
      id: percentLabel

      x: root.logoGap
      text: root.leadingPercent >= 0 ? root.leadingPercent + "%" : "—"
      // Le quota qui s'approche de la limite passe en accent.
      color: root.leadingPercent >= 80 ? root.accentColor : root.foregroundColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      renderType: Text.NativeRendering
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    id: button

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.refresh(true)
      else root.toggle()
    }
  }

  // --- Panneau ---------------------------------------------------------------

  KeyboardPanel {
    id: panel

    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(760))

    PanelKeyCatcher {
      id: keyCatcher

      anchors.fill: parent
      onCloseRequested: root.close()
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh(true)
      }

      ScrollView {
        id: scrollArea

        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: content.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        opacity: root.opened ? 1 : 0
        scale: root.opened ? 1 : 0.97
        transformOrigin: root.transformOriginForBar

        transform: Translate {
          x: root.opened ? 0 : root.revealOffsetX
          y: root.opened ? 0 : root.revealOffsetY

          Behavior on x { NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing } }
          Behavior on y { NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing } }
        }

        Behavior on opacity { NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing } }
        Behavior on scale { NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing } }

        Column {
          id: content

          width: scrollArea.availableWidth
          spacing: Style.space(12)

          // ---- En-tete ----
          PanelIsland {

            Item {
              width: parent.width
              implicitHeight: Math.max(heroLogo.implicitHeight, heroLabels.implicitHeight)

              Image {
                id: heroLogo

                source: Qt.resolvedUrl("claude.svg")
                width: Style.space(30)
                height: width
                sourceSize.width: width * 2
                sourceSize.height: width * 2
                smooth: true
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                id: heroLabels

                anchors.left: heroLogo.right
                anchors.leftMargin: Style.space(14)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  text: "Claude"
                  color: root.foregroundColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: root.statusText !== ""
                    ? root.statusText.toUpperCase()
                    : (root.subscriptionType ? root.subscriptionType.toUpperCase() + " PLAN" : "SIGNED IN")
                  color: root.statusText !== "" ? root.accentColor : root.mutedColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1.2
                  elide: Text.ElideRight
                  width: parent.width
                }
              }
            }
          }

          // ---- Quotas ----
          PanelIsland {

            SectionHeader {
              text: "LIMITS"
              value: root.probing ? "REFRESHING" : ""
            }

            Repeater {
              model: root.limits

              LimitRow {
                required property var modelData

                width: parent.width
                entry: modelData
              }
            }

            Text {
              text: root.authenticated ? "No limits reported" : "Sign in to Claude Code to see limits"
              visible: root.limits.length === 0
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width
            }
          }

          // ---- Credits supplementaires ----
          PanelIsland {
            visible: root.extraUsage && root.extraUsage.is_enabled === true

            SectionHeader { text: "EXTRA USAGE" }

            DetailRow {
              label: "Used"
              value: root.extraUsage
                ? Number(root.extraUsage.used_credits || 0).toFixed(2) + " " + String(root.extraUsage.currency || "")
                : ""
            }

            DetailRow {
              label: "Monthly limit"
              value: root.extraUsage
                ? Number(root.extraUsage.monthly_limit || 0).toFixed(2) + " " + String(root.extraUsage.currency || "")
                : ""
            }
          }

          // ---- Activite du jour ----
          PanelIsland {

            SectionHeader { text: "TODAY" }

            DetailRow { label: "Prompts"; value: String(root.todayPrompts) }
            DetailRow { label: "Sessions"; value: String(root.todaySessions) }
            DetailRow { label: "Tokens"; value: root.formatCount(root.todayTokens) }
          }

          // ---- Cumul par modele ----
          PanelIsland {
            visible: root.modelNames.length > 0

            SectionHeader { text: "TOKENS BY MODEL" }

            Repeater {
              model: root.modelNames

              Column {
                id: modelBlock

                required property var modelData

                readonly property var usage: root.modelUsage[modelData] || ({})

                width: parent.width
                spacing: Style.space(2)

                Text {
                  text: modelBlock.modelData
                  color: root.accentColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                  topPadding: Style.space(4)
                }

                DetailRow { label: "Input"; value: root.formatCount(modelBlock.usage.inputTokens) }
                DetailRow { label: "Output"; value: root.formatCount(modelBlock.usage.outputTokens) }
                DetailRow { label: "Cache write"; value: root.formatCount(modelBlock.usage.cacheCreationInputTokens) }
                DetailRow { label: "Cache read"; value: root.formatCount(modelBlock.usage.cacheReadInputTokens) }
              }
            }
          }

          // ---- Sept derniers jours ----
          PanelIsland {
            visible: root.recentDays.length > 0

            SectionHeader { text: "LAST 7 DAYS" }

            Item {
              id: chart

              width: parent.width
              implicitHeight: Style.space(46)

              // Barres proportionnelles au jour le plus charge de la fenetre.
              readonly property real peak: {
                var max = 0
                for (var i = 0; i < root.recentDays.length; i++) {
                  var value = Number(root.recentDays[i].messageCount || 0)
                  if (value > max) max = value
                }
                return max
              }
              readonly property int gap: Style.space(4)
              readonly property int lastIndex: root.recentDays.length - 1

              Row {
                anchors.fill: parent
                spacing: chart.gap

                Repeater {
                  model: root.recentDays

                  Item {
                    id: dayColumn

                    required property var modelData
                    required property int index

                    readonly property real ratio: chart.peak > 0
                      ? Number(modelData.messageCount || 0) / chart.peak
                      : 0
                    readonly property bool isToday: index === chart.lastIndex

                    width: (chart.width - chart.gap * 6) / 7
                    height: chart.height

                    Rectangle {
                      anchors.horizontalCenter: parent.horizontalCenter
                      anchors.bottom: dayLabel.top
                      anchors.bottomMargin: Style.space(3)
                      width: parent.width
                      // Une trace minimale reste visible pour un jour a zero.
                      height: Math.max(Style.space(2), (chart.height - Style.space(14)) * dayColumn.ratio)
                      radius: Style.space(2)
                      color: dayColumn.isToday ? root.accentColor : root.foregroundColor
                      opacity: dayColumn.isToday ? 1 : 0.35

                      Behavior on height {
                        NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
                      }
                    }

                    Text {
                      id: dayLabel

                      text: String(dayColumn.modelData.date || "").slice(8)
                      color: root.mutedColor
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      anchors.horizontalCenter: parent.horizontalCenter
                      anchors.bottom: parent.bottom
                    }
                  }
                }
              }
            }
          }

          // ---- Cumul ----
          PanelIsland {

            SectionHeader { text: "ALL TIME" }

            DetailRow { label: "Prompts"; value: String(root.totalPrompts) }
            DetailRow { label: "Sessions"; value: String(root.totalSessions) }
          }
        }
      }
    }
  }

  // --- Composants internes ---------------------------------------------------

  component PanelIsland: Rectangle {
    default property alias content: holder.data
    property int padding: Style.space(10)

    width: parent.width
    implicitHeight: holder.implicitHeight + padding * 2
    radius: Style.cornerRadius
    color: root.islandFill

    Column {
      id: holder

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: parent.padding
      spacing: Style.space(4)
    }
  }

  component SectionHeader: Item {
    id: sectionHeader

    property alias text: header.text
    property string value: ""

    width: parent.width
    implicitHeight: Math.max(header.implicitHeight, valueLabel.implicitHeight)

    PanelSectionHeader {
      id: header

      foreground: root.foregroundColor
      fontFamily: root.fontFamily
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: valueLabel

      text: sectionHeader.value
      visible: text !== ""
      color: root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  component DetailRow: Item {
    id: detailRow

    property string label: ""
    property string value: ""

    width: parent.width
    implicitHeight: Style.space(18)

    Text {
      text: detailRow.label
      color: root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      anchors.left: parent.left
      anchors.leftMargin: Style.space(2)
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      text: detailRow.value
      color: root.foregroundColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      anchors.right: parent.right
      anchors.rightMargin: Style.space(2)
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // Quota : intitule, pourcentage, jauge, delai de remise a zero et rythme.
  component LimitRow: Column {
    id: limitRow

    required property var entry

    readonly property real percent: Math.max(0, Math.min(100, Number(entry.percent || 0)))
    readonly property bool active: entry.is_active === true
    readonly property string pace: root.paceFor(entry)

    width: parent.width
    spacing: Style.space(3)
    topPadding: Style.space(4)

    Item {
      width: parent.width
      implicitHeight: Style.space(18)

      Text {
        text: root.limitLabel(limitRow.entry)
        color: limitRow.active ? root.accentColor : root.foregroundColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: limitRow.active
        elide: Text.ElideRight
        width: parent.width - Style.space(50)
        anchors.left: parent.left
        anchors.leftMargin: Style.space(2)
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: Math.round(limitRow.percent) + "%"
        color: root.foregroundColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        anchors.right: parent.right
        anchors.rightMargin: Style.space(2)
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Rectangle {
      width: parent.width - Style.space(4)
      x: Style.space(2)
      height: Math.max(3, Style.space(4))
      radius: height / 2
      color: root.bar ? Style.selectedFillFor(root.bar.foreground, Color.accent) : Color.muted

      Rectangle {
        width: parent.width * limitRow.percent / 100
        height: parent.height
        radius: parent.radius
        color: root.accentColor

        Behavior on width {
          NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
        }
      }
    }

    Text {
      text: {
        var reset = root.formatReset(limitRow.entry.resets_at)
        var parts = []
        if (reset) parts.push("resets in " + reset)
        if (limitRow.pace) parts.push(limitRow.pace)
        return parts.join(" · ")
      }
      color: root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      width: parent.width - Style.space(4)
      x: Style.space(2)
    }
  }
}
