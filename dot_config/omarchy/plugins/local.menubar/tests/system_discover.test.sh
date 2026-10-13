#!/usr/bin/env bash
# Rejoue system_discover.sh sur des arborescences /sys factices :
# `bash tests/system_discover.test.sh`.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$root/system_discover.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

failures=0

hwmon_chip() { # <arbre> <hwmonN> <pilote>
  mkdir -p "$work/$1/hwmon/$2"
  printf '%s\n' "$3" >"$work/$1/hwmon/$2/name"
}

block_device() { # <arbre> <nom> [partition]
  mkdir -p "$work/$1/block/$2/device"
  [[ "${3:-}" == "partition" ]] && printf '1\n' >"$work/$1/block/$2/partition"
  return 0
}

# PROBE_PATH remplace le PATH du seul script sonde, pas celui du test : le
# script n'utilise que des commandes internes de bash, lance par chemin absolu.
probe() { # <arbre>
  mkdir -p "$work/$1/hwmon" "$work/$1/block"
  PATH="${PROBE_PATH:-$PATH}" SYSTEM_DISCOVER_HWMON_ROOT="$work/$1/hwmon" \
    SYSTEM_DISCOVER_BLOCK_ROOT="$work/$1/block" "$BASH" "$script"
}

# Comparaison en bash pur plutot que `grep -q` : avec pipefail, la sortie
# anticipee de grep tue la sonde par SIGPIPE et un succes passerait pour un echec.
expect() { # <nom> <arbre> <ligne exacte>
  local line found=0
  while IFS= read -r line; do
    [[ "$line" == "$3" ]] && { found=1; break; }
  done <<<"$(probe "$2")"
  if (( found )); then echo "  ok   $1"; else
    echo "  FAIL $1 : ligne attendue '$3'"; failures=$((failures + 1)); fi
}

expect_absent() { # <nom> <arbre> <prefixe>
  local line
  while IFS= read -r line; do
    if [[ "$line" == "$3"* ]]; then
      echo "  FAIL $1 : ligne inattendue '$line'"; failures=$((failures + 1)); return
    fi
  done <<<"$(probe "$2")"
  echo "  ok   $1"
}

echo "coretemp : l'etiquette Package id 0 l'emporte sur les entrees nues"
hwmon_chip coretemp hwmon0 acpitz
printf '27800\n' >"$work/coretemp/hwmon/hwmon0/temp1_input"
hwmon_chip coretemp hwmon4 coretemp
printf 'Core 0\n' >"$work/coretemp/hwmon/hwmon4/temp1_label"
printf '40000\n' >"$work/coretemp/hwmon/hwmon4/temp1_input"
printf 'Package id 0\n' >"$work/coretemp/hwmon/hwmon4/temp2_label"
printf '45000\n' >"$work/coretemp/hwmon/hwmon4/temp2_input"
expect "coretemp paquet" coretemp "$(printf 'cpu_temp\t%s/coretemp/hwmon/hwmon4/temp2_input' "$work")"

echo "k10temp sans etiquette : premiere entree lisible"
hwmon_chip k10 hwmon1 k10temp
printf '52000\n' >"$work/k10/hwmon/hwmon1/temp1_input"
expect "k10temp repli" k10 "$(printf 'cpu_temp\t%s/k10/hwmon/hwmon1/temp1_input' "$work")"

echo "puces etrangeres au CPU (acpitz, nvme, asus) : aucune sonde"
hwmon_chip foreign hwmon0 acpitz
printf '27800\n' >"$work/foreign/hwmon/hwmon0/temp1_input"
hwmon_chip foreign hwmon1 nvme
printf '35850\n' >"$work/foreign/hwmon/hwmon1/temp1_input"
expect_absent "pas de cpu_temp" foreign "cpu_temp"

echo "disques : physiques gardes, partitions et virtuels ecartes"
block_device disks nvme0n1
block_device disks nvme0n1p1 partition
block_device disks sda
block_device disks loop0
block_device disks zram0
block_device disks sr0
mkdir -p "$work/disks/block/dm-0"   # mappeur sans `device` : ecarte
expect "nvme0n1 garde" disks "$(printf 'disk\tnvme0n1')"
expect "sda garde" disks "$(printf 'disk\tsda')"
expect_absent "partition ecartee" disks "$(printf 'disk\tnvme0n1p1')"
expect_absent "loop ecarte" disks "$(printf 'disk\tloop')"
expect_absent "zram ecarte" disks "$(printf 'disk\tzram')"
expect_absent "optique ecarte" disks "$(printf 'disk\tsr')"
expect_absent "mappeur ecarte" disks "$(printf 'disk\tdm-')"

echo "nvidia-smi : annonce seulement s'il est dans le PATH"
mkdir -p "$work/bin"
printf '#!/bin/sh\n' >"$work/bin/nvidia-smi"
chmod +x "$work/bin/nvidia-smi"
PROBE_PATH="$work/bin" expect "nvidia-smi trouve" disks "$(printf 'gpu_smi\t%s/bin/nvidia-smi' "$work")"
PROBE_PATH="$work/empty" expect_absent "nvidia-smi absent" disks "gpu_smi"

echo
if (( failures == 0 )); then echo "decouverte : toutes les fixtures passent"; else
  echo "$failures verification(s) en echec"; exit 1; fi
