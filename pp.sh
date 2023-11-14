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

# Determine package manager
if [ -f /sbin/apk ]; then APK=true; else APK=false; fi
if [ -f /usr/bin/apt ]; then APT=true; else APT=false; fi

# Assign variables passed from Transmission
if ! [[ "$TR_TORRENT_NAME" == "" ]]; then TORRENTNAME="$TR_TORRENT_NAME"; fi
if ! [[ "$TR_TORRENT_DIR" == "" ]]; then CONTENTPATH="$TR_TORRENT_DIR/$TR_TORRENT_NAME"; ROOTPATH="$TR_TORRENT_DIR/$TR_TORRENT_NAME"; fi

### DEFINE VARIABLES END
### DEFINE FUNCTIONS

function print_header {
# Print header
  echo '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
  echo $(date)
  echo "  ** STARTED PROCESSING $TORRENTNAME"
}

function print_footer {
# Print footer
  echo "  ** FINISHED PROCESSING $TORRENTNAME"
  echo $(date)
  echo '----------------------------------------------------------------------------------'
}

function print_footer2 {
# Print different footer for reprocessing
  echo "  ** FINISHED REPROCESSING FILES FOUND IN $CONTENTPATH"
  echo $(date)
  echo '_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-'
}

function install_exiftool {
# Install exiftool (required) on debian and alpine
  exiftool -ver > /dev/null 2>&1
  if ! [ $? -eq 0 ]; then
     if ($APT); then
       apt install exiftool -y > /dev/null 2>&1
       if [ $? -eq 0 ]; then echo "  ** INSTALLED: exiftool"; fi
     fi
     if ($APK); then
       apk add --no-cache exiftool > /dev/null 2>&1
       if [ $? -eq 0 ]; then echo "  ** INSTALLED: exiftool"; fi
     fi
  fi
}

function install_ffmpeg {
# Install ffmpeg (optional) on debian and alpine
  ffmpeg -version > /dev/null 2>&1
  if ! [ $? -eq 0 ]; then
     if ($APT); then
       apt install ffmpeg -y > /dev/null 2>&1
       if [ $? -eq 0 ]; then echo "  ** INSTALLED: ffmpeg"; fi
     fi
     if ($APK); then
       apk add --no-cache ffmpeg > /dev/null 2>&1
       if [ $? -eq 0 ]; then echo "  ** INSTALLED: ffmpeg"; fi
     fi
  fi
}

function install_unrar {
# Install UNRAR (optional) on debian and alpine
  unrar > /dev/null 2>&1
  if ! [ $? -eq 0 ]; then
     if ($APT); then
       apt install unrar -y > /dev/null 2>&1
       if [ $? -eq 0 ]; then echo "  ** INSTALLED: UNRAR"; fi
     fi
     if ($APK); then
       apk add --no-cache unrar > /dev/null 2>&1
       if [ $? -eq 0 ]; then echo "  ** INSTALLED: UNRAR"; fi
     fi
  fi
}

function install_unzip {
# Install UnZip (optional) on debian and alpine
  unzip > /dev/null 2>&1
  if ! [ $? -eq 1 ]; then
     if ($APT); then
       apt install unzip -y > /dev/null 2>&1
       if [ $? -eq 0 ]; then echo "  ** INSTALLED: UnZip"; fi
     fi
     if ($APK); then
       apk add --no-cache unzip > /dev/null 2>&1
       if [ $? -eq 0 ]; then echo "  ** INSTALLED: UnZip"; fi
     fi
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
        echo "     DELETED: $file"
        DELETEDFILE=true
      fi
    fi
  done
  if ! ($DELETEDFILE); then echo "     NOTHING DELETED"; fi
}

function strip_files {
# Load list of strip strings from configuration file and strip files
  shopt -s nullglob nocaseglob
  STRIPPEDFILE=false
  cd "$CONTENTPATH"
  echo "  ** STRIPPING FILE NAMES"
  for stripper in $(cat /config/pp-strippers.txt) ; do
    for file in *.{avi,mkv,mp4,rar,ts,wmv,zip} ; do
      if [[ "$file" == *"$stripper"* ]]; then
        if mv "$file" "${file/$stripper/}"; then
           echo "     STRIPPED: $stripper from $file"
           STRIPPEDFILE=true
        fi
      fi
    done
  done
  if ! ($STRIPPEDFILE); then echo "     NOTHING STRIPPED"; fi
}

function rename_files_actual {
# rename/replace strings in files defined in pp-renames.txt
# inputs: matchstring replacementstring
  shopt -s nullglob nocaseglob
  UNWANTED_STRING="$1"
  REPLACEMENT_STRING="$2"
  cd "$CONTENTPATH"
  for file in *.{avi,mkv,mp4,rar,ts,wmv,zip} ; do
    if [[ "$file" == *"$UNWANTED_STRING"* ]]; then
      if mv "$file" "${file/$UNWANTED_STRING/$REPLACEMENT_STRING}"; then
         echo "     RENAMED: $file to ${file/$UNWANTED_STRING/$REPLACEMENT_STRING}"
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
  if ! ($RENAMEDFILE); then echo "     NOTHING RENAMED"; fi
}

function remux_avi_files {
# Remux .AVI files to .MP4 using ffmpeg
  REMUXED_FILE=false
  if [ $AVI_NUM_FILES -eq 0 ]; then return; fi
  echo "  ** REMUXING AVI FILES"
  cd "$CONTENTPATH"
  for file in *.avi ; do
    if ffmpeg -i "$file" -c copy "${file/.avi/}".mp4 > /dev/null 2>&1; then
       echo "     REMUXED $file to MP4"
       REMUXED_FILE=true
       MP4_NUM_FILES=$((MP4_NUM_FILES+1))
       rm "$file"
    else
       echo "     ERROR REMUXING $file"
    fi
  done
if ! ($REMUXED_FILE); then echo "     NOTHING REMUXED"; fi
}

function remux_mkv_files {
# Remux .MKV files to .MP4 using ffmpeg
  REMUXED_FILE=false
  if [ $MKV_NUM_FILES -eq 0 ]; then return; fi
  echo "  ** REMUXING MKV FILES"
  cd "$CONTENTPATH"
  for file in *.mkv ; do
    if ffmpeg -i -map 0 "$file" -c copy "${file/.mkv/}".mp4 > /dev/null 2>&1; then
       echo "     REMUXED $file to MP4"
       REMUXED_FILE=true
       MP4_NUM_FILES=$((MP4_NUM_FILES+1))
       rm "$file"
    else
       echo "     ERROR REMUXING $file"
    fi
  done
if ! ($REMUXED_FILE); then echo "     NOTHING REMUXED"; fi
}

function remux_mov_files {
# Remux .MOV files to .MP4 using ffmpeg
  REMUXED_FILE=false
  if [ $MOV_NUM_FILES -eq 0 ]; then return; fi
  echo "  ** REMUXING MOV FILES"
  cd "$CONTENTPATH"
  for file in *.mov ; do
    if ffmpeg -i "$file" -c copy "${file/.mov/}".mp4 > /dev/null 2>&1; then
       echo "     REMUXED $file to MP4"
       REMUXED_FILE=true
       MP4_NUM_FILES=$((MP4_NUM_FILES+1))
       rm "$file"
    else
       echo "     ERROR REMUXING $file"
    fi
  done
if ! ($REMUXED_FILE); then echo "     NOTHING REMUXED"; fi
}

function remux_ts_files {
# Remux .TS files to .MP4 using ffmpeg
  REMUXED_FILE=false
  if [ $TS_NUM_FILES -eq 0 ]; then return; fi
  echo "  ** REMUXING TS FILES"
  cd "$CONTENTPATH"
  for file in *.ts ; do
    if ffmpeg -i "$file" -c copy "${file/.ts/}".mp4 > /dev/null 2>&1; then
       echo "     REMUXED $file to MP4"
       REMUXED_FILE=true
       MP4_NUM_FILES=$((MP4_NUM_FILES+1))
       rm "$file"
    else
       echo "     ERROR REMUXING $file"
    fi
  done
if ! ($REMUXED_FILE); then echo "     NOTHING REMUXED"; fi
}

function remux_wmv_files {
# Remux .WMV files to .MP4 using ffmpeg
  REMUXED_FILE=false
  if [ $WMV_NUM_FILES -eq 0 ]; then return; fi
  echo "  ** REMUXING WMV FILES"
  cd "$CONTENTPATH"
  for file in *.wmv ; do
    if ffmpeg -i "$file" -c copy "${file/.wmv/}".mp4 > /dev/null 2>&1; then
       echo "     REMUXED $file to MP4"
       REMUXED_FILE=true
       MP4_NUM_FILES=$((MP4_NUM_FILES+1))
       rm "$file"
    else
       echo "     ERROR REMUXING $file"
    fi
  done
  if ! ($REMUXED_FILE); then echo "     NOTHING REMUXED"; fi
}

function tag_files_actual {
# Tag MP4 files with defined metadata from pp-taggers.txt
# NOTE: exiftool can't handle MKV files
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
             echo "     TAGGED: $file with \"$TAG\""
             TAGGEDFILE=true
          else
             echo "     ERROR TAGGING $file"
          fi
        done
     else
     # SERIES album tag
        for file in *.mp4; do
          exiftool -album="$TAG" -title="$file" -genre=Porn,"$GENRE" -comment=" " -copyright=" " "$file" -overwrite_original -api largefilesupport=1 -ignoreMinorErrors > /dev/null 2>&1
          if [ $? -eq 0 ] ; then
             echo "     TAGGED: $file with \"$TAG\""
             TAGGEDFILE=true
          else
             echo "     ERROR TAGGING $file"
          fi
        done
     fi
  fi
}

function tag_files {
# Load tag strings from configuration file
  TAGGEDFILE=false
  if [ $MP4_NUM_FILES -eq 0 ] && [ $RAR_NUM_FILES -eq 0 ]; then return; fi
  echo "  ** TAGGING FILES"
  while IFS=, read -r match tag tagdestination genre
  do
    tag_files_actual "$match" "$tag" "$tagdestination" "$genre"
    if ($TAGGEDFILE); then return; fi
  done </config/pp-taggers.txt
  if ! ($TAGGEDFILE); then echo "     NOTHING TAGGED"; DESTINATION="$HOLD_DESTINATION"; fi
}

function extract_rars {
# extract (video) files from RARs
  if [ $RAR_NUM_FILES -eq 0 ]; then return; fi
  cd "$CONTENTPATH"
  echo "  ** EXTRACTING RARs"
  for file in *.rar; do
      unrar e -inul -y "$file"
      if [ $? -eq 0 ] ; then
         echo "     EXTRACTED: $file"
         if ($DEL_PROCESSED_DIRS); then del "$file"; fi
         AVI_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.AVI"  | wc -l)
         MKV_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.MKV"  | wc -l)
         MOV_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.MOV"  | wc -l)
         MP4_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.MP4"  | wc -l)
         TS_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.TS"  | wc -l)
         WMV_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.WMV"  | wc -l)
      else
         echo "     ERROR EXTRACTING $file"
      fi
  done
}

function extract_zips {
# extract (video) files from ZIPs
  if [ $ZIP_NUM_FILES -eq 0 ]; then return; fi
  cd "$CONTENTPATH"
  echo "  ** EXTRACTING ZIPs"
  for file in *.zip; do
      unzip "$file"
      if [ $? -eq 0 ] ; then
         echo "     EXTRACTED: $file"
         if ($DEL_PROCESSED_DIRS); then del "$file"; fi
         AVI_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.AVI"  | wc -l)
         MKV_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.MKV"  | wc -l)
         MOV_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.MOV"  | wc -l)
         MP4_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.MP4"  | wc -l)
         TS_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.TS"  | wc -l)
         WMV_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.WMV"  | wc -l)
      else
         echo "     ERROR EXTRACTING $file"
      fi
  done
}

function extract_archives {
  extract_rars
  extract_zips
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
         echo "     PREPENDED: $file to $TAG - $file"
         PREPENDEDFILES=true
      fi
  done
  if ! ($PREPENDEDFILES); then echo "     NOTHING PREPENDED"; fi
}

function convert_case {
# Convert files to lower or upper case (helps prevent dupes)
  CONVERTEDFILES=false
  cd "$CONTENTPATH"
  if ($CONVERT_TO_LC); then
    echo "  ** CONVERTING TO LOWER CASE"
    for file in *; do
        mv "$file" "${file,,}" > /dev/null 2>&1
        if [ $? -eq 0 ] ; then
           echo "     CONVERTED: $file to ${file,,}"
           CONVERTEDFILES=true
        fi
    done
  fi
  if ($CONVERT_TO_UC); then
    echo "  ** CONVERTING TO UPPER CASE"
    for file in *; do
        mv "$file" "${file^^}" > /dev/null 2>&1
        if [ $? -eq 0 ] ; then
           echo "     CONVERTED: $file to ${file^^}"
           CONVERTEDFILES=true
        fi
    done
  fi
  if ! ($CONVERTEDFILES); then echo "     NOTHING CONVERTED"; fi
}

function show_properties {
# Display dimensions and codec of files
  unset codec
  unset filename
  unset height
  unset width
  cd "$CONTENTPATH"
  echo "  ** VIDEO PROPERTIES"
  for file in *.{mp4,mkv}; do
      width=$(ffprobe -v error -show_entries stream=width -of default=noprint_wrappers=1 "$file")
      width="${width//width=/}"
      height=$(ffprobe -v error -show_entries stream=height -of default=noprint_wrappers=1 "$file")
      height="${height//height=/}"
      codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file")
      if [ $MP4_NUM_FILES -gt 1 ] || [ $MKV_NUM_FILES -gt 1 ]; then
        echo "     FILE      : $file"
      fi
      if (( $height > $MAX_DESIRED_HEIGHT )); then echo "     RESOLUTION: ${width}x${height} - higher than max desired ${MAX_DESIRED_WIDTH}x${MAX_DESIRED_HEIGHT}" ; fi
      if (( $height > $DESIRED_HEIGHT )); then echo "     RESOLUTION: ${width}x${height} - higher than desired ${DESIRED_WIDTH}x${DESIRED_HEIGHT}" ; fi
      if (( $height < $DESIRED_HEIGHT )); then echo "     RESOLUTION: ${width}x${height} - lower than desired ${DESIRED_WIDTH}x${DESIRED_HEIGHT}" ; fi
      if (( $height == $DESIRED_HEIGHT )); then echo "     RESOLUTION: ${width}x${height} - matches desired ${DESIRED_WIDTH}x${DESIRED_HEIGHT}" ; fi
      if ($OVERWRITE_OLD_CODECS); then
        if [[ " ${MODERN_CODECS[*]} " =~ "$codec" ]]; then
          echo "     CODEC     : $codec - matches desired $MODERN_CODECS"
        else
          echo "     CODEC     : $codec - does not match desired $MODERN_CODECS"
        fi
      else
        echo "     CODEC     : $codec"
      fi
  done
}

function move_files {
# Move files to assigned destinations and handle dupes
  shopt -s nullglob nocaseglob nocasematch
  MOVEDFILE=false
  OVERWRITE=false
  cd "$CONTENTPATH"
  echo "  ** MOVING FILES"
  if ! test -d "$HOLD_DESTINATION/_DUPES" ; then mkdir "$HOLD_DESTINATION/_DUPES"; fi
# check codec stuff here
  if ($OVERWRITE_OLD_CODECS); then
     if [[ $CONTENTPATH == *"HEVC"* || $CONTENTPATH == *"x265"* || $CONTENTPATH == *"h265"* || $CONTENTPATH == *"av1"* || $CONTENTPATH == *"vp9"* ]]; then OVERWRITE=true; fi
     if [[ " ${MODERN_CODECS[*]} " =~ "$codec" ]]; then OVERWRITE=true; fi
  fi
  if ! test -d "$DESTINATION" ; then
     if ($CREATE_MISSING_DIRS); then
        mkdir "$DESTINATION"
     else
        echo "     DESTINATION ($DESTINATION) does not exist."
        DESTINATION=$HOLD_DESTINATION
     fi
  fi
# check resolution stuff here
  if ($OVERWRITE_LOWER_RESOLUTION); then
     unset oldfilewidth
     unset oldfileheight
     unset oldfilecodec
     unset newfilewidth
     unset newfileheight
     unset newfilecodec
     for file in *.{mp4,mkv}; do
       if test -f "$DESTINATION/$file"; then
         echo "     DUPLICATE FOUND: $DESTINATION/$file"
         oldfilewidth=$(ffprobe -v error -show_entries stream=width -of default=noprint_wrappers=1 "$DESTINATION/$file")
         oldfilewidth="${oldfilewidth//width=/}"
         oldfileheight=$(ffprobe -v error -show_entries stream=height -of default=noprint_wrappers=1 "$DESTINATION/$file")
         oldfileheight="${oldfileheight//height=/}"
         oldfilecodec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$DESTINATION/$file")
         newfilewidth=$(ffprobe -v error -show_entries stream=width -of default=noprint_wrappers=1 "$file")
         newfilewidth="${newfilewidth//width=/}"
         newfileheight=$(ffprobe -v error -show_entries stream=height -of default=noprint_wrappers=1 "$file")
         newfileheight="${newfileheight//height=/}"
         newfilecodec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file")
         echo "     EXISTING FILE PROPERTIES: ${oldfilewidth}x${oldfileheight} $oldfilecodec"
         echo "     NEW FILE PROPERTIES     : ${newfilewidth}x${newfileheight} $newfilecodec"

# TODO
# SCOPE: (not fully implemented)
# replace lower resolution files (not existing DESIRED_HEIGHT) up to MAX_DESIRED_HEIGHT
# replace higher resolution files with DESIRED_HEIGHT files when OVERWRITE_HIGHER_RESOLUTION set true
# replace same resolution files with MODERN_CODECS when set true
# delete new file when resolution is greater than MAX_DESIRED_HEIGHT - WARNING: think about VR files!
# decide how to handle exceptions for VR files (possibly check for "VR" tag and always upgrade resolution)
# might be nice to match with different extensions as well; i.e. file.mp4 and file.mkv

         if (( $oldfileheight > $DESIRED_HEIGHT )); then
           echo "     EXISTING FILE RESOLUTION: higher than desired ${DESIRED_WIDTH}x${DESIRED_HEIGHT}"
         fi
         if (( $oldfileheight < $DESIRED_HEIGHT )); then
           echo "     EXISTING FILE RESOLUTION: lower than desired ${DESIRED_WIDTH}x${DESIRED_HEIGHT}"
         fi
         if (( $oldfileheight == $DESIRED_HEIGHT )); then
           echo "     EXISTING FILE RESOLUTION: matches desired ${DESIRED_WIDTH}x${DESIRED_HEIGHT}"
         fi
         if (( $oldfileheight > $newfileheight )); then
           echo "     EXISTING FILE RESOLUTION: higher than new file resolution"
           if ($DEL_DUPES); then
             echo "     DELETING NEW FILE: $file"
             rm "$file"
           fi
         fi
         if (( $oldfileheight < $newfileheight )); then
           echo "     EXISTING FILE RESOLUTION: lower than new file resolution, REPLACING..."
           OVERWRITE=true
         fi
         if (( $oldfileheight == $newfileheight )); then
           echo "     EXISTING FILE RESOLUTION: same as new file resolution"
           if [[ " ${MODERN_CODECS[*]} " =~ "$oldfilecodec" ]]; then
             echo "     EXISTING FILE CODEC     : same as new file codec"
             if ($DEL_DUPES); then
               echo "     DELETING NEW FILE: $file"
               rm "$file"
             fi
           fi
         fi
       fi
     done
  fi
  if ($OVERWRITE); then
     for file in *.{mp4,mkv}; do
           if mv --force "$file" "$DESTINATION"; then
              echo "     MOVED: $file to $DESTINATION"
              MOVEDFILE=true
           else
              echo "     ERROR moving $file to $DESTINATION"
              if mv --force "$file" "$HOLD_DESTINATION"; then
                 echo "     MOVED: $file to $HOLD_DESTINATION"
                 MOVEDFILE=true
              fi
           fi
     done
  else
     for file in *.{mp4,mkv}; do
       if ! [ -f "$DESTINATION/$file" ]; then
          if mv "$file" "$DESTINATION"; then
             echo "     MOVED: $file to $DESTINATION"
             MOVEDFILE=true
          fi
       else
         if ($DEL_DUPES); then
            rm "$file"
            echo "     DELETED DUPE: $file"
         else mv --force "$file" "$HOLD_DESTINATION/_DUPES"
            echo "     MOVED: $file to $HOLD_DESTINATION/_DUPES"
            MOVEDFILE=true
         fi
       fi
     done
  fi
# Move RAR and ZIP files to holding
  for file in *.{rar,zip}; do
       if ! [ -f "$HOLD_DESTINATION/$file" ]; then
          if mv "$file" "$HOLD_DESTINATION"; then
             echo "     MOVED: $file to $HOLD_DESTINATION"
             MOVEDFILE=true
          fi
       else
         if ($DEL_DUPES); then
            rm "$file"
            echo "     DELETED DUPE: $file"
         else
            if mv --force "$file" "$HOLD_DESTINATION/_DUPES"; then
               MOVEDFILE=true
               echo "     MOVED: $file to $HOLD_DESTINATION/_DUPES"
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
  if ! ($MOVEDFILE); then echo "     NOTHING MOVED"; fi
}

function do_more_prep {
# Change file permissions, rename M4V files, display file totals
  cd "$CONTENTPATH"

  # Run chown, chgrp, and/or chmod if defined
  if ! [[ "$RUN_CHOWN" == "" ]]; then chown "$RUN_CHOWN" "$SAVEPATH" -R; fi
  if ! [[ "$RUN_CHGRP" == "" ]]; then chgrp "$RUN_CHGRP" "$SAVEPATH" -R; fi
  if ! [[ "$RUN_CHMOD" == "" ]]; then chmod "$RUN_CHMOD" "$SAVEPATH" -R; fi

  # Rename M4V files to MP4 - M4V is a more descriptive extension, but MP4 is more prevalent
  M4V_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.M4V"  | wc -l)
  if [ $M4V_NUM_FILES -gt 0 ]; then
    find "$CONTENTPATH" -depth -name "*.m4v" -exec sh -c 'f="{}"; mv -- "$f" "${f%.m4v}.mp4"' \;
  fi

  # Announce found files of interest
  AVI_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.AVI"  | wc -l)
  MKV_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.MKV"  | wc -l)
  MOV_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.MOV"  | wc -l)
  MP4_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.MP4"  | wc -l)
  TS_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.TS"  | wc -l)
  WMV_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.WMV"  | wc -l)
  RAR_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.RAR"  | wc -l)
  ZIP_NUM_FILES=$(find "$CONTENTPATH" -type f -iname "*.ZIP"  | wc -l)
  echo "     FOUND $MP4_NUM_FILES MP4, $AVI_NUM_FILES AVI, $MKV_NUM_FILES MKV, $MOV_NUM_FILES MOV, $TS_NUM_FILES TS, $WMV_NUM_FILES WMV, $RAR_NUM_FILES RAR, $ZIP_NUM_FILES ZIP files."
  if [ \( $MP4_NUM_FILES -eq 0 -a $MKV_NUM_FILES -eq 0 -a $TS_NUM_FILES -eq 0 -a $AVI_NUM_FILES -eq 0 -a $MOV_NUM_FILES -eq 0 -a $WMV_NUM_FILES -eq 0 -a $RAR_NUM_FILES -eq 0 -a $ZIP_NUM_FILES -eq 0 \) ] ; then
    print_footer
    exit
  fi
}

function start_processing {
  do_more_prep
  if ($EXTRACT_ARCHIVES); then extract_archives; fi
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
  if ($CONVERT_TO_LC) || ($CONVERT_TO_UC); then convert_case; fi
  show_properties
  if test -f "$CUSTOM_SCRIPT"; then
    echo "  ** EXECUTING $CUSTOM_SCRIPT"
    source "$CUSTOM_SCRIPT"
  fi
  if ($MOVE_FILES); then move_files; fi
}

function start_reprocessing {
# Reprocess directories moved to REPROCESS_PATH
  cd $REPROCESS_PATH
  numdirs=$(ls | wc -l)
  if [ $numdirs -eq 0 ]; then REPROCESSING=false; exit; fi
  REPROCESSING=true
  for dirs in *; do
    CONTENTPATH="$REPROCESS_PATH/$dirs"
    echo '+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-'
    echo $(date)
    echo "  ** STARTED REPROCESSING FILES FOUND IN $CONTENTPATH"
    start_processing
    print_footer2
  done
  REPROCESSING=false
}

### DEFINE FUNCTIONS END

# Announce start of processing torrent's files
print_header

### PREPROCESSING START

if ($ONLY_PROCESS_CATEGORY); then
   if ! [[ "$PROCESS_CATEGORY" == "$CATEGORY" ]]; then
      echo "     CATEGORY ($CATEGORY) not specified for processing. Aborting..."; print_footer; exit 1;
   fi
fi
if [[ "$HOLD_DESTINATION" == "" ]]; then echo "     ERROR: HOLD_DESTINATION needs to be defined in pp-variables.txt. Aborting..."; print_footer; exit 1; fi
if ! test -d "$HOLD_DESTINATION" ; then echo "     ERROR: HOLD_DESTINATION ($HOLD_DESTINATION) is not valid. Check pp-variables.txt. Aborting..."; print_footer; exit 1; fi
if [[ "$PORNSTARS_DESTINATION" == "" ]]; then echo "     ERROR: PORNSTARS_DESTINATION needs to be defined in pp-variables.txt. Aborting..."; print_footer; exit 1; fi
if ! test -d "$PORNSTARS_DESTINATION" ; then echo "     ERROR: PORNSTARS_DESTINATION ($PORNSTARS_DESTINATION) is not valid. Check pp-variables.txt. Aborting..."; print_footer; exit 1; fi
if ! ($DEL_PROCESSED_DIRS); then
     if [[ "$PROCESSED_DESTINATION" == "" ]]; then
        echo "     ERROR: PROCESSED_DESTINATION needs to be defined in pp-variables.txt. Aborting..."; print_footer; exit 1;
     else
       if ! test -d "$PROCESSED_DESTINATION" ; then
          echo "     ERROR: PROCESSED_DESTINATION ($PROCESSED_DESTINATION) is not valid. Check pp-variables.txt. Aborting..."; print_footer; exit 1;
       fi
     fi
fi
if ($REPROCESS_FILES); then
   if [[ "$REPROCESS_PATH" == "" ]]; then
      echo "     ERROR: REPROCESS_PATH needs to be defined in pp-variables.txt. Aborting..."; print_footer; exit 1;
   else
      if ! test -d "$REPROCESS_PATH" ; then
         echo "     ERROR: REPROCESS_PATH ($REPROCESS_PATH) is not valid. Check pp-variables.txt. Aborting..."; print_footer; exit 1;
      fi
   fi
fi
if [[ "$SERIES_DESTINATION" == "" ]]; then echo "     ERROR: SERIES_DESTINATION needs to be defined in pp-variables.txt. Aborting..."; print_footer; exit 1; fi
if ! test -d "$SERIES_DESTINATION" ; then echo "     ERROR: SERIES_DESTINATION ($SERIES_DESTINATION) is not valid. Check pp-variables.txt. Aborting..."; print_footer; exit 1; fi
if ! cd "$ROOTPATH" ; then echo "     ERROR: Can not process ROOTPATH ($ROOTPATH). Aborting..."; print_footer; exit 1; fi
# NOTE: QBittorrent - when content layout is set to Create subfolder, CONTENTPATH includes the filename when there is only one file but ROOTPATH does not
if ! [[ "$CONTENTPATH" == "$ROOTPATH" ]] ; then echo "     CONTENTPATH and ROOTPATH are NOT equal. Setting CONTENTPATH to ROOTPATH"; CONTENTPATH="$ROOTPATH"; fi
if ! cd "$CONTENTPATH" ; then echo "     ERROR: Cannot process CONTENTPATH ($CONTENTPATH). Aborting."; print_footer; exit 1; fi

# Attempt install of exiftool, ffmpeg, unrar, and unzip
install_exiftool
if [[ ($REMUX_AVI_FILES) || ($REMUX_MKV_FILES) || ($REMUX_MOV_FILES) || ($REMUX_TS_FILES) || ($REMUX_WMV_FILES) ]]; then install_ffmpeg; fi
if ($EXTRACT_ARCHIVES); then install_unrar; install_unzip; fi

# Test if exiftool, ffmpeg, unrar, and unzip are installed
exiftool -ver > /dev/null 2>&1
if ! [ $? -eq 0 ]; then echo "     ERROR: exiftool not installed. Aborting..."; print_footer; exit 1; fi
if [[ ($REMUX_AVI_FILES) || ($REMUX_MKV_FILES) || ($REMUX_MOV_FILES) || ($REMUX_TS_FILES) || ($REMUX_WMV_FILES) ]]; then
   ffmpeg -version > /dev/null 2>&1
   if ! [ $? -eq 0 ]; then echo "     WARNING: ffmpeg not installed. Remuxing disabled."; REMUX_AVI_FILES=false; REMUX_MKV_FILES=false; REMUX_MOV_FILES=false; REMUX_TS_FILES=false; REMUX_WMV_FILES=false; fi
fi
if ($EXTRACT_ARCHIVES); then
   unrar > /dev/null 2>&1
   if ! [ $? -eq 0 ]; then echo "     ERROR: UNRAR not installed. Archive extracting disabled."; EXTRACT_ARCHIVES=false; fi
   unzip > /dev/null 2>&1
   if ! [ $? -eq 1 ]; then echo "     ERROR: UnZip not installed. Archive extracting disabled."; EXTRACT_ARCHIVES=false; fi
fi

### PREPROCESSING END
### PROCESSING START

start_processing
print_footer
if ($REPROCESS_FILES); then start_reprocessing; fi

### PROCESSING END
