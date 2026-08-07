#!/bin/bash

# Releve systeme pour le widget System de local.menubar.
#
# Sortie TSV, une metrique par ligne. Les compteurs CPU sont donnes bruts :
# c'est le widget qui fait la difference entre deux releves, ce qui evite de
# garder un etat ici et rend le script rejouable sans effet de bord.

set -u

# cpu <idle> <total>, puis une ligne core par coeur.
# idle = idle + iowait, total = somme de tous les compteurs de la ligne.
awk '
  /^cpu / {
    idle = $5 + $6
    total = 0
    for (i = 2; i <= NF; i++) total += $i
    printf "cpu\t%d\t%d\n", idle, total
  }
  /^cpu[0-9]/ {
    idle = $5 + $6
    total = 0
    for (i = 2; i <= NF; i++) total += $i
    printf "core\t%s\t%d\t%d\n", $1, idle, total
  }
' /proc/stat

# mem et swap en kio : <total> <utilise>.
# MemAvailable, et non MemFree : le cache reclamable ne compte pas comme occupe.
awk '
  /^MemTotal:/ { total = $2 }
  /^MemAvailable:/ { avail = $2 }
  /^SwapTotal:/ { swapTotal = $2 }
  /^SwapFree:/ { swapFree = $2 }
  END {
    printf "mem\t%d\t%d\n", total, total - avail
    printf "swap\t%d\t%d\n", swapTotal, swapTotal - swapFree
  }
' /proc/meminfo

awk '{ printf "load\t%s\t%s\t%s\n", $1, $2, $3 }' /proc/loadavg
awk '{ printf "uptime\t%d\n", $1 }' /proc/uptime

# temp <libelle> <millidegres>. Un seul releve par puce : coretemp en expose un
# par coeur, ce qui noierait le panneau sans rien apprendre de plus.
for hwmon in /sys/class/hwmon/hwmon*; do
  [ -r "$hwmon/name" ] || continue
  [ -r "$hwmon/temp1_input" ] || continue
  printf 'temp\t%s\t%s\n' "$(cat "$hwmon/name")" "$(cat "$hwmon/temp1_input")"
done

# topcpu / topmem <pourcent_cpu> <pourcent_mem> <commande>
ps -eo pcpu=,pmem=,comm= --sort=-pcpu 2>/dev/null | head -5 |
  awk 'NF >= 3 { printf "topcpu\t%s\t%s\t%s\n", $1, $2, $3 }'
ps -eo pcpu=,pmem=,comm= --sort=-pmem 2>/dev/null | head -5 |
  awk 'NF >= 3 { printf "topmem\t%s\t%s\t%s\n", $1, $2, $3 }'
