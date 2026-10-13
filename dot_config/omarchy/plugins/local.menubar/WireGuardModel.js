.pragma library

// Logique pure du widget WireGuard : debit, fenetre du graphe, detection des
// coupures. Rien ici ne touche a QML ni a NetworkManager — les profils arrivent
// deja lus par `wireguard-backend.py status` — donc tout se teste avec `node`.
//
// Inspire de omarchy-wireguard (VirtualDataPro, MIT) : Traffic.js.

// 30 points a un releve toutes les 2 s : la minute que montre le graphe.
var WINDOW_SIZE = 30

// Au-dela, l'ecart ne mesure plus un debit mais une mise en veille ou un shell
// fige : mieux vaut repartir de zero qu'afficher une moyenne trompeuse.
var MAX_SAMPLE_GAP = 15

// `current` : { device, counters: { rx, tx } | null }, `timestamp` en secondes.
// Le point retourne sert de `previous` au releve suivant.
function sample(previous, current, timestamp) {
  if (!current || !current.counters) {
    return { time: timestamp, device: "", rx: 0, tx: 0, down: 0, up: 0 }
  }

  var counters = current.counters
  var elapsed = previous ? timestamp - previous.time : 0
  // Une autre interface, un compteur qui recule (interface recreee) ou un trou
  // dans les releves : les deux compteurs ne se comparent plus.
  var comparable = !!previous
    && previous.device === current.device
    && elapsed > 0
    && elapsed < MAX_SAMPLE_GAP
    && counters.rx >= previous.rx
    && counters.tx >= previous.tx

  return {
    time: timestamp,
    device: current.device,
    rx: counters.rx,
    tx: counters.tx,
    down: comparable ? (counters.rx - previous.rx) / elapsed : 0,
    up: comparable ? (counters.tx - previous.tx) / elapsed : 0
  }
}

// Retourne un nouveau tableau : muter l'ancien en place ne notifierait pas les
// liaisons QML qui le lisent.
function pushWindow(history, point) {
  var next = (history || []).slice()
  next.push(point)
  while (next.length > WINDOW_SIZE) next.shift()
  return next
}

function isUp(state) {
  return state === "activated"
}

// Etats ou NetworkManager n'a pas encore tranche : on attend le releve suivant
// plutot que de crier a la coupure sur une reconnexion en cours.
function isSettling(state) {
  return state === "activating" || state === "deactivating"
}

// Tunnels tombes entre deux releves sans qu'on l'ait demande. `expected` mappe
// les uuid coupes volontairement (down depuis le panneau, ou victimes d'une
// bascule de full tunnel) vers `true`.
//
// Seul un tunnel etabli (`activated`) ou en train de se defaire peut tomber :
// une activation qui echoue n'a jamais ete une connexion.
function dropped(previous, current, expected) {
  if (!previous) return []

  var wanted = expected || {}
  var now = current || []

  return previous.filter(function(old) {
    if (old.state !== "activated" && old.state !== "deactivating") return false
    if (wanted[old.uuid]) return false

    var still = now.filter(function(profile) { return profile.uuid === old.uuid })[0]
    if (!still) return true

    return !isUp(still.state) && !isSettling(still.state)
  })
}

function activeNames(profiles) {
  return (profiles || [])
    .filter(function(profile) { return isUp(profile.state) })
    .map(function(profile) { return profile.name })
}

// Meme format que le panneau reseau, pour que les deux debits se lisent pareil.
function formatRate(bytesPerSec) {
  var value = Number(bytesPerSec || 0)
  if (value < 1024) return Math.round(value) + " B/s"
  if (value < 1024 * 1024) return (value / 1024).toFixed(value < 10240 ? 1 : 0) + " kB/s"
  return (value / (1024 * 1024)).toFixed(1) + " MB/s"
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    WINDOW_SIZE: WINDOW_SIZE,
    sample: sample,
    pushWindow: pushWindow,
    isUp: isUp,
    dropped: dropped,
    activeNames: activeNames,
    formatRate: formatRate
  }
}
