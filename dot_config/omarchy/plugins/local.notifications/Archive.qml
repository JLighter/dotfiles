// L'archive des notifications, montee une seule fois pour tout le shell.
//
// Elle vit dans le plugin `service` et non dans le widget de barre, et c'est le
// point qui commande tout le reste : Omarchy construit une barre PAR ECRAN.
// Un `Process` pose dans le widget serait un watcher par moniteur — deux
// inotifywait sur les memes fichiers, deux listes en memoire, et un « tout
// marquer lu » qui ne vaudrait que pour l'ecran ou on a clique. Le magasin sur
// disque est deja partage ; ceci en est le proprietaire QML.
//
// Ce qui est lu ici ne vient jamais du modele du service natif, mais des
// fichiers qu'il ecrit. Deux raisons :
//
//   1. Une notification recue en « ne pas deranger » n'entre jamais dans
//      `popupModel` — `handleNotification()` appelle `writeSilenced()` et
//      retourne. Elle n'existe que sur disque. Or « qu'est-ce que j'ai rate
//      pendant que c'etait silencieux » est exactement la question a laquelle
//      un centre de notifications existe pour repondre.
//   2. Le format sur disque est un contrat stable, la ou `Service.qml` s'accroche
//      deja a `popupModel`, `liveRefs` et `archivePopupFileFor` pour peindre les
//      toasts. Autant ne pas payer cette fragilite une seconde fois.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  width: 0
  height: 0
  visible: false

  // --- Reglages, pousses par le widget de barre --------------------------------
  property int keepDays: 30
  property int maxItems: 1000
  property bool showPreview: true
  // Combien de lignes on tient en memoire. L'archive sur disque va bien plus
  // loin ; c'est `notification-archive list N` qui sait la relire entierement.
  property int pageSize: 500

  // --- Etat --------------------------------------------------------------------
  property var entries: []
  property double lastSeen: 0
  property bool loaded: false

  readonly property bool watching: watchProc.running

  // La liste est rangee du plus recent au plus ancien : des qu'on croise une
  // entree deja vue, tout ce qui suit l'est aussi.
  readonly property int unread: {
    var count = 0
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].timestamp > lastSeen) count++
      else break
    }
    return count
  }

  signal entryAdded(var entry)
  signal entriesReset()

  readonly property string script:
    Qt.resolvedUrl("bin/notification-archive").toString().replace(/^file:\/\//, "")

  readonly property var storeEnvironment: ({
    "NA_KEEP_DAYS": String(root.keepDays),
    "NA_MAX_ITEMS": String(root.maxItems),
    "NA_PREVIEWS": root.showPreview ? "1" : "0"
  })

  function storeCommand(args) {
    return [root.script].concat(args)
  }

  // --- Lecture -----------------------------------------------------------------

  // Test de fraicheur a bon marche : l'archive est triee, donc une longueur
  // egale et une meme premiere cle veulent dire « rien n'a bouge ». Sans lui, la
  // relecture periodique reconstruirait la liste du panneau toutes les dix
  // secondes, curseur et defilement compris.
  function differsFrom(data) {
    if (data.length !== entries.length) return true
    if (data.length === 0) return false
    return String(data[0].key) !== String(entries[0].key)
  }

  function load() {
    if (listProc.running) return
    listProc.command = root.storeCommand(["list", String(root.pageSize)])
    listProc.running = true
  }

  function readSeen() {
    if (seenProc.running) return
    seenProc.command = root.storeCommand(["seen"])
    seenProc.running = true
  }

  // --- Ecriture ----------------------------------------------------------------

  function markSeen() {
    var stamp = Date.now()
    root.lastSeen = stamp
    if (markProc.running) return
    markProc.command = root.storeCommand(["seen", String(stamp)])
    markProc.running = true
  }

  // Detache, comme la purge : une suppression qui arrive pendant qu'une
  // precedente tourne encore rendrait la main sans rien faire, et l'entree
  // reviendrait a la prochaine relecture — un bouton qui a l'air casse.
  function remove(key) {
    if (!key) return
    var next = []
    for (var i = 0; i < entries.length; i++)
      if (entries[i].key !== key) next.push(entries[i])
    entries = next
    entriesReset()
    Quickshell.execDetached(root.storeCommand(["remove", String(key)]))
  }

  function clearAll() {
    entries = []
    entriesReset()
    Quickshell.execDetached(root.storeCommand(["clear"]))
  }

  // --- Flux du watcher ---------------------------------------------------------

  function absorb(line) {
    var entry
    try {
      entry = JSON.parse(line)
    } catch (e) {
      return
    }
    if (!entry || !entry.key) return
    // close_write et moved_to se declenchent tous les deux pour un meme popup ;
    // le second est ecarte par la cle.
    for (var i = 0; i < entries.length; i++)
      if (entries[i].key === entry.key) return

    var next = [entry].concat(entries)
    if (next.length > pageSize) next = next.slice(0, pageSize)
    entries = next
    entryAdded(entry)
  }

  Process {
    id: watchProc
    command: root.storeCommand(["watch"])
    environment: root.storeEnvironment
    running: true
    stdout: SplitParser {
      onRead: function(line) { root.absorb(line) }
    }
    // Le watcher ne devrait pas s'arreter. S'il le fait — inotify a court de
    // veilleuses, un `pkill` mal vise — on le relance, sans boucle serree : une
    // relance immediate d'un process qui echoue a l'ouverture tournerait a la
    // rafale.
    onExited: restartWatch.restart()
  }

  Timer {
    id: restartWatch
    interval: 30000
    onTriggered: if (!watchProc.running) watchProc.running = true
  }

  // Filet : le flux du watcher est la voie normale, celle-ci rattrape ce qu'un
  // watcher mort aurait laisse passer.
  Timer {
    interval: 10000
    running: true
    repeat: true
    onTriggered: root.load()
  }

  Process {
    id: listProc
    environment: root.storeEnvironment
    stdout: StdioCollector {
      onStreamFinished: {
        var data
        try {
          data = JSON.parse(text)
        } catch (e) {
          return
        }
        if (!Array.isArray(data)) return
        var wasLoaded = root.loaded
        root.loaded = true
        if (wasLoaded && !root.differsFrom(data)) return
        root.entries = data
        root.entriesReset()
      }
    }
  }

  Process {
    id: seenProc
    environment: root.storeEnvironment
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (data.ok === true) root.lastSeen = Number(data.seen) || 0
        } catch (e) {
          // Premiere ouverture : pas de fichier `seen`, tout est non lu.
        }
      }
    }
  }

  Process { id: markProc; environment: root.storeEnvironment }

  Component.onCompleted: {
    readSeen()
    load()
  }

  // --- Introspection -----------------------------------------------------------
  //
  // De quoi verifier le plugin sans le regarder : `state` repond en JSON, `seed`
  // remplit l'archive d'un trafic d'essai. Cible separee de celle du widget pour
  // que ces verbes-la restent clairement des verbes d'essai.
  //
  //   omarchy-shell local.notifications.archive state
  //   omarchy-shell local.notifications.archive seed 25
  IpcHandler {
    target: "local.notifications.archive"

    function state(): string {
      return JSON.stringify({
        entries: root.entries.length,
        newest: root.entries.length > 0 ? root.entries[0].summary : "",
        unread: root.unread,
        watching: watchProc.running,
        loaded: root.loaded,
        lastSeen: root.lastSeen,
        keepDays: root.keepDays,
        maxItems: root.maxItems
      })
    }

    function seed(count: int): string {
      Quickshell.execDetached(root.storeCommand(["seed", String(count > 0 ? count : 25)]))
      reloadAfterSeed.restart()
      return "seeding " + count
    }

    function clear(): string {
      root.clearAll()
      return "cleared"
    }

    function reload(): string {
      root.load()
      return "reloading"
    }
  }

  Timer {
    id: reloadAfterSeed
    interval: 600
    onTriggered: root.load()
  }
}
