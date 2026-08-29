.pragma library

// Logique pure du widget cliamp : tout ce qui transforme du texte en donnees.
// Rien ici ne touche a QML ni a Quickshell, donc tout se relit et se teste avec
// un simple `node`. C'est la partie qui casse quand cliamp change de version,
// et c'est pour ca qu'elle vit a part.
//
// Quatre formats a lire :
//   - le JSON du socket cliamp (`{"cmd":"status"}`, identique a
//     `cliamp status --json`) ;
//   - le JSON de `cliamp plugins call next-track next` ;
//   - les frames NDJSON de `cliamp visstream` ;
//   - `radio_favorites.toml`, un TOML minimal.

// --- Outils ------------------------------------------------------------------

// cliamp relaie les metadonnees ICY d'une radio sans les filtrer : un flux peut
// donc pousser n'importe quoi dans un titre. On retire les caracteres de
// controle, qui casseraient la mise en page du panneau.
function sanitize(value) {
  if (value === undefined || value === null) return ""
  return String(value).replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, "")
}

function toNumber(value, fallback) {
  var number = Number(value)
  return isFinite(number) ? number : fallback
}

// --- Etat de lecture ---------------------------------------------------------

// Toujours la meme forme, meme quand rien n'est lisible : les bindings QML ne
// doivent jamais tomber sur `undefined`, sinon le panneau se vide par a-coups.
function emptyStatus() {
  return {
    ok: false,
    state: "",
    playing: false,
    title: "",
    artist: "",
    album: "",
    path: "",
    stream: false,
    duration: 0,
    position: 0,
    volume: 0,
    hasVolume: false,
    shuffle: false,
    repeatMode: "Off",
    speed: 1,
    index: -1,
    total: 0,
    visualizer: ""
  }
}

// Le socket de cliamp repond en JSON indente : une reponse s'etale donc sur
// plusieurs lignes, et le lecteur qui decoupe sur « \n » n'en recoit que des
// morceaux. Cette fonction dit quand le tampon accumule tient enfin un objet
// complet — c'est le seul delimiteur fiable, cliamp n'en emettant aucun.
function isCompleteJson(text) {
  var value = String(text === undefined || text === null ? "" : text)
  var start = value.indexOf("{")
  if (start < 0) return false

  try {
    JSON.parse(value.slice(start))
    return true
  } catch (e) {
    return false
  }
}

// Renvoie null si la reponse n'est pas exploitable — l'appelant garde alors
// l'etat precedent plutot que d'afficher un panneau vide sur un hoquet du
// socket.
function parseStatus(raw) {
  var text = String(raw === undefined || raw === null ? "" : raw)

  // La CLI prefixe parfois le JSON d'une ligne d'avertissement ; on part de la
  // premiere accolade.
  var start = text.indexOf("{")
  if (start < 0) return null

  var data
  try {
    data = JSON.parse(text.slice(start))
  } catch (e) {
    return null
  }
  if (!data || data.ok !== true) return null

  var track = data.track || {}
  var status = emptyStatus()

  status.ok = true
  status.state = String(data.state || "")
  status.playing = status.state === "playing"
  status.title = sanitize(track.title)
  status.artist = sanitize(track.artist)
  status.album = sanitize(track.album)
  status.path = sanitize(track.path)
  status.stream = track.stream === true

  // La duree a change de place entre les versions de cliamp : `duration_secs`
  // dans la piste, `duration` a la racine. On accepte les deux.
  status.duration = Math.max(0, toNumber(track.duration_secs, toNumber(data.duration, 0)))
  status.position = Math.max(0, toNumber(data.position, 0))

  // Le volume est en dB et vaut legitimement 0 : il faut un drapeau pour
  // distinguer « zero dB » de « absent de la reponse ».
  var volume = Number(data.volume)
  if (isFinite(volume)) {
    status.volume = volume
    status.hasVolume = true
  }

  status.shuffle = data.shuffle === true
  status.repeatMode = data.repeat === undefined || data.repeat === null
    ? "Off"
    : String(data.repeat)
  status.speed = toNumber(data.speed, 1)
  status.index = Math.round(toNumber(data.index, -1))
  status.total = Math.round(toNumber(data.total, 0))
  status.visualizer = String(data.visualizer || "")

  return status
}

// Une piste n'est scrutable que si elle a une duree. Le drapeau `stream` ne
// sert a rien ici : cliamp le met aussi a vrai pour les pistes de bibliotheque
// servies en HTTP, qui elles se scrutent tres bien.
function isSeekable(status) {
  return !!status && status.duration > 0
}

// --- Piste suivante ----------------------------------------------------------
// `cliamp plugins call next-track next` renvoie {"shuffle": bool, "track": …}.
// En lecture aleatoire la suite est imprevisible et le plugin renvoie null :
// mieux vaut ne rien afficher qu'annoncer une piste qui ne viendra pas.

function parseNext(raw) {
  var text = String(raw === undefined || raw === null ? "" : raw)
  var start = text.indexOf("{")
  if (start < 0) return null

  var data
  try {
    data = JSON.parse(text.slice(start))
  } catch (e) {
    return null
  }
  if (!data || data.shuffle === true || !data.track) return null

  var title = sanitize(data.track.title)
  if (title === "") return null

  return {
    title: title,
    artist: sanitize(data.track.artist),
    album: sanitize(data.track.album)
  }
}

// --- Spectre -----------------------------------------------------------------
// `cliamp visstream` emet un objet JSON par ligne. Les frames en erreur
// (`ok: false`) sont ignorees : c'est ce que renvoie cliamp lance en mode
// daemon, ou la visualisation n'est pas calculee.

function parseBandFrame(line) {
  if (!line) return null

  try {
    var frame = JSON.parse(line)
    if (!frame || !frame.ok) return null
    return {
      bands: frame.bands || null,
      visualizer: frame.visualizer ? String(frame.visualizer) : ""
    }
  } catch (e) {
    // Ligne tronquee : la suivante arrivera dans 1/20 s.
    return null
  }
}

// --- Favoris radio -----------------------------------------------------------
// `radio_favorites.toml` est un TOML minimal : des blocs [[station]] suivis de
// `cle = "valeur"`. Pas de parseur TOML en QML, mais ce sous-ensemble se lit
// sans risque.

function parseFavorites(content) {
  var stations = []
  var current = null
  var lines = String(content || "").split("\n")

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line === "[[station]]") {
      current = ({})
      stations.push(current)
      continue
    }
    if (!current || line === "" || line.charAt(0) === "#") continue

    var match = line.match(/^([A-Za-z0-9_]+)\s*=\s*(.*)$/)
    if (!match) continue

    var value = match[2].trim()
    // Retire les guillemets ; les nombres (bitrate) restent tels quels.
    if (value.length >= 2 && value.charAt(0) === '"' && value.charAt(value.length - 1) === '"')
      value = value.substring(1, value.length - 1)
    current[match[1]] = value
  }

  // Une station sans URL n'est pas jouable : autant ne pas l'afficher.
  return stations.filter(function(station) { return !!station.url })
}

function favoriteNameFor(favorites, url) {
  if (!url) return ""

  var list = favorites || []
  for (var i = 0; i < list.length; i++) {
    if (String(list[i].url || "") === String(url)) return String(list[i].name || "")
  }
  return ""
}

// Tant qu'un flux n'a pas envoye ses metadonnees ICY, cliamp annonce son URL
// comme titre. On lui substitue alors le nom de la station, faute de quoi la
// barre afficherait « http://usa9.fastcast4u.com/proxy/… ».
function displayTitle(trackTitle, favoriteName) {
  var title = String(trackTitle || "")
  if (title !== "" && !/^https?:\/\//.test(title)) return title
  if (favoriteName) return String(favoriteName)
  return title !== "" ? "Radio" : ""
}

// --- Mise en forme -----------------------------------------------------------

function formatTime(seconds) {
  if (!isFinite(seconds) || seconds < 0) return "--:--"

  var total = Math.floor(seconds)
  var minutes = Math.floor(total / 60)
  var rest = total % 60
  return minutes + ":" + (rest < 10 ? "0" : "") + rest
}

// Le TOML des favoris porte codec et debit ; ni l'un ni l'autre n'est garanti.
function stationSubtitle(station) {
  if (!station) return ""

  var parts = []
  if (station.codec) parts.push(String(station.codec))
  if (station.bitrate) parts.push(String(station.bitrate) + " kb/s")
  return parts.join(" · ")
}

// Rend le module utilisable par `node` pour les tests, sans gener QML : sous
// Quickshell `module` n'existe pas et le bloc est simplement saute.
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    sanitize: sanitize,
    emptyStatus: emptyStatus,
    isCompleteJson: isCompleteJson,
    parseStatus: parseStatus,
    isSeekable: isSeekable,
    parseNext: parseNext,
    parseBandFrame: parseBandFrame,
    parseFavorites: parseFavorites,
    favoriteNameFor: favoriteNameFor,
    displayTitle: displayTitle,
    formatTime: formatTime,
    stationSubtitle: stationSubtitle
  }
}
