# Porn Processor - automatically clean, remux, tag, and move downloaded porn files

So you wish there was an *arr for porn... Yeah, me too. Using QBittorrent's RSS Downloader and Porn Processor you can achieve nearly the same results.

This is a little bash script I wrote, re-wrote, and re-wrote again, (and yet again to add features/settings for other people) to automatically process downloaded porn files and make them readily available on my Plex Media Server. It's not perfect, but it handles 99% of what I need. pp works very well to prep your files for use with [PhoenixAdult](https://github.com/PAhelper/PhoenixAdult.bundle/blob/master/Contents/Code/PAsiteList.py) PMS Agent. pp has freed up countless hours of my time from manually renaming, tagging, and moving files to my libraries. It used to be so bad that management was more time then watching the videos. Hopefully it will be of use to you as well. pp is intended to be used along with QBittorrent and it's RSS Downlaoder function.

# ASSUMPTIONS:
* You're using QBittorrent and it's RSS Downlaoder

# RECOMMENDATIONS:
* [Plex Media Server](https://www.plex.tv/) with [PhoenixAdult](https://github.com/PAhelper/PhoenixAdult.bundle/blob/master/Contents/Code/PAsiteList.py) Agent.
* [Stash](https://stashapp.cc/)
* [Porn Vault](https://github.com/porn-vault/porn-vault)

# pp FEATURES:
* Fully configurable from external files with the hopes you don't need to edit the script.
* Delete unwanted files; e.g. RARBG\_DO\_NOT\_MIRROR.exe
* Strip files of scene "tagging," e.g. remove `.XXX.1080p.MP4-KTR` from file names, as well as replacing the copyright and comment tags with " ". (Sorry scene peeps, we still love and thank you but don't appreciate the vandalism of the files.)
* Rename parts of files; e.g. `btra` to `BigTitsRoundAsses`
* Remux AVI, MKV, MOV, TS, and WMV files to MP4. (Yes MKV is arguably a better format than MP4, but it's also a pain in the ass to add metadata to. exiftool is universally available but basically only supports MP4 files and minimally tagging them. Taggers with more features are not as easy to install into containers.)
* Tag files with metadata. (Album field for collections in Plex and other media servers.); e.g. `ExxxtraSmall`. `Porn` is added as the genre to all MP4 files.
* Prepend files with the tag; i.e. `BangBus - 22.03.16.Sisi.Pesos.mp4` (Don't forget to strip "bangbus.") Not recommended when using PhoenixAdult Agent with PMS.
* Convert to lower case. This dramatically helps avoid dupes.
* Dupe checking. Can move dupes to designated folder for validation or they can be deleted. Original files can be overwritten with files using nextgen codecs such has HEVC/x265/h265/av1/vp9.
* Move processed files to library location. **NOTE:** Files/directories that are not processed, i.e. non-video files are left in their original download location. MP4 files without a defined destination will be kept in a holding area.
* Clean up processed torrent download directories by moving or deleting them after processing.
* Announcements of main functions running, success, failure, and not applicable viewable in the logs.

# REQUIREMENTS:

* exiftool is a requirement for tagging metadata. If you're running from a container such as 	[linuxserver/qbittorrent](https://hub.docker.com/r/linuxserver/qbittorrent) you can setup a [custom-cont-init.d](https://docs.linuxserver.io/general/container-customization#custom-scripts) directory with an install_packages.sh file which has "apk add --no-cache exiftool" in it. You might want to also add "apk add --no-cache ffmpeg" for transcoding support. pp will try to install these packages when using Debian or Alpine. If you're not using a docker container, just manually install the packages.
* pp is designed to be the "Run external program on torrent finished" from QBittorrent. Be sure to setup the command exactly like the below picture; i.e. `/bin/bash /config/pp.sh "%N" "%L" "%G" "%F" "%R" "%D" "%C" "%Z" "%T" "%I" "%J" "%K"`. Transmission support has been added but only minimumly tested. This documentation is going to mainly refer to QBittorrent. Put the files in QBittorrent's /config directory or wherever you want as long as you path it correctly in QBittorrent.

![image](https://user-images.githubusercontent.com/127630165/224512328-1ac010a5-2828-4d90-b4ff-cf3f2e96f9f0.png)

* Set "When adding a torrent/Torrrent content layout" to "Create subfolder" or you will might unexpectedly find your downloads directory deleted or moved. Don't say I didn't warn you!

![image](https://user-images.githubusercontent.com/127630165/224514087-64e746d2-982d-4eb8-964d-2d922f94cdb2.png)

# CONFIGURATION:

**Edit pp-variables.txt.** All features are disbaled by default with the exception of tagging.

* **DEL\_UNWANTED\_FILES** - set to true if you want to delete unwanted files listed in pp-deleters.txt.
* **MOVE\_FILES** - set to true if you want processed download directories moved to your library as defined in xDESTINATIONS below and pp-taggers.txt.
* **REMUX\_AVI\_FILES** - set to true to transcode older .AVI files to .MP4
* **REMUX\_MKV\_FILES** - set to true to transcode .MKV files to .MP4
* **REMUX\_MOV\_FILES** - set to true to transcode older .MOV files to .MP4
* **REMUX\_TS\_FILES** - set to true to transcode .TS files to .MP4 (This is showing up frequently in the Chinese/Tawainese porn scene.)
* **REMUX\_WMV\_FILES** - set to true to transcode older .WMV files to .MP4
* **RENAME\_FILES** - set to true to enable renaming of strings in files to something else as defined in pp-renamers.txt. (Usually acroynyms to full words.)
* **STRIP\_FILES** - set to true to remove strings in files such as scene group "tagging," resolution info, etc.
* **TAG\_FILES** - set to false if you don't want to tag files.
* **CONVERT\_TO\_LC** - set to true to convert files to lower case; this helps avoid some dupes.
* **CREATE\_MISSING\_DIRS** - set to true to create any missing destination directories in your library
* **DEL\_DUPES** - set to true to delete new files that are duplicates of files already in your library. When false, dupes will be held for inspection in **HOLD\_DESTINATION/\_DUPES**. 
* **DEL\_PROCESSED\_DIRS** - set to true to delete the torrent download directory after processing. When false, the directory will be held for inspection in **PROCESSED\_DESTINATION**.
* **ONLY\_PROCESS\_CATEGORY** - set to true if all your porn torrents are set to a category of **PROCESS\_CATEGORY** and you want to ignore all non-porn downloads. NOTE: Not compatible with Transmission.
* **OVERWRITE\_OLD\_CODECS** - set to true if you want to overwrite original files with dupes that use nextgen codecs such as HEVC/x265/h265/av1/vp9
* **PREPEND\_WITH\_TAG** - set to true to prepend the .MP4 file with the album tag.
* **PROCESS\_CATEGORY** - string to define which torrent cataegory to process when **ONLY\_PROCESS\_CATEGORY** is set to true; ie. "PORN"
* **REPROCESS\_FILES** - set to true to reprocess torrent directories moved to **REPROCESS\_PATH**. You shouldn't need this. This is basically a debug feature.
* **RUN\_CHOWN** - allows you to run chown owner on files before processing
* **RUN\_CHGRP** - allows you to run chgrp group on files before processing
* **RUN\_CHMOD** - allows you to run chmod +/-xxx on files before processing
* **HOLD\_DESTINATION** - directory to put post-processed files with no matching location to move to; i.e. misc stuff you download that might not be automated.
* **PORNSTARS\_DESTINATION** - directory to put porn star collections in. The matched tag from pp-taggers.txt will be appended to the path.
* **PORNSTARS\_KEEPERS\_DESTINATION** - directory to put porn star collections in that you want to keep seperate possibly for backup, the matched tag from pp-taggers.txt will be appended to the path. You probably don't need this.
* **PROCESSED\_DESTINATION** - directory to move processed torrent download directories to if **DEL\_PROCESSED\_DIRS** is set to false.
* **REPROCESS\_PATH** - directory to move torrent download directories to that were not processed automatically for some reason. You most likely don't need this. This is basically a debug feature.
* **SERIES\_DESTINATION** - directory to put porn series collections in. The matched tag from pp-taggers.txt will be appended to the path.
* **SERIES\_KEEPERS\_DESTINATION** - directory to put porn series collections in that you want to keep seperate possibly for backup. The matched tag from pp-taggers.txt will be appended to the path. You probably don't need this.

NOTE: The predefined destinations are just easy to type shortcuts. You can define individual full paths in pp-taggers.txt.

**Edit pp-deleters.txt** and add any file names, one per line, that you want deleted from the torrent's download directory. If you have **DEL\_PROCESSED\_DIRS** set to true there's no need for this as the directory will be deleted after processing. For the most part this is legacy pp but can be useful for deleting files from your non-porn downloads as well. The supplied pp-deleters.txt has examples given.

**Edit pp-renamers.txt** and add any strings you want replaced with a second string seperated by a comma, one per line. The supplied pp-renamers.txt has examples given. Becareful of gotchas replacing common words. Try to be as specific as possible. Processing is done top down so put any smaller strings below longer simular strings; i.e. if renaming `Blacked` and `BlackedRaw` be sure to list `BlackedRaw` before `Blacked`. You should already be aware of this from your "Must Contain" strings in QBittorrent's RSS Downloader.

**Edit pp-strippers.txt** and add any strings you want stripped from the downloaded torrent's file names. The supplied pp-strippers.txt has examples given. Be careful of gotchas stripping common words. Try to be as specific as possible. Processing is done top down so put any smaller strings below longer simular strings; i.e. if stripping `.1080p` be sure to list it after strings like `.XXX.1080p.MP4-KTR` or you'll get unwanted results.

**Edit pp-taggers.txt.** This is going to be the biggest and most important file to edit. It contains the variables for what to match, what to tag the match with, where to move the files to, and an optional genre tag. Your source comparison for this file should be your QBittorrent RSS Downloader Download Rules. The supplied pp-taggers.txt has examples given. Some more examples for you include:

* If you have a collection of Eva Elfie videos stored in a directory as a collection, you'd have a line such as `Eva.Elfie,Eva Elfie,pornstars,Russian` which would match "Eva.Elfie" from the torrent's download folder name, add "Eva Elfie" as the album tag, move the video to the designated "**PORNSTARS\_DESTINATION/Eva Elfie**," and add "Russian" to the genre along with the default "Porn" genre.

* If you collect the series ATKGirlfriends you'd have a line such as `ATKGirlfriends,same,series,` which would match ATKGirlfriends from the torrent's download folder name, add "ATKGirlfriends" as the album tag ("same" for tag equals whatever the match is, you could repeat "ATKGirlfriends" or use "same" to type less), and move the video to the designated "**SERIES\_DESTINATION/ATKGirlfriends**." No genre is specified so it will be tagged with the default "Porn" genre and nothing else. 

**NOTE:** In all cases you can override the predefined **PORNSTARS\_DESTINATION** and **SERIES\_DESTINATION** destinations with a full path such as "/porn/pornstars/Eva Elfie" or "/porn/series/ATKGirlfriends." 

**NOTE:** If you don't sort and/or collect porn stars and only want to process series, than you need to delete the lines of porn star names at the top of the file.

Your logs will look similar to this once you're setup:

![image](https://user-images.githubusercontent.com/127630165/224518527-c86906c0-f9e3-4600-960e-dfdface23996.png)

**MINOR BUG:**

* After processing a directory created by QBittorrent for a torrent's files that originally didn't have a subdirectory in the torrent (see the REQUIREMENTS' 3rd bulletpoint), an error saying "mv: cannot stat '/downloads/complete/PORN/torrentname': No such file or directory" will occur even though that directory gets moved to the **PROCESSED\_DESTINATION**.

**POSSIBLE** future updates:

* Move pornstars and series to seperate match files so that a series can be tagged as the "album" as well as tagging a matched pornstar to the "album artist" tag.
* Ability to add more than one custom genre. (Adding two or more genres in a comma seperate value file results in quotes that need to be parsed correctly before passing to exiftool)
* Process RAR and ZIP files. Some Tawainese porn comes packaged in RAR files. Due to the presumption that most people only run one torrent download program, it would only process RAR and ZIP files that were categorized as **PROCESS_CATEGORY**. I would probably just extract the archive before normal processing.
