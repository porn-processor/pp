#!/bin/bash
# Porn Processor - automatically clean, remux, tag, and move porn files
# ASSUMPTION: Using QBittorrent (but setup to probably work with Transmission)
# ASSUMPTION: QBittorrent config - Options/Downloads/When adding a torrent/Torrent content layout is set to Create subfolder

### DEFINE VARIABLES

# Load configuration variables from file
source /config/pp-variables.txt

# Assign variables passed from QBittorrent
TORRENTNAME=$1
CATEGORY=$2
TAGS=$3
CONTENTPATH=$4
ROOTPATH=$5
SAVEPATH=$6
NUMBEROFFILES=$7

# Assign variables passed from Transmission
if ! [[ "$TR_TORRENT_NAME" == "" ]]; then TORRENTNAME="$TR_TORRENT_NAME"; fi
if ! [[ "$TR_TORRENT_DIR" == "" ]]; then CONTENTPATH="$TR_TORRENT_DIR/$TR_TORRENT_NAME"; ROOTPATH="$TR_TORRENT_DIR/$TR_TORRENT_NAME"; fi

### DEFINE VARIABLES END
### DEFINE FUNCTIONS

# Print header
function print_header {
  echo '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
  echo $(date)
  echo "  ** START PROCESSING $TORRENTNAME"
}

# Print footer
function print_footer {
# Print footer
  echo "  ** FINISHED PROCESSING $TORRENTNAME"
  echo $(date)
  echo '----------------------------------------------------------------------------------'
}

# Print footer for reprocessing
function print_footer2 {
  echo "  ** FINISHED REPROCESSING FILES FOUND IN $CONTENTPATH"
  echo $(date)
  echo '_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-'
}

function install_exiftool {
# Install exiftool (required) on debian and alpine
  exiftool -ver > /dev/null 2>&1
  if ! [ $? -eq 0 ]; then
     apt -v > /dev/null 2>&1
     if ! [ $? -eq 0 ]; then apt install exiftool -y > /dev/null 2>&1; echo "  ** installed exiftool"; fi
     apk --version > /dev/null 2>&1
     if ! [ $? -eq 0 ]; then apk add --no-cache exiftool > /dev/null 2>&1; echo "  ** installed exiftool"; fi
  fi
}

function install_ffmpeg {
# Install ffmpeg (optional) on debian and alpine
  ffmpeg -version > /dev/null 2>&1
  if ! [ $? -eq 0 ]; then
     apt -v > /dev/null 2>&1
     if ! [ $? -eq 0 ]; then apt install ffmpeg -y > /dev/null 2>&1; echo "  ** installed ffmpeg"; fi
     apk --version > /dev/null 2>&1
     if ! [ $? -eq 0 ]; then apk add --no-cache ffmpeg > /dev/null 2>&1; echo "  ** installed ffmpeg"; fi
  fi
}

function del_unwanted_files {
# Load list of files to delete from configuration file
  DELETEDFILE=false
  shopt -s nocaseglob
  echo "  ** DELETING UNWANTED FILES"
  cd "$CONTENTPATH"
  for file in $(cat /config/pp-deleters.txt) ; do
    if test -f "$file"; then
      if rm "$file"; then
        echo "    ** DELETED: $file"
        DELETEDFILE=true
      fi
    fi
  done
  if ! ($DELETEDFILE); then echo "    ** NOTHING DELETED"; fi
}

function strip_files_actual {
# Strip unwanted strings from files defined in pp-strippers.txt
# inputs: strip_string
  shopt -s nullglob nocaseglob
  STRIP_STRING="$1"
  cd "$CONTENTPATH"
  for file in *.{mp4,mkv,rar,ts} ; do
    if [[ "$file" == *"$STRIP_STRING"* ]]; then
      if mv "${file}" "${file/$STRIP_STRING/}"; then
         echo "    ** STRIPPED: $STRIP_STRING"
         STRIPPEDFILE=true
      fi
    fi
  done
}

function strip_files {
# Load strip strings from configuration file
  STRIPPEDFILE=false
  echo "  ** STRIPPING FILE NAMES"
  for strippers in $(cat /config/pp-strippers.txt) ; do
     strip_files_actual "$strippers"
  done
  if ! ($STRIPPEDFILE); then echo "    ** NOTHING STRIPPED"; fi
}

function rename_files_actual {
# rename/replace strings in files defined in pp-renames.txt
# inputs: matchstring replacementstring
  shopt -s nullglob nocaseglob
  UNWANTED_STRING="$1"
  REPLACEMENT_STRING="$2"
  cd "$CONTENTPATH"
  for file in *.{mp4,mkv,rar,ts} ; do
    if [[ "$file" == *"$UNWANTED_STRING"* ]]; then
      if mv "$file" "${file/$UNWANTED_STRING/$REPLACEMENT_STRING}"; then
         echo "    ** RENAMED: $file to ${file/$UNWANTED_STRING/$REPLACEMENT_STRING}"
         RENAMEDFILE=true
      fi
    fi
  done
}

function rename_files {
# Load rename/replace strings from configuration file
  RENAMEDFILE=false
  echo "  ** RENAMING FILES"
  while IFS=, read -r oldname newname
  do
    rename_files_actual "$oldname" "$newname"
  done </config/pp-renamers.txt
  if ! ($RENAMEDFILE); then echo "    ** NOTHING RENAMED"; fi
}

function remux_avi_files {
# Remux .AVI files to .MP4 using ffmpeg
  REMUXED_FILE=false
  if [ $AVI_NUM_FILES -eq 0 ]; then return; fi
  echo "  ** REMUXING AVI FILES"
  cd "$CONTENTPATH"
  for file in *.avi ; do
    if ffmpeg -i "$file" -c copy "${file/.avi/}".mp4 > /dev/null 2>&1; then
      echo "    ** REMUXED $file to MP4"
      REMUXED_FILE=true
      MP4_NUM_FILES=$((MP4_NUM_FILES+1))
      rm "$file"
    fi
  done
if ! ($REMUXED_FILE); then echo "    ** NOTHING REMUXED"; fi
}

function remux_mkv_files {
# Remux .MKV files to .MP4 using ffmpeg
  REMUXED_FILE=false
  if [ $MKV_NUM_FILES -eq 0 ]; then return; fi
  echo "  ** REMUXING MKV FILES"
  cd "$CONTENTPATH"
  for file in *.mkv ; do
    if ffmpeg -i "$file" -c copy "${file/.mkv/}".mp4 > /dev/null 2>&1; then
      echo "    ** REMUXED $file to MP4"
      REMUXED_FILE=true
      MP4_NUM_FILES=$((MP4_NUM_FILES+1))
      rm "$file"
    fi
  done
if ! ($REMUXED_FILE); then echo "    ** NOTHING REMUXED"; fi
}

function remux_mov_files {
# Remux .MOV files to .MP4 using ffmpeg
  REMUXED_FILE=false
  if [ $MOV_NUM_FILES -eq 0 ]; then return; fi
  echo "  ** REMUXING MOV FILES"
  cd "$CONTENTPATH"
  for file in *.mov ; do
    if ffmpeg -i "$file" -c copy "${file/.mov/}".mp4 > /dev/null 2>&1; then
      echo "    ** REMUXED $file to MP4"
      REMUXED_FILE=true
      MP4_NUM_FILES=$((MP4_NUM_FILES+1))
      rm "$file"
    fi
  done
if ! ($REMUXED_FILE); then echo "    ** NOTHING REMUXED"; fi
}

function remux_ts_files {
# Remux .TS files to .MP4 using ffmpeg
  REMUXED_FILE=false
  if [ $TS_NUM_FILES -eq 0 ]; then return; fi
  echo "  ** REMUXING TS FILES"
  cd "$CONTENTPATH"
  for file in *.ts ; do
    if ffmpeg -i "$file" -c copy "${file/.ts/}".mp4 > /dev/null 2>&1; then
      echo "    ** REMUXED $file to MP4"
      REMUXED_FILE=true
      MP4_NUM_FILES=$((MP4_NUM_FILES+1))
      rm "$file"
    fi
  done
if ! ($REMUXED_FILE); then echo "    ** NOTHING REMUXED"; fi
}

function remux_wmv_files {
# Remux .WMV files to .MP4 using ffmpeg
  REMUXED_FILE=false
  if [ $WMV_NUM_FILES -eq 0 ]; then return; fi
  echo "  ** REMUXING WMV FILES"
  cd "$CONTENTPATH"
  for file in *.wmv ; do
    if ffmpeg -i "$file" -c copy "${file/.wmv/}".mp4 > /dev/null 2>&1; then
      echo "    ** REMUXED $file to MP4"
      REMUXED_FILE=true
      MP4_NUM_FILES=$((MP4_NUM_FILES+1))
      rm "$file"
    fi
  done
  if ! ($REMUXED_FILE); then echo "    ** NOTHING REMUXED"; fi
}

function tag_files_actual {
# Tag MP4 files with defined metadata from pp-taggers.txt
# inputs: MATCH TAG TAG_DESTINATION GENRE (genre is optional but will always be tagged with "Porn")
  shopt -s nullglob nocaseglob
  MATCH="$1"
  TAG="$2"
  TAG_DESTINATION="$3"
  GENRE="$4"
  DESTINATION="$HOLD_DESTINATION"
  PORNSTARS_TAG=false
  SERIES_TAG=false
  cd "$CONTENTPATH"
  if [[ "$TAG" == "same" ]] ; then TAG="$MATCH"; fi
  if [[ $TAG_DESTINATION == "pornstars" ]] ; then PORNSTARS_TAG=true; DESTINATION="$PORNSTARS_DESTINATION/$TAG"; fi
  if [[ $TAG_DESTINATION == "pornstars_keepers" ]] ; then PORNSTARS_TAG=true; DESTINATION="$PORNSTARS_KEEPERS_DESTINATION/$TAG"; fi
  if [[ $TAG_DESTINATION == "series" ]] ; then SERIES_TAG=true; DESTINATION="$SERIES_DESTINATION/$TAG"; fi
  if [[ $TAG_DESTINATION == "series_keepers" ]] ; then SERIES_TAG=true; DESTINATION="$SERIES_KEEPERS_DESTINATION/$TAG"; fi
  if [[ $TAG_DESTINATION == "hold" ]]; then DESTINATION="$HOLD_DESTINATION"; fi
  if [[ $TAG_DESTINATION =~ "/" ]]; then DESTINATION="$TAG_DESTINATION"; fi
  if [[ ${CONTENTPATH^^} == *"${MATCH^^}"* ]] ; then
     # PORNSTARS album tag
     if ($PORNSTARS_TAG) ; then
        for file in *.mp4; do
          exiftool -album="$TAG" -albumartist="$TAG" -title="$file" -genre=Porn,"$GENRE" -comment=" " -copyright=" " "$file" -overwrite_original -api largefilesupport=1 -ignoreMinorErrors > /dev/null 2>&1
          if [ $? -eq 0 ] ; then
             echo "    ** TAGGED: $file with \"$TAG\""
             TAGGEDFILE=true
          else
             echo "    ** ERROR TAGGING $file"
          fi
        done
     else
     # SERIES album tag
        for file in *.mp4; do
          exiftool -album="$TAG" -title="$file" -genre=Porn,"$GENRE" -comment=" " -copyright=" " "$file" -overwrite_original -api largefilesupport=1 -ignoreMinorErrors > /dev/null 2>&1
          if [ $? -eq 0 ] ; then
             echo "    ** TAGGED: $file with \"$TAG\""
             TAGGEDFILE=true
          else
             echo "    ** ERROR TAGGING $file"
          fi
        done
     fi
  fi
}

function tag_files {
# Load tag strings from configuration file
  TAGGEDFILE=false
  if [ $MP4_NUM_FILES -eq 0 ]; then return; fi
  echo "  ** TAGGING FILES"
  while IFS=, read -r match tag tagdestination genre
  do
    tag_files_actual "$match" "$tag" "$tagdestination" "$genre"
    if ($TAGGEDFILE); then return; fi
  done </config/pp-taggers.txt
  if ! ($TAGGEDFILE); then echo "    ** NOTHING TAGGED"; DESTINATION="$HOLD_DESTINATION"; fi
}

function prepend_with_tag {
# Prepend file with tag
  PREPENDEDFILES=false
  if ! ($TAGGEDFILE); then return; fi
  echo DEBUG: TAG = "$TAG"
  echo "  ** PREPENDING FILES"
  cd "$CONTENTPATH"
  for file in *; do
      mv "$file" "$TAG - $file" > /dev/null 2>&1
      if [ $? -eq 0 ] ; then
         echo "    ** PREPENDED: $file to $TAG - $file"
         PREPENDEDFILES=true
      fi
   done
   if ! ($PREPENDEDFILES); then echo "    ** NOTHING PREPENDED"; fi
}

function convert_to_lc {
# Convert files to lower case (helps prevent dupes)
  CONVERTEDFILES=false
  echo "  ** CONVERTING TO LOWER CASE"
  cd "$CONTENTPATH"
  for file in *; do
      mv "$file" "${file,,}" > /dev/null 2>&1
      if [ $? -eq 0 ] ; then
         echo "    ** CONVERTED: $file to ${file,,}"
         CONVERTEDFILES=true
      fi
   done
   if ! ($CONVERTEDFILES); then echo "    ** NOTHING CONVERTED"; fi
}

function move_files {
# Move files to assigned destinations
  shopt -s nullglob nocaseglob nocasematch
  MOVEDFILE=false
  OVERWRITE=false
  echo "  ** MOVING FILES"
  if ($OVERWRITE_OLD_CODECS); then
     if [[ $CONTENTPATH == *"HEVC"* || $CONTENTPATH == *"x265"* || $CONTENTPATH == *"h265"* || $CONTENTPATH == *"av1"* || $CONTENTPATH == *"vp9"* ]]; then OVERWRITE=true; fi
  fi
  cd "$CONTENTPATH"
  if ! test -d "$DESTINATION" ; then
     if ($CREATE_MISSING_DIRS); then
        mkdir "$DESTINATION"
     else
        echo "    ** DESTINATION ($DESTINATION) does not exist. Aborting..."
        print_footer
        exit 1
     fi
  fi
  if ! test -d "$HOLD_DESTINATION/_DUPES" ; then mkdir "$HOLD_DESTINATION/_DUPES"; fi
  if ($OVERWRITE); then
     for file in *.mp4; do
           if mv --force "$file" "$DESTINATION"; then
              echo "    ** MOVED: $file to $DESTINATION"
              MOVEDFILE=true
           else
              echo "    ** ERROR moving $file to $DESTINATION"
              if mv --force "$file" "$HOLD_DESTINATION"; then
                 echo "    ** MOVED: $file to $HOLD_DESTINATION"
                 MOVEDFILE=true
              fi
           fi
     done
  else
     for file in *.mp4; do
       if ! [ -f "$DESTINATION/$file" ]; then
          if mv "$file" "$DESTINATION"; then
             echo "    ** MOVED: $file to $DESTINATION"
             MOVEDFILE=true
          fi
       else
         if ($DEL_DUPES); then
            rm "$file"
            echo "  ** DELETED DUPE: $file"
         else mv --force "$file" "$HOLD_DESTINATION/_DUPES"
            echo "    ** MOVED: $file to $HOLD_DESTINATION/_DUPES"
            MOVEDFILE=true
         fi
       fi
     done
  fi
# Move RAR and ZIP files to holding since we're not going to process them
  for file in *.{rar,zip}; do
       if ! [ -f "$HOLD_DESTINATION/$file" ]; then
          if mv "$file" "$HOLD_DESTINATION"; then
             echo "    ** MOVED: $file to $HOLD_DESTINATION"
             MOVEDFILE=true
          fi
       else
         if ($DEL_DUPES); then
            rm "$file"
            echo "  ** DELETED DUPE: $file"
         else
            if mv --force "$file" "$HOLD_DESTINATION/_DUPES"; then
               MOVEDFILE=true
               echo "    ** MOVED: $file to $HOLD_DESTINATION/_DUPES"
            fi
         fi
       fi
  done
  if ($MOVEDFILE); then
     if ($DEL_PROCESSED_DIRS); then
        rm "$CONTENTPATH"
     else
        mv "$CONTENTPATH" "$PROCESSED_DESTINATION"
     fi
  fi
  if ! ($MOVEDFILE); then echo "    ** NOTHING MOVED"; fi
}

function start_processing {
  if ($DEL_UNWANTED_FILES); then del_unwanted_files; fi
  if ($STRIP_FILES); then strip_files; fi
  if ($RENAME_FILES); then rename_files; fi
  if ($REMUX_AVI_FILES); then remux_avi_files; fi
  if ($REMUX_MKV_FILES); then remux_mkv_files; fi
  if ($REMUX_MOV_FILES); then remux_mov_files; fi
  if ($REMUX_TS_FILES); then remux_ts_files; fi
  if ($REMUX_WMV_FILES); then remux_wmv_files; fi
  if ($TAG_FILES); then tag_files; fi
  if ($PREPEND_WITH_TAG); then prepend_with_tag; fi
  if ($CONVERT_TO_LC); then convert_to_lc; fi
  if ($MOVE_FILES); then move_files; fi
}

### DEFINE FUNCTIONS END

# Announce start of processing torrent
print_header

### PREPROCESSING START

if ($ONLY_PROCESS_CATEGORY); then
   if ! [[ "$PROCESS_CATEGORY" == "$CATEGORY" ]]; then
      echo "  ** CATEGORY ($CATEGORY) not specified for processing. Aborting..."; print_footer; exit 1;
   fi
fi
if [[ "$HOLD_DESTINATION" == "" ]]; then echo "  ** ERROR: HOLD_DESTINATION needs to be defined in pp-variables.txt. Aborting..."; print_footer; exit 1; fi
if ! test -d "$HOLD_DESTINATION" ; then echo "  ** ERROR: HOLD_DESTINATION ($HOLD_DESTINATION) is not valid. Check pp-variables.txt. Aborting..."; print_footer; exit 1; fi
if [[ "$PORNSTARS_DESTINATION" == "" ]]; then echo "  ** ERROR: PORNSTARS_DESTINATION needs to be defined in pp-variables.txt. Aborting..."; print_footer; exit 1; fi
if ! test -d "$PORNSTARS_DESTINATION" ; then echo "  ** ERROR: PORNSTARS_DESTINATION ($PORNSTARS_DESTINATION) is not valid. Check pp-variables.txt. Aborting..."; print_footer; exit 1; fi
if ! ($DEL_PROCESSED_DIRS); then
     if [[ "$PROCESSED_DESTINATION" == "" ]]; then
        echo "  ** ERROR: PROCESSED_DESTINATION needs to be defined in pp-variables.txt. Aborting..."; print_footer; exit 1;
     else
       if ! test -d "$PROCESSED_DESTINATION" ; then
          echo "  ** ERROR: PROCESSED_DESTINATION ($PROCESSED_DESTINATION) is not valid. Check pp-variables.txt. Aborting..."; print_footer; exit 1;
       fi
     fi
fi
if ($REPROCESS_FILES); then
   if [[ "$REPROCESS_PATH" == "" ]]; then
      echo "  ** ERROR: REPROCESS_PATH needs to be defined in pp-variables.txt. Aborting..."; print_footer; exit 1;
   else
      if ! test -d "$REPROCESS_PATH" ; then
         echo "  ** ERROR: REPROCESS_PATH ($REPROCESS_PATH) is not valid. Check pp-variables.txt. Aborting..."; print_footer; exit 1;
      fi
   fi
fi
if [[ "$SERIES_DESTINATION" == "" ]]; then echo "  ** ERROR: SERIES_DESTINATION needs to be defined in pp-variables.txt. Aborting..."; print_footer; exit 1; fi
if ! test -d "$SERIES_DESTINATION" ; then echo "  ** ERROR: SERIES_DESTINATION ($SERIES_DESTINATION) is not valid. Check pp-variables.txt. Aborting..."; print_footer; exit 1; fi
if ! cd "$ROOTPATH" ; then echo "  ** ERROR: Can not process ROOTPATH ($ROOTPATH). Aborting..."; print_footer; exit 1; fi
# NOTE: QBittorrent - when content layout is set to Create subfolder, CONTENTPATH includes the filename when there is only one file but ROOTPATH does not
if ! [[ "$CONTENTPATH" == "$ROOTPATH" ]] ; then echo "CONTENTPATH and ROOTPATH are NOT equal"; echo "setting CONTENTPATH to ROOTPATH"; CONTENTPATH="$ROOTPATH"; fi
if ! cd "$CONTENTPATH" ; then echo "  ** ERROR: Cannot process CONTENTPATH ($CONTENTPATH). Aborting."; print_footer; exit 1; fi

# Attempt exiftool and ffmpeg install
install_exiftool
install_ffmpeg

# Test if exiftool and ffmpeg are installed
exiftool -ver > /dev/null 2>&1
if ! [ $? -eq 0 ]; then echo "  ** ERROR: exiftool not installed. Aborting..."; print_footer; exit 1; fi
ffmpeg -version > /dev/null 2>&1
if ! [ $? -eq 0 ]; then echo "  ** WARNING: ffmpeg not installed. Remuxing disabled."; REMUX_AVI_FILES=false; REMUX_MKV_FILES=false; REMUX_MOV_FILES=false; REMUX_TS_FILES=false; REMUX_WMV_FILES=false; fi

# Announce found files of interest
AVI_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.AVI"  | wc -l)
MKV_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.MKV"  | wc -l)
MOV_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.MOV"  | wc -l)
MP4_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.MP4"  | wc -l)
TS_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.TS"  | wc -l)
WMV_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.WMV"  | wc -l)
RAR_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.RAR"  | wc -l)
ZIP_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.ZIP"  | wc -l)
echo "  ** Found $MP4_NUM_FILES MP4, $AVI_NUM_FILES AVI, $MKV_NUM_FILES MKV, $MOV_NUM_FILES MOV, $TS_NUM_FILES TS, $WMV_NUM_FILES WMV, $RAR_NUM_FILES RAR, $ZIP_NUM_FILES ZIP files."
if [ \( $MP4_NUM_FILES -eq 0 -a $MKV_NUM_FILES -eq 0 -a $TS_NUM_FILES -eq 0 -a $AVI_NUM_FILES -eq 0 -a $MOV_NUM_FILES -eq 0 -a $WMV_NUM_FILES -eq 0 -a $RAR_NUM_FILES -eq 0 -a $ZIP_NUM_FILES -eq 0 \) ] ; then
   echo "  ** Nothing to process. Aborting..."
   print_footer
   exit
fi

# Run chown, chgrp, and/or chmod if defined
if ! [[ "$RUN_CHOWN" == "" ]]; then chown "$RUN_CHOWN" "$SAVEPATH" -R; fi
if ! [[ "$RUN_CHGRP" == "" ]]; then chgrp "$RUN_CHGRP" "$SAVEPATH" -R; fi
if ! [[ "$RUN_CHMOD" == "" ]]; then chmod "$RUN_CHMOD" "$SAVEPATH" -R; fi

### PREPROCESSING END
### PROCESSING START

start_processing
print_footer

# Reprocess directories moved to REPROCESS_PATH
if ($REPROCESS_FILES); then
  cd $REPROCESS_PATH
  numdirs=$(ls | wc -l)
  if [ $numdirs -eq 0 ]; then REPROCESSING=false; exit; fi
  REPROCESSING=true
  for dirs in *; do
    CONTENTPATH="$REPROCESS_PATH/$dirs"
    echo '+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-'
    echo $(date)
    echo "  ** REPROCESSING FILES FOUND IN $CONTENTPATH"
    start_processing
    print_footer2
  done
  REPROCESSING=false
fi

### PROCESSING END
