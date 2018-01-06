#!/bin/bash
# May be easily converted to sh compatible script if needed, since a very few bashisms are used ([[]]...)
#
# Context:
#       I use two music libraries. One for lossy files and one for lossless files.
#       Thus, at home with high bandwith, I can enjoy my lossless files, and on remote (in my car...)
#       I can spare data in my phone's subscription by using corresponding lossy files.
#       Of course, music players (DS Audio..) provide automatic transcoding but we have no visibility on the
#       quality of the transcode and it uses music server's resources.
#       I call "pair file" th same song from a file encoded with another quality.
#       Namely toto.mp3 is the pair file of toto.flac.
#       The issue with such an aproach is that I have to maintain 2 copies of the same playlist, the lossy one and the lossless one.
#       However, music organizer (except Roon) are not able to match files with different quality.
#       This is why I have created a bunch of scripts to automatize that. It uses the power of Beets library to
#       identify pairs via tags compare.
#       The scripts also give the possibility to backup playlists directly into files tags, without tracing the play order tough (via Beets again).
#       At the end I will have two copies per playlist:
#             - a lossy one to play on remote
#             - and a "best quality" one prioritarizing lossless files when available, to play at home
#
# Synopsis:
#       Highest level script.
#       Backup lossy playlists from Synology server and regenerate corresponding best quality ones.
#       Update files Beets' comments accordingly.
#       WARNING LIMITATION: When not using SQLITE DB option, playlist songs order is not maintained and only one instance is kept per pair playlist song.
#
#
# Usage: bash ./UpdateFilesAndPlaylists.sh $useSQLiteDBOption
#
# Pre-requisites:
#   Playlist can use either relatives or absolutes paths to identify the songs
#   Pool of playlist available.
#   WARNING CONVENTION: Rating playlists must be named x-stars.m3u, i.e 5-stars.m3u
#
## External dependencies:
#   03_generateRatingPlaylist.sh
#   03_updateMusicFilesAndSQLDB script
#   sed and comm commands
#   SQLite DB created according to the structure below
#
# SQLITE DB Structure:
# sqlite> .tables
# FILES      PLAYLISTS
# sqlite> .schema
# CREATE TABLE FILES(
# ID       INTEGER     PRIMARY KEY   AUTOINCREMENT,
# LOSSY    TEXT                  NOT NULL,
# LOSSLESS TEXT                  NOT NULL
# );
# CREATE INDEX i  ON FILES(LOSSY);
# CREATE INDEX i2 ON FILES(LOSSLESS);
# CREATE TABLE PLAYLISTS(
# PLAYLISTNAME  TEXT    NOT NULL,
# PLAYORDER     INTEGER NOT NULL,
# TRACKID       INTEGER NOT NULL,
# PRIMARY KEY(PLAYLISTNAME,PLAYORDER),
# FOREIGN KEY(TRACKID) REFERENCES FILES(ID)
# );
# CREATE INDEX i3 ON PLAYLISTS(PLAYLISTNAME);
#
# Algo:
# Get all playlists in LOSSY_PLAYLIST_DIRECTORY
#   -> regenerate rating playlists from Synology API
# For each playlist
#   -> either get last bakup from BACKUP_DIRECTORY or get List From SQLITE DB (depending on option chosen)
#   -> compare both files
#       -> put new files in $playlist.addedSinceLastBackup
#       -> put removed files in $playlist.removedSinceLastBackup
#       -> add new files to lossless playlist and update beet ratings
#           -> ./03_updateMusicFilesAndSQLDB.sh $playlist.addedSinceLastBackup add
#       -> remove old files from lossless playlist and update beet ratings
#           -> ./03_updateMusicFilesAndSQLDB.sh $playlist.removedSinceLastBackup remove
#       -> regenerate pair playlist $playlist.lossless.m3u in LOSSLESS_PLAYLIST_DIRECTORY after backup of old one
#            -> if DB option is used, create a "BEST QUALITY playlist"
#            -> if not, just create a lossless playlist (so, playlist may miss songs that only exist in LOSSY quality)
#       -> backup LOSSY_PLAYLIST_DIRECTORY to FULL_BACKUP_DIRECTORY
#
# Useful commands:
#     timestamp="$(date +'%Y%m%d%H%M')";while read playlist; do cp "$playlist" "./backups/$timestamp-$playlist"; done <  <(find *.m3u)
#
# History
# Date            Version        Auteur        Commentaire
# 11/09/2016      1.0            Djhibee       Creation
# 16/03/2017      2.0            Djhibee       Introduce SQLITE DB

####################################
## TO CONFIGURE BEFORE USING SCRIPT
####################################

####### Global variables #######
# Directory where lossy playlist are stored
LOSSY_PLAYLIST_DIRECTORY="/volume1/music/playlists"
# Directory where lossless playlist are stored
LOSSLESS_PLAYLIST_DIRECTORY="/volume1/music_lossless/playlists"
# Directory where all music related stuff is backed up
FULL_BACKUP_DIRECTORY="/var/services/homes/djhibee/Config_NAS/beet/01_backups"
# Directory where playlists are backed-up (used when SQLITEDB is off)
BACKUP_DIRECTORY="/volume1/homes/djhibee/.config/beets/backups"
# Directory where all music scripts are stored
SCRIPTS_DIRECTORY="/var/services/homes/djhibee/Config_NAS/beet/02_scripts"
# Lossy music directory
LOSSY_DIRECTORY="/volume1/music"
# Beets' config for lossless files
export CONFIG_LOSSLESS="/Users/superToto/Downloads/home/config-lossless.yaml"
# Set to 1 in order to use by default SQLITE DB to store playlists backups instead of simple txt files
USE_SQLITE_DB_DEFAULT=1
GENERATE_RATING_PLAYLISTS_SCRIPT_PATH="$SCRIPTS_DIRECTORY/03_generateRatingPlaylist.sh"
UPDATE_MUSIC_FILES_AND_SQLDB_SCRIPT_PATH="$SCRIPTS_DIRECTORY/03_updateMusicFilesAndSQLDB.sh"
# DB were to store playlists backups and pairs
export SQLITEDB="/Users/superToto/Downloads/home/musicOnNas.db"
export RED_COLOR='\033[0;31m'
export NO_COLOR='\033[0m'
export LOG_COLOR_DEFAULT=$NO_COLOR

#####################
# END OF CONFIGURATION
#######################
#######################
## Other variables
#######################
debug_mode=0


##############################################
function usage {
  echo "USAGE: $0 [-d]
             -d : use SQLITE DB instead of text files
             -h --help : Display this message
        "
  exit 0
}

function endProg {
    end=$1
    args=$*
    if [ $end -gt 0 ]; then
        echoInColor "End of script with error" "$RED_COLOR"
        if [ $# -gt 1 ]; then
            echoInColor "$args" "$RED_COLOR"
        fi
        exit $end
    else
        echoInColor "Script ended normally" "$LOG_COLOR_DEFAULT"
        exit 0
    fi
}

function datacheck {
  echo ""
}

# Print debug logs if debug_mode==true
function log {
  typeset logcolor
  if [ $# -gt 1 ]; then
  	logColor="$2"
  else
    logColor="$LOG_COLOR_DEFAULT"
  fi
  if [ "$debug_mode" -eq 1 ]; then
    echoInColor "$1" "$logColor"
  fi
}

function echoInColor {
  typeset echoColor
  if [ $# -gt 1 ]; then
    echoColor="$2"
  else
    echoColor="$LOG_COLOR_DEFAULT"
  fi
  echo -e "$echoColor $1"
  printf "${LOG_COLOR_DEFAULT}\r"
}

function initialize{
  if [[ $1 =~ ^--help ]]; then
    usage
  fi
  echo "02_UpdateFilesAndPlaylists script started..."
  if [ "$debug_mode" -eq 1 ]; then
    echo "debug mode is ON"
  else
    echo "debug mode is OFF"
  fi
  echo "... Get parameters"
  useSQLiteDB=$USE_SQLITE_DB_DEFAULT
  updateDBOption=""
  while getopts "hd" option
  do
    case $option in
      d)
        useSQLiteDB=1
        updateDBOption="-d"
        ;;
      h)
        usage
        ;;
      :)
        endProg 1 "Option $OPTARG needs an argument" ;
        ;;
      \?)
        endProg 1 "$OPTARG : invalid option" ;
        ;;
    esac
  done

  if [ useSQLiteDB == 0 ]
  then
    echo "Back-up file option chosen"
  else
    echo "SQLite DB option chosen"
  fi

}


##########
#  Main
##########
initialize "$@"
datacheck

echo "... Starting update of playlists in $LOSSY_PLAYLIST_DIRECTORY..."

# Get dynamic rating playlists from AudioStation
for i in `seq 1 5`
do
  $GENERATE_RATING_PLAYLISTS_SCRIPT_PATH "$i" "$LOSSY_PLAYLIST_DIRECTORY"
done

# filter only .m3u file from given LOSSY_PLAYLIST_DIRECTORY
find $LOSSY_PLAYLIST_DIRECTORY -maxdepth 1 |  grep .m3u$ > playlists.tmp

timestamp="$(date +'%Y%m%d%H%M')"

while read filePlaylist; do
	echo "Processing Playlist $filePlaylist"
  # Handle ../ in case the playlist path is absolute and not the current repo
  # ../foo/bar/playlist.m3u => playlist
  playlistName=$(basename "$filePlaylist" ".m3u" | cut -f1 -d'.' )
  log "the playlist name is $playlistName"
  newBackup="$BACKUP_DIRECTORY/$timestamp-$playlistName.m3u"

  if [ useSQLiteDB -eq 0 ]
  then
    # extract last backup date. Backup are store in format $timestamp-$filePlaylist
    #set -x
    lastBackup="`find "$BACKUP_DIRECTORY" | grep "$playlistName.*\.m3u$" | sort | tail -1 `"
    #set +x
    echo "Last backup is $lastBackup"
    # if no backup was existing, we create an empty one
    if [[ -z "$lastBackup" ]]
    then
      echo "No backup existing, we create an empty one"
      touch "$newBackup"
    else
      # we create a new backup with all music from the last one
      cp $lastBackup "$newBackup"
    fi
  else
    # we create the backup file from th DB
    selectDBRequest="select LOSSY from files as f INNER JOIN PLAYLISTS as p on f.ID=p.TRACKID where p.name = \"$playlistName\" ORDER BY p.PLAYORDER"
    sqlite3 $SQLITEDB <<< "$selectDBRequest" > "$newBackup"
  fi

  cat "$filePlaylist" | tr -d '\r' > "$filePlaylist.tmp"
  # Replace ../ by LOSSY_DIRECTORY to have aboslute music paths
  sed "s|\.\.\/|${LOSSY_DIRECTORY}\/|" "$filePlaylist.tmp" > "$filePlaylist.cleaned"
  sort "$filePlaylist.cleaned"  > "$filePlaylist.sorted"

  # THAT STEP IS VERY IMPORTANT otherwise comm wont match lines between unix and windows encoded lines
  # indeed the command 'file' return 201609171402-2-stars.m3u.sorted: ASCII text, with CRLF line terminators
  # and 2-stars.m3u.sorted: ASCII text
  # so we remove the \r from the unix playlist
  cat "$newBackup" | tr -d '\r' > "$newBackup.cleaned"
  sort "$newBackup.cleaned"  > "$newBackup.sorted"

  # last backup should already be sorted; we remove the extinf line
  comm -2 -3 "$filePlaylist.sorted" "$newBackup.sorted" | sed '/#EXTINF:/d'  > "$filePlaylist.addedSinceLastBackup"
  comm -1 -3 "$filePlaylist.sorted" "$newBackup.sorted" | sed '/#EXTINF:/d'  > "$filePlaylist.removedSinceLastBackup"
  addEmpty="`cat "$filePlaylist.addedSinceLastBackup" | grep '.*mp3'`"
  removeEmpty="`cat \"$filePlaylist.removedSinceLastBackup\" | grep '.*mp3' `"

  if [ -z "$addEmpty" ] && [ -z "$removeEmpty" ]
  then
      echo "No changed occured for $filePlaylist since last backup."
      rm -f "$newBackup"
  else
    if [ ! -z "$addEmpty" ]
    then
      echo "Number of new songs added since last backup: `wc -l < \"$filePlaylist.addedSinceLastBackup\"`"
      # we dont use the -o option since the given playlist is a diff and not the complete one
      $UPDATE_MUSIC_FILES_AND_SQLDB_SCRIPT_PATH -p "$filePlaylist.addedSinceLastBackup" -u "add" $updateDBOption -b "$newBackup"
    fi
    if [ ! -z "$removeEmpty" ]
    then
      echo "Number of new songs removed since last backup: `wc -l < \"$filePlaylist.removedSinceLastBackup\"`"
      $UPDATE_MUSIC_FILES_AND_SQLDB_SCRIPT_PATH -p "$filePlaylist.removedSinceLastBackup" -u "remove" $updateDBOption "$newBackup"
      # erase removed lignes from backup in order not to process it again next time
      sort "$newBackup" | tr -d '\r' > "$newBackup.sorted"
      comm -1 -3 "$filePlaylist.removedSinceLastBackup" "$newBackup.sorted" > "$newBackup"
    fi

    # overwrite playlist in DB if songs play order changed
    # Performances could be improved using a fine diff but it requires line numbers in the diff....
    if [ useSQLiteDB -gt 0 ]
    then
      comm -2 -3 "$filePlaylist.cleaned" "$newBackup.cleaned" | sed '/#EXTINF:/d'  > "$filePlaylist.checkOrderChange"
      orderChange="`cat "$filePlaylist.checkOrderChange" | grep '.*mp3'`"
      if [ ! -z "$orderChange" ]
      then
        deleteDBRequest="DELETE FROM PLAYLISTS WHERE PLAYLISTNAME =\"$playlistName\";"
        sqlite3 $SQLITEDB <<< "$deleteDBRequest"
        playlistOrder=0
        while read file; do
          playlistOrder=$((playlistOrder + 1))
          selectDBRequest="SELECT ID FROM FILES WHERE LOSSY=\"$file\" LIMIT 1 ;"
          trackID=`sqlite3 $SQLITEDB <<< "$selectDBRequest"`
          if [[ -z "$trackID" ]]
          then
            endProg 400 "Unexpected error occured. No id was found in FILES table for file $file"
          fi
          addDBRequest="INSERT INTO PLAYLISTS (PLAYLISTNAME, PLAYORDER, TRACKID) VALUES (\"$playlistName\", \"$playlistOrder\", \"$trackID\" );"
          sqlite3 $SQLITEDB <<< "$addDBRequest"
        done <  "$filePlaylist"
      else
        echo "Former songs play order was maintained. Only new songs were added at the end of the list."
      fi
    fi

    ##############################
    # regenerate pair playlists:
    # if DB option is used, create a "BEST QUALITY playlist"
    # if not, just create a lossless playlist (so, playlist may miss songs that only exist in LOSSY quality)

    # backup of old playlist
    if (test -e "$LOSSLESS_PLAYLIST_DIRECTORY/$playlistName.lossless.m3u")
    then
      echo "Backup lossless playlist"
      mv -f "$LOSSLESS_PLAYLIST_DIRECTORY/$playlistName.lossless.m3u" "$LOSSLESS_PLAYLIST_DIRECTORY/$playlistName.lossless.m3u.bak"
    fi
    echo "Create new lossless playlist"
    echo "#EXTM3U" > "$LOSSLESS_PLAYLIST_DIRECTORY/$playlistName.lossless.m3u"

    if [ useSQLiteDB -eq 0 ]
    then
      # limitation: only one instance is kept per song in the pair playist...
      beet -c $CONFIG_LOSSLESS list -p "comments:$playlistName"  >> "$LOSSLESS_PLAYLIST_DIRECTORY/$playlistName.lossless.m3u"
    else
      # create best quality playlist
      selectDBRequest="SELECT CASE WHEN LOSSLESS != "" THEN LOSSLESS ELSE LOSSY END AS song
                       FROM FILES AS f
                       JOIN PLAYLISTS AS p ON f.ID=p.TRACKID
                       WHERE p.PLAYLISTNAME=$playlistName
                       ORDER BY PLAYORDER ASC
                       ; "
      #songPaths=`sqlite3 $SQLITEDB <<< "$selectDBRequest"`
      #echo "$toto"  | xargs -0 ./test2.sh > essai3.txt
      sqlite3 $SQLITEDB <<< "$selectDBRequest" >> "$LOSSLESS_PLAYLIST_DIRECTORY/$playlistName.lossless.m3u"
    fi

  fi

  # Clean files
  if [ "$debug_mode" = 0 ]; then
    rm -f "$filePlaylist.sorted"
    rm -f "$filePlaylist.addedSinceLastBackup"
    rm -f "$filePlaylist.removedSinceLastBackup"
    rm -f "$newBackup.sorted"
    rm -f "$newBackup.cleaned"
    rm -f "$filePlaylist.cleaned"
  fi

done < "playlists.tmp"

# creationDate=`echo $playlist|awk -F _ '{print $1$2}'|sed 's/h//g'`
# backup LOSSY_PLAYLIST_DIRECTORY  to FULL_BACKUP_DIRECTORY
echo "Backup full playlist repo"
cp -a "$LOSSY_PLAYLIST_DIRECTORY" "$FULL_BACKUP_DIRECTORY/playlists-$timestamp"
#delete useless @eadir direcotries
find "$FULL_BACKUP_DIRECTORY/playlists-$timestamp" -type d -name "@eaDir" -print0 | xargs -0 rm -rf

# Clean files
if [ "$debug_mode" = 0 ]; then
  rm -f "playlists.tmp"
fi

echo "All Playlists were updated successfully".
echo "$0 Script ended normally."
exit 0
