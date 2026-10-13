.pragma library

// Logique pure du widget System : lecture de /proc, de `df` et de `nvidia-smi`,
// fenetre d'historique (aussi utilisee par le graphe de debit du widget
// Network). Rien ici ne touche a QML, donc tout se teste avec `node`.
//
// Porte de omarchy-system-monitor (Harshith Chennupati, MIT, voir NOTICE), Metrics.js au
// commit 71599f7. Retires : capteurs Apple Silicon et ventilateurs (materiel
// absent ici), lecture GPU par sysfs (amdgpu/i915) au profit de nvidia-smi,
// echappement de tooltip (le widget n'en a pas), lecture reseau (le debit vient
// de omarchy-network-status dans le widget Network).

// Deux minutes d'historique, et un plafond de points au cas ou la cadence
// s'emballerait.
var HISTORY_WINDOW_MS = 120000
var HISTORY_MAX_POINTS = 130

// Number("") et Number(null) valent 0 : sans ce garde, un champ absent
// passerait pour une mesure nulle.
function finiteNumber(value, fallback) {
  if (value === undefined || value === null || String(value).trim() === "") return fallback
  var number = Number(value)
  return isFinite(number) ? number : fallback
}

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value))
}

// /proc/stat ne donne que des cumuls depuis le demarrage : la charge est la
// part non oisive de l'ecart entre deux releves. `previous` est le `snapshot`
// rendu par l'appel precedent.
function parseCpu(raw, previous) {
  var lines = String(raw || "").split("\n")
  var snapshots = ({})
  var usages = ({})

  for (var i = 0; i < lines.length; i++) {
    var fields = lines[i].trim().split(/\s+/)
    if (!/^cpu\d*$/.test(fields[0] || "")) continue

    var values = []
    for (var field = 1; field <= 8; field++) values.push(finiteNumber(fields[field], 0))
    var total = 0
    for (var value = 0; value < values.length; value++) total += values[value]
    var idle = values[3] + values[4]
    snapshots[fields[0]] = { total: total, idle: idle }

    var before = previous ? previous[fields[0]] : null
    if (!before) continue
    var totalDelta = total - before.total
    var idleDelta = idle - before.idle
    if (totalDelta <= 0 || idleDelta < 0) continue
    usages[fields[0]] = clamp((totalDelta - idleDelta) * 100 / totalDelta, 0, 100)
  }

  var cores = []
  var labels = Object.keys(usages).filter(function(label) { return label !== "cpu" })
  labels.sort(function(a, b) { return Number(a.slice(3)) - Number(b.slice(3)) })
  for (var core = 0; core < labels.length; core++) {
    cores.push({ name: labels[core].toUpperCase(), percent: usages[labels[core]] })
  }

  return {
    snapshot: snapshots,
    overall: usages.cpu === undefined ? -1 : usages.cpu,
    cores: cores
  }
}

// MemAvailable, et non MemFree : le cache reclamable ne compte pas comme occupe.
function parseMemory(raw) {
  var values = ({})
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^([A-Za-z_()]+):\s+(\d+)/)
    if (match) values[match[1]] = Number(match[2]) * 1024
  }

  var total = values.MemTotal || 0
  var available = values.MemAvailable || 0
  var used = total > 0 ? Math.max(0, total - available) : 0
  var swapTotal = values.SwapTotal || 0
  var swapUsed = Math.max(0, swapTotal - (values.SwapFree || 0))
  return {
    total: total,
    used: used,
    percent: total > 0 ? clamp(used * 100 / total, 0, 100) : -1,
    swapTotal: swapTotal,
    swapUsed: swapUsed,
    swapPercent: swapTotal > 0 ? clamp(swapUsed * 100 / swapTotal, 0, 100) : -1
  }
}

function parseLoad(raw) {
  var fields = String(raw || "").trim().split(/\s+/)
  return {
    one: finiteNumber(fields[0], -1),
    five: finiteNumber(fields[1], -1),
    fifteen: finiteNumber(fields[2], -1)
  }
}

function parseUptime(raw) {
  return Math.max(0, finiteNumber(String(raw || "").trim().split(/\s+/)[0], 0))
}

// /proc/diskstats compte en secteurs de 512 octets, quelle que soit la taille
// physique des secteurs du peripherique.
function parseDisk(raw, devices) {
  var wanted = ({})
  for (var i = 0; i < devices.length; i++) wanted[String(devices[i])] = true
  var readSectors = 0
  var writeSectors = 0
  var found = false
  var lines = String(raw || "").split("\n")

  for (var line = 0; line < lines.length; line++) {
    var fields = lines[line].trim().split(/\s+/)
    if (fields.length < 10 || !wanted[fields[2]]) continue
    readSectors += finiteNumber(fields[5], 0)
    writeSectors += finiteNumber(fields[9], 0)
    found = true
  }

  return found ? { readBytes: readSectors * 512, writeBytes: writeSectors * 512 } : null
}

// Sortie de `system_discover.sh` : une cle et une valeur par ligne, separees
// par une tabulation.
function parseDiscovery(raw) {
  var result = { cpuTempPath: "", gpuSmiPath: "", devices: [] }
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var separator = lines[i].indexOf("\t")
    if (separator < 0) continue
    var key = lines[i].slice(0, separator)
    var value = lines[i].slice(separator + 1).trim()
    if (key === "cpu_temp") result.cpuTempPath = value
    else if (key === "gpu_smi") result.gpuSmiPath = value
    else if (key === "disk" && value !== "") result.devices.push(value)
  }
  return result
}

// Le pilote NVIDIA proprietaire n'expose rien dans sysfs, pas meme la
// temperature : tout passe par nvidia-smi, interroge avec
//   --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total
//   --format=csv,noheader,nounits
// Un champ que la carte ne renseigne pas ressort a « [N/A] » et devient -1, pour
// que le panneau affiche un tiret plutot qu'un faux zero. Une sortie illisible
// (pilote absent, message d'erreur) ne rend aucune carte.
function parseNvidiaGpu(raw) {
  var line = String(raw || "").split("\n")[0]
  var fields = line.split(",").map(function(field) { return field.trim() })
  if (fields.length < 4) return null

  function reading(text) {
    if (!/^[0-9]+(\.[0-9]+)?$/.test(text)) return -1
    return Number(text)
  }

  var percent = reading(fields[0])
  var temperature = reading(fields[1])
  var usedMib = reading(fields[2])
  var totalMib = reading(fields[3])
  if (percent < 0 && temperature < 0 && usedMib < 0 && totalMib < 0) return null

  return {
    percent: percent < 0 ? -1 : clamp(percent, 0, 100),
    temperature: temperature,
    vramUsed: usedMib < 0 ? -1 : usedMib * 1048576,
    vramTotal: totalMib < 0 ? -1 : totalMib * 1048576
  }
}

// Types de systemes de fichiers sur disque qui meritent une ligne de capacite.
// Une liste blanche ecarte la foule des pseudo-systemes (tmpfs, overlay,
// squashfs, cgroup...) sans avoir a les nommer ; `df -l` a deja ecarte les
// montages reseau.
var CAPACITY_FILESYSTEMS = {
  ext2: true, ext3: true, ext4: true, btrfs: true, xfs: true, f2fs: true,
  zfs: true, jfs: true, reiserfs: true, nilfs2: true, bcachefs: true,
  vfat: true, exfat: true, ntfs: true, ntfs3: true, hfsplus: true, ufs: true
}

// Lit `df -P -k -l -T` :
//   Filesystem  Type  1024-blocks  Used  Available  Capacity  Mounted on
// Une entree { mount, total, used, percent } par peripherique, dans l'ordre de
// df, en octets ; percent vaut -1 pour un total nul. La racine est toujours
// gardee ; les autres lignes doivent etre d'un type sur disque. Les lignes
// d'un meme peripherique (sous-volumes btrfs, bind mounts) se replient sur le
// chemin le plus court : elles annoncent le meme espace libre.
function parseFilesystems(raw) {
  var lines = String(raw || "").trim().split("\n")
  var byDevice = ({})
  var order = []

  for (var i = 1; i < lines.length; i++) {
    var fields = lines[i].trim().split(/\s+/)
    if (fields.length < 7) continue
    var device = fields[0]
    var type = fields[1]
    var mount = fields.slice(6).join(" ")
    if (mount !== "/" && !CAPACITY_FILESYSTEMS[type]) continue

    var total = finiteNumber(fields[2], 0) * 1024
    var used = finiteNumber(fields[3], 0) * 1024
    var entry = {
      mount: mount,
      total: total,
      used: used,
      percent: total > 0 ? clamp(used * 100 / total, 0, 100) : -1
    }

    var seen = byDevice[device]
    if (!seen) {
      byDevice[device] = entry
      order.push(device)
    } else if (mount.length < seen.mount.length) {
      byDevice[device] = entry
    }
  }

  var result = []
  for (var d = 0; d < order.length; d++) result.push(byDevice[order[d]])
  return result
}

// Ajoute un point a une serie et oublie ce qui sort de la fenetre. Rend un
// nouveau tableau : muter en place ne notifierait pas les bindings QML.
function appendHistory(current, timestamp, value) {
  if (!isFinite(value) || value < 0) return current
  var cutoff = timestamp - HISTORY_WINDOW_MS
  var next = []
  for (var i = 0; i < current.length; i++) {
    if (current[i].time >= cutoff) next.push(current[i])
  }
  next.push({ time: timestamp, value: value })
  if (next.length > HISTORY_MAX_POINTS) next = next.slice(next.length - HISTORY_MAX_POINTS)
  return next
}

// Pic d'une fenetre glissante, pour fixer l'echelle d'un graphe : le trace et
// l'echelle imprimee a cote disent alors le meme nombre.
function peakValue(history) {
  var peak = 0
  if (!history) return peak
  for (var i = 0; i < history.length; i++) {
    var value = Number(history[i].value)
    if (isFinite(value) && value > peak) peak = value
  }
  return peak
}

function maximumPercent(cores) {
  var peak = -1
  if (!cores) return peak
  for (var i = 0; i < cores.length; i++) {
    var value = Number(cores[i].percent)
    if (isFinite(value) && value > peak) peak = value
  }
  return peak
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    HISTORY_WINDOW_MS: HISTORY_WINDOW_MS,
    parseCpu: parseCpu,
    parseMemory: parseMemory,
    parseLoad: parseLoad,
    parseUptime: parseUptime,
    parseDisk: parseDisk,
    parseDiscovery: parseDiscovery,
    parseNvidiaGpu: parseNvidiaGpu,
    parseFilesystems: parseFilesystems,
    appendHistory: appendHistory,
    peakValue: peakValue,
    maximumPercent: maximumPercent
  }
}
