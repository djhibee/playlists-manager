#!/bin/sh

# !!!DRAFT!!! But working...
# Read paths from file and call a twicked artistCountry.py to force countries when not found
# REQUIRES modification of artistCountry.py

#Use this to create  dirs:
#ls -d -1 $PWD/**
#this for files:
#ls -d -1 $PWD/*.*
#this for everything:
#ls -d -1 $PWD/**/*

CONFIG_MUSIC_TO_PROCESS="/Users/superToto/.config/beets/config-mp3-toProcess.yaml"


#ls -d -1 /Volumes/SuperToto_MOB/music-mp3-v0/** > directoriesToTreatForCountry.txt
while read file; do
  echo "Processing $file"
  beet -c $CONFIG_MUSIC_TO_PROCESS move path:"$file"
done < directoriesToTreatForCountry.txt
