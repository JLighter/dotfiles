import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Widget d'usage Claude : quota le plus contraignant dans la barre, detail
// complet au clic. Vue Claude seule de ce que montre `omarchy.agents`.
//
// Une seule source : l'enregistrement que le collecteur d'Omarchy depose dans
// ~/.local/state/omarchy/agents/usage/claude.json. Quotas et compteurs locaux y
// arrivent ensemble — ce widget interrogeait auparavant l'endpoint OAuth
// d'Anthropic lui-meme et embarquait son propre scanner de transcrits ; la 4.0
// fait les deux, mieux, et personne n'a plus a manipuler de jeton ici.
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

  // --- Enregistrement d'usage ------------------------------------------------
  // Omarchy collecte lui-meme l'usage des agents depuis la 4.0 :
  // `omarchy-agent-usage-update` lance un collecteur par agent et depose un
  // enregistrement JSON par agent dans ~/.local/state/omarchy/agents/usage/. Le
  // collecteur `claude` fait les deux choses que ce widget faisait a la main —
  // interroger l'endpoint OAuth d'Anthropic pour les quotas, parcourir
  // ~/.claude/projects pour les compteurs — et couvre en plus les sessions
  // opencode et un cache de repli quand les transcrits manquent.
  //
  // Ce widget ne detient donc plus de jeton, n'ouvre plus de socket et n'embarque
  // plus de scanner : il lit un fichier et demande sa regeneration.

  property var record: ({})

  readonly property string usagePath:
    (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
    + "/omarchy/agents/usage/claude.json"

  function parseRecord(content) {
    try {
      var parsed = JSON.parse(String(content || ""))
      root.record = parsed && typeof parsed === "object" ? parsed : ({})
    } catch (e) {
      root.record = ({})
    }
  }

  FileView {
    path: root.usagePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parseRecord(text())
    onLoadFailed: root.record = ({})
  }

  // Le collecteur separe ce qu'il n'a pas pu joindre (`usageStatusText`) de ce
  // qu'il faut faire pour y remedier (`authHelpText`).
  readonly property string statusText: String(record.usageStatusText || "")
  readonly property string authHelpText: String(record.authHelpText || "")
  readonly property string subscriptionType: String(record.tierLabel || "")

  // « Authentifie » n'a plus de sens ici, le widget ne detient plus de jeton :
  // ce qui compte est qu'un enregistrement exploitable soit arrive.
  readonly property bool authenticated: record.ready === true && statusText === ""

  // --- Quotas ----------------------------------------------------------------
  // L'enregistrement normalise chaque quota en {label, percent, resetsAt, title}
  // — une entree par fenetre, quelle qu'elle soit, pour qu'un futur quota
  // apparaisse tout seul. Le pourcentage y est une fraction de 0 a 1, la ou
  // l'endpoint d'Anthropic parlait en centiemes : on le ramene une fois pour
  // toutes a l'echelle d'affichage, et le reste du fichier ne voit pas la
  // difference.

  readonly property var limits: {
    var source = Array.isArray(record.limits) ? record.limits : []
    var out = []
    for (var i = 0; i < source.length; i++) {
      var entry = source[i]
      if (!entry) continue

      // Un quota que le collecteur n'a pas pu mesurer arrive en negatif : il
      // n'a rien a dire, et le laisser passer le ferait gagner le classement du
      // quota le plus consomme a l'envers.
      var percent = Number(entry.percent)
      if (!isFinite(percent) || percent < 0) continue

      out.push({
        label: String(entry.title || entry.label || ""),
        percent: percent * 100,
        resetsAt: String(entry.resetsAt || "")
      })
    }
    return out
  }

  readonly property bool probing: collector.running

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

  // Le collecteur nomme deja ses fenetres (« Session (5-hour) », « Weekly
  // (7-day) », « Fable Weekly ») : il n'y a plus de code de type a traduire.
  function limitLabel(entry) {
    return entry ? String(entry.label || "") : ""
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

  // Sur combien de temps porte un quota. L'enregistrement ne le dit pas : il
  // nomme ses fenetres sans les mesurer. Le nom porte pourtant la duree —
  // « Session (5-hour) », « Weekly (7-day) » — et une fenetre dont le nom n'en
  // dit rien (« Fable Weekly ») est hebdomadaire chez Anthropic.
  function windowFor(entry) {
    var label = String((entry && entry.label) || "")
    var match = label.match(/(\d+)\s*-?\s*(hour|day)/i)

    if (match) {
      var count = Number(match[1])
      var unit = match[2].toLowerCase() === "hour" ? 3600 * 1000 : 24 * 3600 * 1000
      if (count > 0) return count * unit
    }

    return 7 * 24 * 3600 * 1000
  }

  // Compare la consommation au temps ecoule dans la fenetre : au-dessus de la
  // diagonale on consomme trop vite pour tenir jusqu'a la remise a zero.
  function paceFor(entry) {
    if (!entry || !entry.resetsAt) return ""

    var reset = new Date(entry.resetsAt).getTime()
    if (!isFinite(reset)) return ""

    var period = windowFor(entry)
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

  // --- Compteurs locaux ------------------------------------------------------
  // Memes noms que dans l'enregistrement : le collecteur publie exactement le
  // contrat que produisait le scanner, il n'y a rien a traduire.

  readonly property int todayPrompts: Number(record.todayPrompts || 0)
  readonly property int todaySessions: Number(record.todaySessions || 0)
  readonly property real todayTokens: Number(record.todayTotalTokens || 0)
  readonly property int totalPrompts: Number(record.totalPrompts || 0)
  readonly property int totalSessions: Number(record.totalSessions || 0)
  readonly property var modelUsage: record.modelUsage || ({})
  readonly property var recentDays: Array.isArray(record.recentDays) ? record.recentDays : []

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

  // --- Regeneration ----------------------------------------------------------
  // C'est `omarchy.agents` qui porte d'ordinaire ce rafraichissement ; ce widget
  // le remplace dans cette barre, la relance lui revient donc. On se limite a
  // l'agent claude — les autres enregistrements ne nous regardent pas, et le
  // widget natif garde son propre timer si un jour il reprend sa place.
  //
  // Le fichier est surveille, pas relu : c'est le FileView qui ramene le
  // resultat, ce processus ne fait que le provoquer.
  Process {
    id: collector

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("claude-usage", text.trim())
    }
  }

  function runCollector(flag) {
    // Une relance pendant qu'une autre tourne n'apporterait rien : le collecteur
    // ecrit le meme fichier, et la suivante viendra de toute facon au timer.
    if (collector.running) return

    var command = ["omarchy-agent-usage-update"]
    if (flag) command.push(flag)
    command.push("claude")
    collector.command = command
    collector.running = true
  }

  function refresh(force) {
    runCollector(force === true ? "--force" : "")
  }

  // Ce que veut une ouverture de panneau : les chiffres qui vieillissent sur le
  // reseau, pas une nouvelle marche sur tous les transcrits du disque.
  function refreshLimits() {
    runCollector("--limits-only")
  }

  // Sondage espace : le collecteur parcourt les transcrits et interroge un
  // endpoint distant, alors que l'icone n'a besoin que d'un ordre de grandeur.
  // Panneau ouvert, on se rabat sur les seuls quotas, bien moins couteux.
  Timer {
    interval: root.opened ? 60000 : 900000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.opened ? root.refreshLimits() : root.refresh(false)
  }

  // --- Ouverture -------------------------------------------------------------

  property bool opened: false

  function open() {
    opened = true
    refreshLimits()
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

  // Claude Desktop, quand il est installe. Le `command -v` en garde rend le
  // geste inoffensif sur une machine sans l'application : le shell sort sans
  // rien faire au lieu de remonter une commande introuvable. L'app est en
  // instance unique, un second lancement ramene la fenetre existante.
  readonly property string desktopAppCommand:
    "command -v claude-desktop >/dev/null 2>&1 && exec claude-desktop"

  function openDesktopApp() {
    if (!bar) return
    bar.run(desktopAppCommand)
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
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.openDesktopApp()
      else if (mouse.button === Qt.MiddleButton) root.refresh(true)
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

          // Le bloc « extra usage » a disparu avec l'appel direct a l'endpoint :
          // le collecteur ne reporte pas les credits hors forfait. Seuls les
          // agents prepayes ont un solde chez Omarchy, et Claude n'en est pas un.

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
        var reset = root.formatReset(limitRow.entry.resetsAt)
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
