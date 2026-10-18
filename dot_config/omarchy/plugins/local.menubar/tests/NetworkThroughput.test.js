// Tests du modele de debit du widget Network. Sans dependance : `node --test tests/`.
//
// Le debit vient de /proc/net/dev, lu au moment du releve : l'instant passe au
// modele est celui de la lecture des compteurs, jamais celui de la fin d'un
// processus plus lent (le helper de statut pingue apres avoir lu ses compteurs).

const assert = require("node:assert/strict")
const test = require("node:test")
const fs = require("node:fs")
const path = require("node:path")
const Module = require("node:module")

// Meme chargeur que CliampModel.test.js : node ne connait pas `.pragma library`.
const Model = (function loadModel() {
  const file = path.join(__dirname, "..", "NetworkThroughput.js")
  const source = fs.readFileSync(file, "utf8").replace(/^\s*\.pragma\s+\w+\s*$/gm, "")
  const module_ = new Module(file)
  module_.filename = file
  module_.paths = Module._nodeModulePaths(path.dirname(file))
  module_._compile(source, file)
  return module_.exports
})()

const netDev = [
  "Inter-|   Receive                                                |  Transmit",
  " face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed",
  "    lo: 1000 10 0 0 0 0 0 0 1000 10 0 0 0 0 0 0",
  "  eno1: 5000 20 0 0 0 0 0 0 7000 30 0 0 0 0 0 0"
].join("\n")

// --- AC-NET-01 : compteurs de l'interface active --------------------------------

test("AC-NET-01 : les compteurs suivent l'interface demandee", () => {
  assert.deepEqual(Model.parseNetDev(netDev, "eno1"), { rx: 5000, tx: 7000 })
})

test("AC-NET-01 : interface absente, non nommee ou ligne tronquee : aucun compteur", () => {
  assert.equal(Model.parseNetDev(netDev, "wlan0"), null)
  assert.equal(Model.parseNetDev(netDev, ""), null)
  assert.equal(Model.parseNetDev("eno1: 5000 20 0", "eno1"), null)
  assert.equal(Model.parseNetDev("", "eno1"), null)
})

// --- AC-NET-02 : debit entre deux releves ---------------------------------------

function step(previous, rx, tx, iface, timeMs) {
  return Model.nextThroughput(previous, { rx: rx, tx: tx }, iface, timeMs)
}

test("AC-NET-02 : le debit est l'ecart de compteurs sur l'ecart de temps de lecture", () => {
  const first = step(null, 1000, 2000, "eno1", 0)
  assert.equal(first.rates, null)
  const second = step(first.snapshot, 4000, 2500, "eno1", 1500)
  assert.deepEqual(second.rates, { down: 2000, up: 1000 / 3 })
  assert.equal(second.reset, false)
})

test("AC-NET-02 : un compteur qui recule (reinitialisation) ne fabrique pas de point", () => {
  const first = step(null, 9000, 9000, "eno1", 0)
  const second = step(first.snapshot, 100, 9500, "eno1", 1500)
  assert.equal(second.rates, null)
  // Le releve suivant repart de la nouvelle base.
  assert.deepEqual(step(second.snapshot, 1600, 11000, "eno1", 3000).rates, { down: 1000, up: 1000 })
})

test("AC-NET-02 : un ecart de 30 s ou plus (veille) n'est pas un debit", () => {
  const first = step(null, 0, 0, "eno1", 0)
  assert.equal(step(first.snapshot, 30000, 30000, "eno1", 30000).rates, null)
  assert.notEqual(step(first.snapshot, 29000, 29000, "eno1", 29000).rates, null)
})

test("AC-NET-02 : un ecart de temps nul ou negatif n'est pas un debit", () => {
  const first = step(null, 0, 0, "eno1", 1000)
  assert.equal(step(first.snapshot, 10, 10, "eno1", 1000).rates, null)
  assert.equal(step(first.snapshot, 10, 10, "eno1", 900).rates, null)
})

test("AC-NET-02 : changer d'interface repart de zero et demande d'effacer l'historique", () => {
  const first = step(null, 1000, 1000, "eno1", 0)
  const switched = step(first.snapshot, 50, 50, "wlan0", 1500)
  assert.equal(switched.rates, null)
  assert.equal(switched.reset, true)
  assert.equal(switched.snapshot.iface, "wlan0")
})

test("AC-NET-02 : sans compteurs (lien tombe), plus de base ni de debit", () => {
  const first = step(null, 1000, 1000, "eno1", 0)
  const lost = Model.nextThroughput(first.snapshot, null, "eno1", 1500)
  assert.equal(lost.snapshot, null)
  assert.equal(lost.rates, null)
  assert.equal(lost.reset, true)
})

// --- AC-NET-03 : affichage ------------------------------------------------------

test("AC-NET-03 : debit en unites decimales, jusqu'au Go/s", () => {
  assert.equal(Model.formatRate(512), "512 B/s")
  assert.equal(Model.formatRate(2500), "2.5 kB/s")
  assert.equal(Model.formatRate(250000), "250 kB/s")
  assert.equal(Model.formatRate(1500000), "1.5 MB/s")
  assert.equal(Model.formatRate(2300000000), "2.3 GB/s")
})

test("AC-NET-03 : un debit inconnu s'affiche en tiret, jamais en faux zero", () => {
  assert.equal(Model.formatRate(-1), "—")
  assert.equal(Model.formatRate(NaN), "—")
  assert.equal(Model.formatRate(undefined), "—")
  assert.equal(Model.formatRate(0), "0 B/s")
})
