// Tests du modele du widget System. Sans dependance : `node --test tests/`.
//
// Les fixtures reprennent le format exact de /proc, de `df -P -k -l -T` et de
// `nvidia-smi --format=csv,noheader,nounits`. Les cas /proc et df viennent de
// omarchy-system-monitor (Harshith Chennupati, MIT), d'ou le modele est porte.

const assert = require("node:assert/strict")
const test = require("node:test")
const fs = require("node:fs")
const path = require("node:path")
const Module = require("node:module")

// Meme chargeur que CliampModel.test.js : node ne connait pas `.pragma library`.
const Model = (function loadModel() {
  const file = path.join(__dirname, "..", "SystemMetrics.js")
  const source = fs.readFileSync(file, "utf8").replace(/^\s*\.pragma\s+\w+\s*$/gm, "")
  const module_ = new Module(file)
  module_.filename = file
  module_.paths = Module._nodeModulePaths(path.dirname(file))
  module_._compile(source, file)
  return module_.exports
})()

// --- Processeur ----------------------------------------------------------------

const previousStat = [
  "cpu  3000 0 4000 400000 0 0 0 0 0 0",
  "cpu0 900 0 450 95000 0 0 0 0 0 0",
  "cpu1 700 0 350 85000 0 0 0 0 0 0"
].join("\n")

const sampleStat = [
  "cpu  3357 0 4323 422382 0 0 0 0 0 0",
  "cpu0 1000 0 500 100000 0 0 0 0 0 0",
  "cpu1 800 0 400 90000 0 0 0 0 0 0"
].join("\n")

test("cpu : la charge se deduit de deux releves consecutifs, globale et par coeur", () => {
  const parsed = Model.parseCpu(sampleStat, Model.parseCpu(previousStat, null).snapshot)
  // (357 + 323) occupes sur (357 + 323 + 22382) ecoules.
  assert.equal(parsed.overall.toFixed(3), (680 * 100 / 23062).toFixed(3))
  assert.deepEqual(parsed.cores.map(core => core.name), ["CPU0", "CPU1"])
  assert.ok(parsed.cores.every(core => core.percent >= 0 && core.percent <= 100))
})

test("cpu : un premier releve, sans precedent, ne pretend aucune charge", () => {
  const parsed = Model.parseCpu(sampleStat, null)
  assert.equal(parsed.overall, -1)
  assert.deepEqual(parsed.cores, [])
  assert.ok(parsed.snapshot.cpu)
})

test("cpu : un compteur qui recule (reboot, debordement) n'est pas une mesure", () => {
  const parsed = Model.parseCpu(previousStat, Model.parseCpu(sampleStat, null).snapshot)
  assert.equal(parsed.overall, -1)
  assert.deepEqual(parsed.cores, [])
})

test("cpu : les coeurs se trient numeriquement, cpu10 apres cpu2", () => {
  const lines = n => ["cpu 1 0 1 " + n + " 0 0 0 0"]
    .concat(["cpu10", "cpu2", "cpu1"].map(name => name + " 1 0 1 " + n + " 0 0 0 0"))
    .join("\n")
  const parsed = Model.parseCpu(lines(200), Model.parseCpu(lines(100), null).snapshot)
  assert.deepEqual(parsed.cores.map(core => core.name), ["CPU1", "CPU2", "CPU10"])
})

// --- Memoire -------------------------------------------------------------------

test("memoire : les kio de meminfo deviennent des octets, l'occupe exclut le cache", () => {
  const parsed = Model.parseMemory([
    "MemTotal:       16384000 kB",
    "MemFree:         1000000 kB",
    "MemAvailable:    8192000 kB",
    "SwapTotal:       4194304 kB",
    "SwapFree:        2097152 kB"
  ].join("\n"))
  assert.equal(parsed.total, 16384000 * 1024)
  assert.equal(parsed.used, 8192000 * 1024)
  assert.equal(parsed.percent, 50)
  assert.equal(parsed.swapPercent, 50)
})

test("memoire : sans swap ni total lisible, les pourcentages valent -1 et non 0", () => {
  const parsed = Model.parseMemory("")
  assert.equal(parsed.percent, -1)
  assert.equal(parsed.swapPercent, -1)
  assert.equal(parsed.swapTotal, 0)
})

// --- Charge et uptime ----------------------------------------------------------

test("loadavg et uptime se lisent tels quels, une entree illisible vaut -1 ou 0", () => {
  assert.deepEqual(Model.parseLoad("0.52 0.58 0.59 1/389 12345\n"), { one: 0.52, five: 0.58, fifteen: 0.59 })
  assert.deepEqual(Model.parseLoad(""), { one: -1, five: -1, fifteen: -1 })
  assert.equal(Model.parseUptime("12345.67 98765.43\n"), 12345.67)
  assert.equal(Model.parseUptime("garbage"), 0)
})

// --- Disque --------------------------------------------------------------------

const diskStats = [
  " 259       0 nvme0n1 100 0 2000 0 50 0 4000 0 0 0 0",
  " 259       1 nvme0n1p1 10 0 200 0 5 0 400 0 0 0 0",
  "   8       0 sda 10 0 100 0 10 0 300 0 0 0 0"
].join("\n")

test("disque : seuls les peripheriques decouverts comptent, en secteurs de 512 o", () => {
  assert.deepEqual(Model.parseDisk(diskStats, ["nvme0n1"]), { readBytes: 2000 * 512, writeBytes: 4000 * 512 })
  assert.deepEqual(Model.parseDisk(diskStats, ["nvme0n1", "sda"]), { readBytes: 2100 * 512, writeBytes: 4300 * 512 })
})

test("disque : aucun peripherique connu ne rend rien plutot qu'un debit nul", () => {
  assert.equal(Model.parseDisk(diskStats, []), null)
  assert.equal(Model.parseDisk(diskStats, ["mmcblk0"]), null)
})

// --- Decouverte ----------------------------------------------------------------

test("decouverte : sonde de temperature CPU et disques physiques", () => {
  const parsed = Model.parseDiscovery([
    "cpu_temp\t/sys/class/hwmon/hwmon4/temp1_input",
    "disk\tnvme0n1",
    "disk\tnvme1n1"
  ].join("\n"))
  assert.equal(parsed.cpuTempPath, "/sys/class/hwmon/hwmon4/temp1_input")
  assert.deepEqual(parsed.devices, ["nvme0n1", "nvme1n1"])
})

test("decouverte : cles inconnues, lignes sans tabulation et disques vides ignores", () => {
  const parsed = Model.parseDiscovery([
    "gpu_busy\t/sys/class/drm/card0/device/gpu_busy_percent",
    "cpu_temp /sans/tabulation",
    "disk\t",
    ""
  ].join("\n"))
  assert.deepEqual(parsed, { cpuTempPath: "", gpuSmiPath: "", devices: [] })
})

test("decouverte : nvidia-smi n'est retenu que s'il a ete trouve", () => {
  assert.equal(Model.parseDiscovery("gpu_smi\t/usr/bin/nvidia-smi\n").gpuSmiPath, "/usr/bin/nvidia-smi")
  assert.equal(Model.parseDiscovery("disk\tsda\n").gpuSmiPath, "")
})

// --- GPU (nvidia-smi) ----------------------------------------------------------

test("gpu : nvidia-smi rend charge, temperature et VRAM en Mio", () => {
  assert.deepEqual(Model.parseNvidiaGpu("37, 54, 1024, 8192\n"), {
    percent: 37,
    temperature: 54,
    vramUsed: 1024 * 1048576,
    vramTotal: 8192 * 1048576
  })
})

test("gpu : un champ [N/A] vaut -1, les autres restent lisibles", () => {
  const parsed = Model.parseNvidiaGpu("[N/A], 61, [N/A], 8192\n")
  assert.equal(parsed.percent, -1)
  assert.equal(parsed.temperature, 61)
  assert.equal(parsed.vramUsed, -1)
  assert.equal(parsed.vramTotal, 8192 * 1048576)
})

test("gpu : une sortie vide, tronquee ou un message d'erreur ne rend aucune carte", () => {
  assert.equal(Model.parseNvidiaGpu(""), null)
  assert.equal(Model.parseNvidiaGpu("37, 54\n"), null)
  assert.equal(Model.parseNvidiaGpu("NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver.\n"), null)
})

test("gpu : seule la premiere carte compte, la charge est bornee a 100", () => {
  assert.equal(Model.parseNvidiaGpu("140, 50, 1, 2\n5, 40, 1, 2\n").percent, 100)
})

// --- Capacite ------------------------------------------------------------------

const dfHeader = "Filesystem       Type     1024-blocks      Used Available Capacity Mounted on"

test("capacite : disques locaux reels, pseudo-systemes de fichiers ecartes", () => {
  const rows = Model.parseFilesystems([
    dfHeader,
    "/dev/mapper/root btrfs      486270976 155857108 326760620      33% /",
    "tmpfs            tmpfs       16363224         0  16363224       0% /dev",
    "efivarfs         efivarfs         192       102        86      55% /sys/firmware/efi/efivars",
    "/dev/mapper/data btrfs      976744448 230469684 744539180      24% /mnt/data",
    "/dev/nvme0n1p1   vfat         2093048    517272   1575776      25% /boot"
  ].join("\n"))
  assert.deepEqual(rows.map(row => row.mount), ["/", "/mnt/data", "/boot"])
  assert.equal(rows[0].total, 486270976 * 1024)
  assert.equal(rows[0].used, 155857108 * 1024)
})

test("capacite : les sous-volumes d'un meme peripherique se replient sur le chemin le plus court", () => {
  const rows = Model.parseFilesystems([
    dfHeader,
    "/dev/mapper/root btrfs 100 50 50 50% /home",
    "/dev/mapper/root btrfs 100 50 50 50% /",
    "/dev/mapper/root btrfs 100 50 50 50% /var/log"
  ].join("\n"))
  assert.deepEqual(rows.map(row => row.mount), ["/"])
})

test("capacite : la racine reste meme sous un type inconnu, un total nul vaut -1", () => {
  const rows = Model.parseFilesystems([
    dfHeader,
    "overlay overlay 0 0 0 - /",
    "/dev/sdb1 ext4 0 0 0 - /mnt/vide"
  ].join("\n"))
  assert.deepEqual(rows.map(row => row.mount), ["/", "/mnt/vide"])
  assert.ok(rows.every(row => row.percent === -1))
})

test("capacite : un point de montage avec espaces garde son nom entier", () => {
  const rows = Model.parseFilesystems([dfHeader, "/dev/sdc1 exfat 100 25 75 25% /run/media/Mon Disque"].join("\n"))
  assert.equal(rows[0].mount, "/run/media/Mon Disque")
})

test("capacite : une sortie df vide ne rend aucune ligne", () => {
  assert.deepEqual(Model.parseFilesystems(""), [])
})

// --- Historique ----------------------------------------------------------------

test("historique : le pic d'une fenetre ignore les valeurs illisibles", () => {
  assert.equal(Model.peakValue([{ value: 3 }, { value: "x" }, { value: 9 }, { value: 4 }]), 9)
  assert.equal(Model.peakValue([]), 0)
  assert.equal(Model.peakValue(null), 0)
})

test("historique : la fenetre glisse sur deux minutes et rejette les mesures negatives", () => {
  let history = []
  history = Model.appendHistory(history, 0, 10)
  history = Model.appendHistory(history, 60000, 20)
  history = Model.appendHistory(history, 60000, -1)
  assert.deepEqual(history.map(point => point.value), [10, 20])
  history = Model.appendHistory(history, 130000, 30)
  assert.deepEqual(history.map(point => point.value), [20, 30])
})

test("coeurs : le maximum vaut -1 sans coeur mesure", () => {
  assert.equal(Model.maximumPercent([{ percent: 12 }, { percent: 87 }]), 87)
  assert.equal(Model.maximumPercent([]), -1)
})
