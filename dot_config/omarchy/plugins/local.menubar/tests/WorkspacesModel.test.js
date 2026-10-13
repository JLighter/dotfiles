// Tests des libelles du switcher de workspaces. Sans dependance : `node --test tests/`.
//
// Les pastilles affichent leur numero en kanji (numeration japonaise
// traditionnelle) plutot qu'en chiffres arabes. Deux sources de numeros :
// les slots 1..slotsPerScreen de l'ecran, et l'identifiant reel d'un workspace
// hors tranche, qui peut depasser 10.

const assert = require("node:assert/strict")
const test = require("node:test")
const fs = require("node:fs")
const path = require("node:path")
const Module = require("node:module")

// Meme chargeur que CliampModel.test.js : node ne connait pas `.pragma library`.
const Model = (function loadModel() {
  const file = path.join(__dirname, "..", "WorkspacesModel.js")
  const source = fs.readFileSync(file, "utf8").replace(/^\s*\.pragma\s+\w+\s*$/gm, "")
  const module_ = new Module(file)
  module_.filename = file
  module_.paths = Module._nodeModulePaths(path.dirname(file))
  module_._compile(source, file)
  return module_.exports
})()

// --- AC-WS-01 : les slots 1..9 s'ecrivent avec un seul kanji -----------------

test("AC-WS-01 : les chiffres 1 a 9 deviennent 一 a 九", () => {
  const expected = ["一", "二", "三", "四", "五", "六", "七", "八", "九"]
  for (let n = 1; n <= 9; n++) assert.equal(Model.kanjiNumeral(n), expected[n - 1])
})

// --- AC-WS-02 : un identifiant hors tranche suit la numeration positionnelle --

test("AC-WS-02 : 10 s'ecrit 十, sans 一 devant", () => {
  assert.equal(Model.kanjiNumeral(10), "十")
})

test("AC-WS-02 : les dizaines composent multiplicateur et unites", () => {
  assert.equal(Model.kanjiNumeral(11), "十一")
  assert.equal(Model.kanjiNumeral(20), "二十")
  assert.equal(Model.kanjiNumeral(25), "二十五")
  assert.equal(Model.kanjiNumeral(99), "九十九")
})

test("AC-WS-02 : centaines et milliers omettent 一 et les rangs nuls", () => {
  assert.equal(Model.kanjiNumeral(100), "百")
  assert.equal(Model.kanjiNumeral(101), "百一")
  assert.equal(Model.kanjiNumeral(110), "百十")
  assert.equal(Model.kanjiNumeral(300), "三百")
  assert.equal(Model.kanjiNumeral(1000), "千")
  assert.equal(Model.kanjiNumeral(2024), "二千二十四")
  assert.equal(Model.kanjiNumeral(9999), "九千九百九十九")
})

test("AC-WS-02 : un rang nul au milieu du nombre ne s'ecrit pas", () => {
  assert.equal(Model.kanjiNumeral(1001), "千一")
  assert.equal(Model.kanjiNumeral(1010), "千十")
})

test("AC-WS-02 : aucun chiffre arabe ne subsiste sur tout le domaine 1..9999", () => {
  for (let n = 1; n <= 9999; n++) {
    const label = Model.kanjiNumeral(n)
    assert.match(label, /^[一二三四五六七八九十百千]+$/, n + " -> " + label)
  }
})

// --- AC-WS-03 : hors domaine, on garde le chiffre arabe -----------------------
//
// Un libelle vide rendrait la pastille muette ; une exception casserait toute
// la barre. On retombe donc sur l'ecriture d'origine.

test("AC-WS-03 : au-dela de 9999 le libelle reste en chiffres arabes", () => {
  assert.equal(Model.kanjiNumeral(10000), "10000")
})

test("AC-WS-03 : zero, negatifs et non-entiers restent en chiffres arabes", () => {
  assert.equal(Model.kanjiNumeral(0), "0")
  assert.equal(Model.kanjiNumeral(-3), "-3")
  assert.equal(Model.kanjiNumeral(1.5), "1.5")
  assert.equal(Model.kanjiNumeral(NaN), "NaN")
})

test("AC-WS-03 : une valeur absente ne leve pas et ne donne pas un libelle vide", () => {
  for (const value of [undefined, null]) {
    const label = Model.kanjiNumeral(value)
    assert.equal(typeof label, "string")
    assert.notEqual(label, "")
  }
})
