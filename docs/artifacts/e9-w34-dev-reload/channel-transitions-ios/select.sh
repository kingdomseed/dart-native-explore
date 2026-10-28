#!/bin/zsh
set -e
stage=$1
label=$2
name=$3
agent=/private/tmp/dart3d-w34-ios-live-catcher-composition-20261028/r1/parent/agent.sh
base=/private/tmp/dart3d-w34-ios-channel-transitions-20261028/r1/parent/$stage
$agent snapshot -i > "$base/$name-before.txt"
ref=$(rg -F "[button] \"$label\"" "$base/$name-before.txt" | cut -d ' ' -f 1)
$agent click "$ref" > "$base/$name-click.txt"
$agent snapshot -i > "$base/$name-after.txt"
$agent screenshot "$base/$name.png" > "$base/$name-screenshot.txt"
