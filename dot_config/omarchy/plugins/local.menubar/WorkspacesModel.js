.pragma library

// Logique pure du switcher de workspaces : rien ici ne touche a QML ni a
// Hyprland, donc tout se teste avec un simple `node --test tests/`.

var DIGITS = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

// Rangs du plus fort au plus faible. Au-dela de 9999 il faudrait le groupement
// par 万 : aucun workspace n'y arrive, on s'arrete donc a 千.
var UNITS = [
  { value: 1000, kanji: "千" },
  { value: 100, kanji: "百" },
  { value: 10, kanji: "十" }
]

// Numeration japonaise traditionnelle : 11 -> 十一, 20 -> 二十, 2024 -> 二千二十四.
// Le 一 multiplicateur s'omet devant 十, 百 et 千 (10 -> 十, pas 一十), et un
// rang nul ne s'ecrit pas (101 -> 百一).
//
// Hors de 1..9999, ou pour un non-entier, on rend le chiffre arabe : un libelle
// vide rendrait la pastille muette, une exception casserait la barre entiere.
function kanjiNumeral(value) {
  if (typeof value !== "number" || value % 1 !== 0 || value < 1 || value > 9999) return String(value)

  var rest = value
  var text = ""

  for (var i = 0; i < UNITS.length; i++) {
    var count = Math.floor(rest / UNITS[i].value)
    rest -= count * UNITS[i].value
    if (count === 0) continue
    text += (count === 1 ? "" : DIGITS[count]) + UNITS[i].kanji
  }

  return text + DIGITS[rest]
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    kanjiNumeral: kanjiNumeral
  }
}
