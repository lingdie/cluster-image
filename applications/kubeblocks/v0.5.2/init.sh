#!/bin/bash
set -e

cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1

mkdir -p charts

target_dir="charts"
file="chartslist"

while IFS= read -r line
do
    wget -P $target_dir "$line"
done < "$file"

