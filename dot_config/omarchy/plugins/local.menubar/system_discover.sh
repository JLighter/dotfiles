#!/bin/bash

# Decouverte des sondes du widget System de local.menubar, lancee une fois au
# chargement : le releve periodique lit ensuite les chemins trouves ici sans
# rien forker.
#
# Sortie TSV, une cle et une valeur par ligne :
#   cpu_temp  <chemin du capteur de temperature du paquet CPU>
#   disk      <peripherique bloc physique>   (une ligne par disque)
#   gpu_smi   <chemin de nvidia-smi>         (absent sans pilote NVIDIA)
#
# Porte de omarchy-system-monitor (Harshith Chennupati, MIT, voir NOTICE),
# discover-sensors.sh au commit 71599f7, sans les capteurs Apple Silicon ni la
# decouverte GPU sysfs : la carte NVIDIA de cette machine n'expose rien dans
# /sys, elle passe par nvidia-smi.

shopt -s nullglob

# Racines surchargeables pour que le test rejoue la decouverte sur des
# arborescences factices.
hwmon_root="${SYSTEM_DISCOVER_HWMON_ROOT:-/sys/class/hwmon}"
block_root="${SYSTEM_DISCOVER_BLOCK_ROOT:-/sys/class/block}"

# Capteur du paquet : l'etiquette « Package id 0 » (coretemp) ou « Tctl »
# (k10temp, zenpower) d'abord, a defaut la premiere entree lisible de la puce.
for hwmon in "$hwmon_root"/hwmon*; do
  [[ -r "$hwmon/name" ]] || continue
  IFS= read -r name <"$hwmon/name"
  [[ "$name" == "coretemp" || "$name" == "k10temp" || "$name" == "zenpower" ]] || continue

  selected=""
  for label_file in "$hwmon"/temp*_label; do
    IFS= read -r label <"$label_file"
    if [[ "$label" == "Package id 0" || "$label" == "Tctl" ]]; then
      candidate="${label_file%_label}_input"
      [[ -r "$candidate" ]] && selected="$candidate"
      break
    fi
  done

  if [[ -z "$selected" ]]; then
    for candidate in "$hwmon"/temp*_input; do
      [[ -r "$candidate" ]] && selected="$candidate" && break
    done
  fi

  if [[ -n "$selected" ]]; then
    printf 'cpu_temp\t%s\n' "$selected"
    break
  fi
done

# Disques physiques : ni partitions, ni peripheriques virtuels (loop, ram,
# zram), ni lecteurs amovibles d'un autre age (disquette, optique).
for block_path in "$block_root"/*; do
  device="${block_path##*/}"
  [[ -e "$block_path/partition" ]] && continue
  [[ -e "$block_path/device" ]] || continue
  case "$device" in
    loop*|ram*|zram*|fd*|sr*) continue ;;
  esac
  printf 'disk\t%s\n' "$device"
done

# Le pilote NVIDIA proprietaire n'expose rien dans /sys : charge, temperature
# et VRAM passent par nvidia-smi. Le chercher une fois ici evite au releve de
# lancer a chaque tour un binaire absent.
if smi="$(command -v nvidia-smi)"; then
  printf 'gpu_smi\t%s\n' "$smi"
fi

exit 0
