.pragma library

// Debit de l'interface active pour le widget Network : lecture de
// /proc/net/dev, ecart entre deux releves, format d'affichage. Rien ici ne
// touche a QML, donc tout se teste avec `node`.
//
// Les compteurs sont lus au moment du releve, et l'instant passe a
// nextThroughput est celui de cette lecture. Dater le releve a la fin de
// `omarchy-network-status`, qui pingue apres avoir lu ses compteurs, faussait
// le debit d'un facteur trois des qu'un ping se perdait.

// Au-dela, l'ecart mesure une mise en veille ou un shell fige, pas un debit.
var MAX_SAMPLE_GAP_MS = 30000

// { rx, tx } en octets pour `interfaceName`, ou null.
function parseNetDev(raw, interfaceName) {
  if (!interfaceName) return null
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var separator = lines[i].indexOf(":")
    if (separator < 0) continue
    if (lines[i].slice(0, separator).trim() !== interfaceName) continue
    var fields = lines[i].slice(separator + 1).trim().split(/\s+/)
    if (fields.length < 9) return null
    var rx = Number(fields[0])
    var tx = Number(fields[8])
    return isFinite(rx) && isFinite(tx) ? { rx: rx, tx: tx } : null
  }
  return null
}

// `previous` : snapshot rendu par l'appel precedent ({ iface, rx, tx, time }) ou
// null. Rend { snapshot, rates, reset } :
//   rates  { down, up } en octets/s, ou null quand l'ecart ne mesure rien ;
//   reset  vrai quand l'historique doit etre efface (interface changee, lien
//          perdu) : comparer les compteurs de deux cartes n'a pas de sens.
function nextThroughput(previous, counters, iface, timeMs) {
  if (!counters) return { snapshot: null, rates: null, reset: true }

  var snapshot = { iface: iface, rx: counters.rx, tx: counters.tx, time: timeMs }
  if (!previous) return { snapshot: snapshot, rates: null, reset: false }
  if (previous.iface !== iface) return { snapshot: snapshot, rates: null, reset: true }

  var elapsedMs = timeMs - previous.time
  var rxDelta = counters.rx - previous.rx
  var txDelta = counters.tx - previous.tx
  if (elapsedMs <= 0 || elapsedMs >= MAX_SAMPLE_GAP_MS || rxDelta < 0 || txDelta < 0) {
    return { snapshot: snapshot, rates: null, reset: false }
  }

  return {
    snapshot: snapshot,
    rates: { down: rxDelta * 1000 / elapsedMs, up: txDelta * 1000 / elapsedMs },
    reset: false
  }
}

// Unites decimales (1 kB = 1000 o), comme les debits annonces par les
// operateurs. Un debit inconnu (-1, absent) s'ecrit en tiret.
function formatRate(bytesPerSec) {
  var value = Number(bytesPerSec)
  if (bytesPerSec === undefined || bytesPerSec === null || !isFinite(value) || value < 0) return "—"
  if (value < 1000) return Math.round(value) + " B/s"
  var units = ["kB/s", "MB/s", "GB/s"]
  var index = -1
  while (value >= 1000 && index < units.length - 1) {
    value /= 1000
    index++
  }
  return value.toFixed(value < 10 ? 1 : 0) + " " + units[index]
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    MAX_SAMPLE_GAP_MS: MAX_SAMPLE_GAP_MS,
    parseNetDev: parseNetDev,
    nextThroughput: nextThroughput,
    formatRate: formatRate
  }
}
