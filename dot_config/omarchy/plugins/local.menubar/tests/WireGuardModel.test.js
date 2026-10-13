// Tests du modele WireGuard. Sans dependance : `node --test tests/`.
//
// Le modele ne voit que ce que renvoie `wireguard-backend.py status` : une liste
// de profils { uuid, name, state, device, counters }. Les etats sont ceux de
// NetworkManager (`activated`, `activating`, `deactivating`, `deactivated`).

const assert = require("node:assert/strict")
const test = require("node:test")
const fs = require("node:fs")
const path = require("node:path")
const Module = require("node:module")

// Meme chargeur que CliampModel.test.js : node ne connait pas `.pragma library`.
const Model = (function loadModel() {
  const file = path.join(__dirname, "..", "WireGuardModel.js")
  const source = fs.readFileSync(file, "utf8").replace(/^\s*\.pragma\s+\w+\s*$/gm, "")
  const module_ = new Module(file)
  module_.filename = file
  module_.paths = Module._nodeModulePaths(path.dirname(file))
  module_._compile(source, file)
  return module_.exports
})()

function profile(uuid, state, extra) {
  return Object.assign({ uuid: uuid, name: "tunnel-" + uuid, state: state, device: "", counters: null }, extra || {})
}

// --- AC-WG-04 : debit et ligne de base ----------------------------------------

test("AC-WG-04 : le premier echantillon pose une ligne de base a debit nul", () => {
  const point = Model.sample(null, { device: "wg0", counters: { rx: 5000, tx: 300 } }, 10)
  assert.deepEqual(point, { time: 10, device: "wg0", rx: 5000, tx: 300, down: 0, up: 0 })
})

test("AC-WG-04 : le debit est la difference des compteurs sur le temps ecoule", () => {
  const previous = { time: 10, device: "wg0", rx: 1000, tx: 500, down: 0, up: 0 }
  const point = Model.sample(previous, { device: "wg0", counters: { rx: 5000, tx: 1500 } }, 12)
  assert.equal(point.down, 2000)
  assert.equal(point.up, 500)
})

test("AC-WG-04 : un changement d'interface repart de zero", () => {
  const previous = { time: 10, device: "wg0", rx: 1000, tx: 500, down: 0, up: 0 }
  const point = Model.sample(previous, { device: "wg-1234", counters: { rx: 9000, tx: 9000 } }, 12)
  assert.equal(point.down, 0)
  assert.equal(point.up, 0)
  assert.equal(point.device, "wg-1234")
})

test("AC-WG-04 : un compteur qui recule repart de zero au lieu d'un debit negatif", () => {
  const previous = { time: 10, device: "wg0", rx: 9000, tx: 500, down: 0, up: 0 }
  const point = Model.sample(previous, { device: "wg0", counters: { rx: 100, tx: 600 } }, 12)
  assert.equal(point.down, 0)
  assert.equal(point.up, 0)
})

test("AC-WG-04 : un trou de 15 s ou plus repart de zero", () => {
  const previous = { time: 10, device: "wg0", rx: 0, tx: 0, down: 0, up: 0 }
  const point = Model.sample(previous, { device: "wg0", counters: { rx: 15000, tx: 15000 } }, 25)
  assert.equal(point.down, 0)
  assert.equal(point.up, 0)
})

test("AC-WG-04 : un temps qui ne progresse pas ne divise pas par zero", () => {
  const previous = { time: 10, device: "wg0", rx: 0, tx: 0, down: 0, up: 0 }
  const point = Model.sample(previous, { device: "wg0", counters: { rx: 100, tx: 100 } }, 10)
  assert.equal(point.down, 0)
  assert.equal(point.up, 0)
})

test("AC-WG-04 : un tunnel sans compteurs donne un point nul sans interface", () => {
  const previous = { time: 10, device: "wg0", rx: 1000, tx: 500, down: 0, up: 0 }
  assert.deepEqual(Model.sample(previous, { device: "", counters: null }, 12),
    { time: 12, device: "", rx: 0, tx: 0, down: 0, up: 0 })
  assert.deepEqual(Model.sample(previous, null, 12),
    { time: 12, device: "", rx: 0, tx: 0, down: 0, up: 0 })
})

test("AC-WG-04 : la fenetre garde les 30 derniers points (60 s a 2 s)", () => {
  let history = []
  for (let i = 0; i < 35; i++) history = Model.pushWindow(history, { time: i })
  assert.equal(history.length, Model.WINDOW_SIZE)
  assert.equal(Model.WINDOW_SIZE, 30)
  assert.equal(history[0].time, 5)
  assert.equal(history[29].time, 34)
})

test("AC-WG-04 : pushWindow ne modifie pas le tableau recu", () => {
  const history = [{ time: 1 }]
  const next = Model.pushWindow(history, { time: 2 })
  assert.equal(history.length, 1)
  assert.notEqual(next, history)
})

// --- AC-WG-06 / AC-WG-N3 : coupures ------------------------------------------

test("AC-WG-06 : un tunnel actif qui tombe sans action est signale", () => {
  const previous = [profile("a", "activated")]
  const current = [profile("a", "deactivated")]
  assert.deepEqual(Model.dropped(previous, current, {}).map(p => p.uuid), ["a"])
})

test("AC-WG-06 : un tunnel actif qui disparait de la liste est signale", () => {
  const previous = [profile("a", "activated")]
  assert.deepEqual(Model.dropped(previous, [], {}).map(p => p.uuid), ["a"])
})

test("AC-WG-06 : la fin d'une desactivation non demandee est signalee", () => {
  const previous = [profile("a", "deactivating")]
  const current = [profile("a", "deactivated")]
  assert.deepEqual(Model.dropped(previous, current, {}).map(p => p.uuid), ["a"])
})

test("AC-WG-N3 : rien au premier releve", () => {
  assert.deepEqual(Model.dropped(null, [profile("a", "deactivated")], {}), [])
})

test("AC-WG-N3 : rien apres un down demande ou un tunnel coupe par la bascule", () => {
  const previous = [profile("a", "activated"), profile("b", "activated")]
  const current = [profile("a", "deactivated"), profile("b", "deactivated")]
  assert.deepEqual(Model.dropped(previous, current, { a: true, b: true }), [])
})

test("AC-WG-N3 : rien pendant un etat transitoire", () => {
  const previous = [profile("a", "activated"), profile("b", "activated")]
  const current = [profile("a", "activating"), profile("b", "deactivating")]
  assert.deepEqual(Model.dropped(previous, current, {}), [])
})

test("AC-WG-N3 : une activation qui echoue n'est pas une coupure", () => {
  const previous = [profile("a", "activating")]
  const current = [profile("a", "deactivated")]
  assert.deepEqual(Model.dropped(previous, current, {}), [])
})

test("AC-WG-N3 : un tunnel deja inactif ne produit rien", () => {
  const previous = [profile("a", "deactivated")]
  const current = [profile("a", "deactivated")]
  assert.deepEqual(Model.dropped(previous, current, {}), [])
})

// --- AC-WG-01 : etat affiche ---------------------------------------------------

test("AC-WG-01 : seul `activated` compte comme actif", () => {
  assert.equal(Model.isUp("activated"), true)
  for (const state of ["activating", "deactivating", "deactivated", "", undefined])
    assert.equal(Model.isUp(state), false, String(state))
})

test("AC-WG-01 : activeNames liste les tunnels actifs dans l'ordre recu", () => {
  const profiles = [profile("a", "activated", { name: "maison" }), profile("b", "deactivated"),
    profile("c", "activated", { name: "travail" })]
  assert.deepEqual(Model.activeNames(profiles), ["maison", "travail"])
  assert.deepEqual(Model.activeNames(null), [])
})

// --- Affichage du debit --------------------------------------------------------

test("formatRate suit le format du panneau reseau", () => {
  assert.equal(Model.formatRate(0), "0 B/s")
  assert.equal(Model.formatRate(512.4), "512 B/s")
  assert.equal(Model.formatRate(1536), "1.5 kB/s")
  assert.equal(Model.formatRate(20480), "20 kB/s")
  assert.equal(Model.formatRate(3 * 1024 * 1024), "3.0 MB/s")
  assert.equal(Model.formatRate(undefined), "0 B/s")
})
