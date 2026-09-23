#!/usr/bin/env bash
# Factual digest of a Claude Code transcript (.jsonl): where time and tokens went.
# Usage: session-digest.sh <transcript.jsonl>
set -euo pipefail
f="${1:?usage: session-digest.sh <transcript.jsonl>}"

jq -rs '
  def ts: .timestamp // empty;
  def tool_uses: [.[] | select(.type=="assistant") | .message.content[]? | select(.type=="tool_use")];
  def results:   [.[] | select(.type=="user") | .message.content | arrays | .[] | select(.type=="tool_result")];
  def rtext: if (.content|type)=="string" then .content else ([.content[]? | .text? // empty] | join(" ")) end;
  def prompts:   [.[] | select(.type=="user" and (.message.content|type)=="string")
                      | select(.message.content | test("^<(local-command|command-|bash-std)") | not)];
  def dur($a;$b): (($b|sub("\\.[0-9]+Z$";"Z")|fromdate) - ($a|sub("\\.[0-9]+Z$";"Z")|fromdate));

  ([.[] | ts]) as $t
  | tool_uses as $tu | results as $r
  | "## Overview",
    "duration_min: \((dur($t[0];$t[-1])/60)|floor)",
    "user_prompts: \(prompts|length)",
    "tool_calls: \($tu|length)",
    "tool_errors: \([$r[] | select(.is_error==true)]|length)",
    "user_denials: \([$r[] | rtext | select(test("doesn.t want to proceed|rejected|denied"; "i"))]|length)",
    "interruptions: \([.[] | select(.type=="user") | .message.content | tostring | select(test("Request interrupted"))]|length)",
    "output_tokens: \([.[] | select(.type=="assistant") | .message.usage.output_tokens // 0] | add // 0)",
    "",
    "## Tool calls by name",
    ($tu | group_by(.name) | map("\(length)\t\(.[0].name)") | sort_by(-(split("\t")[0]|tonumber)) | .[]),
    "",
    "## Repeated identical calls (>=2)",
    ($tu | map({k: (.name + " " + (.input|tostring|.[0:160]))}) | group_by(.k) | map(select(length>=2)) | map("\(length)x\t\(.[0].k)") | .[]),
    "",
    "## Tool errors (first 200 chars)",
    ($r | map(select(.is_error==true) | rtext | .[0:200] | gsub("\n";" ")) | .[]),
    "",
    "## User prompts (timeline, first 200 chars)",
    (prompts | .[] | "\(.timestamp[11:19])\t\(.message.content|.[0:200]|gsub("\n";" "))"),
    "",
    "## Longest gaps between records (>60s)",
    ([range(1; $t|length) as $i | {at: $t[$i-1][11:19], s: dur($t[$i-1];$t[$i])}]
      | map(select(.s>60)) | sort_by(-.s) | .[:8][] | "\(.at)\t\(.s|floor)s")
' "$f"
