#!/bin/sh

CONFIG_MP3=“~/.config/beets/config.yaml"
CONFIG_LOSSLESS=“~/.config/beets/config-lossless.yaml"

ls > newImports.txt

while read playlist; do
  echo “$playlist”
  cat “$playlist”  > newFiles.txt
  while read file2; do
    echo $file2
    synoindex -a “$file2”
  done < newFiles.txt
done < newImports.txt
