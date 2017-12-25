#!/bin/bash
# https://github.com/mb243/exifsort
#
function varbles() {

# The following are the only settings you should need to change:
#
# TS_AS_FILENAME: This can help eliminate duplicate images during sorting.
# TRUE: File will be renamed to the Unix timestamp and its extension.
# FALSE (any non-TRUE value): Filename is unchanged.

export TS_AS_FILENAME=TRUE
#
# USE_LMDATE: If this is TRUE, images without EXIF data will have their Last Modified file
# timestamp used as a fallback. If FALSE, images without EXIF data are put in noexif/ for
# manual sorting.
# Valid options are "TRUE" or anything else (assumes FALSE). FIXME: Restrict to TRUE/FALSE
#
export USE_LMDATE=TRUE
#
# USE_FILE_EXT: The following option is here as a compatibility option as well as a bugfix.
# If this is set to TRUE, files are identified using FILE's magic, and the extension
# is set accordingly. If FALSE (or any other value), file extension is left as-is.
# CAUTION: If set to TRUE, extensions may be changed to values you do not expect.
# See the manual page for file(1) to understand how this works. Jeff says on my system
#invalid file extensions are ignored and this only checks capitalisation
#
USE_FILE_EXT=TRUE
#
# JPEG_TO_JPG: The following option is here for personal preference. If TRUE, this will
# cause .jpg to be used instead of .jpeg as the file extension. If FALSE (or any other
# value) .jpeg is used instead.
#
export JPEG_TO_JPG=TRUE
#
#
# The following is an array of filetypes that we intend to locate using find.
# Any imagemagick-supported filetype can be used, but EXIF data is only present in
# jpeg and tiff. Script will optionally use the last-modified time for sorting (see above)
# Extensions are matched case-insensitive. *.jpg is treated the same as *.JPG, etc.
# Can handle any file type; not just EXIF-enabled file types. See USE_LMDATE above.
#
FILETYPES=("*.jpg" "*.jpeg" "*.png" "*.tif" "*.tiff" "*.gif" "*.xcf")
#
# Optional: Prefix of new top-level directory to move sorted photos to.
# Can be a relative pathspec, but an # absolute pathspec is recommended.
#
export moveto="test/"
x="${moveto: -1}"
if [[ $x != "/" ]]; then
  moveto="$moveto"/
fi

if [ ! -d "$moveto" ]; then
  echo $moveto does not exist, using current directory or q to quit
  moveto=""
  read -p  "q to quit, anything else to continue  " q
  if [[ $q == "q" ]]; then
    exit
  fi
fi


if [[ "$TS_AS_FILENAME" == "TRUE" ]]; then
  echo You are renaming files with the Unix timestamp
else
  echo You are using the existing file name
fi


if [[ "$USE_LMDATE" == "TRUE" ]]; then
  echo You are using modification date where exif data are unavailable
else
  echo Files with exif data will be put in a \'No exif directory\'
fi

if [[ "$USE_FILE_EXT" == "TRUE" ]]; then
  echo The file extension will go to lower case
else
  echo File extensions will be ignored
fi


if [[ "$JPEG_TO_JPG" == "TRUE" ]]; then
  echo File extension jpeg will be changed to jpg
fi

if [[ "$moveto" != "" ]]; then
  echo The directories will be created at "$moveto"
else
  echo The directories will be created at $PWD
fi

read -p  "q to quit, anything else to continue  " q
if [[ $q == "q" ]]; then
  exit
fi
}
#
###############################################################################
# End of settings. If you feel the need to modify anything below here, please share
# your edits at the url above so that improvements can be made to the script. Thanks!
#
#
# Assume find, grep, stat, awk, sed, tr, etc.. are already here, valid, and working.
# This may be an issue for environments which use gawk instead of awk, etc.
# Please report your environment and adjustments at the URL above.
#
###############################################################################
# Nested execution (action) call
# This is invoked when the programs calls itself with
# $1 = "doAction"
# $2 = <file to handle>
# This is NOT expected to be run by the user in this matter, but can be for single image
# sorting. Minor output issue when run in this manner. Related to find -print0 below.
#
# Are we supposed to run an action? If not, skip this entire section.

if [[ "$1" == "doAction" && "$2" != "" ]]; then
  # Check for EXIF and process it
  echo -n ": Checking EXIF... "
  DATETIME=`identify -verbose "$2" | grep "exif:DateTime:" | awk '{print $2" "$3}'`
  if [[ "$DATETIME" == "" ]]; then
    echo "not found."
    echo $USE_LMDATE
    if [[ $USE_LMDATE == "TRUE" ]]; then
      # I am deliberately not using %Y here because of the desire to display the date/time
      # to the user, though I could avoid a lot of post-processing by using it.
      DATETIME=`stat --printf='%y' "$2" | awk -F. '{print $1}' | sed y/-/:/`
      echo " Using LMDATE: $DATETIME"
    else
      echo " Moving to ./noexif/"
      mkdir -p "${moveto}noexif" && mv -b -f "$2" "${moveto}noexif"
      exit
    fi;
  else
    echo "found: $DATETIME"
  fi;
  # The previous iteration of this script had a major bug which involved handling the
  # renaming of the file when using TS_AS_FILENAME. The following sections have been
  # rewritten to handle the action correctly as well as fix previously mangled filenames.
  #
  EDATE=`echo $DATETIME | awk '{print $1}'`
  # Evaluate the file extension
  extension=`file -b "$2" | awk -F' ' '{print $1}' | tr '[:upper:]' '[:lower:]'`

  if [ "${USE_FILE_EXT}" != "TRUE" ]; then
    # Lowercase and use the current extension as-is
    extension=`echo "$2" | awk -F. '{print $NF}' | tr '[:upper:]' '[:lower:]'`
  fi;
  # Evaluate the file name

  if [[ "${extension}" == "jpeg" && "${JPEG_TO_JPG}" == "TRUE" ]]; then
  extension="jpg";
  fi


  if [ "$TS_AS_FILENAME" == "TRUE" ]; then
    # Get date and times from EXIF stamp
    ETIME=`echo $DATETIME | awk '{print $2}'`
    # Unix Formatted DATE and TIME - For feeding to date()
    UFDATE=`echo $EDATE | sed y/:/-/`
    # Unix DateSTAMP
    UDSTAMP=`date -d "$UFDATE $ETIME" +%s`
    echo " Will rename to $UDSTAMP.$extension"
    filename="/$UDSTAMP.$extension"
  else
    y=${2%.*} # strips everything after dot
    y=`echo $y | sed 's/^..//'`
    directoryname=`echo $EDATE | sed y-:-/-`
    directoryname=$directoryname/
    filename="${y}"
    filename=`basename $filename`
    filename=/$filename.$extension
  fi;
  
  # DIRectory NAME for the file move
  # sed issue for y command fix provided by thomas
  directoryname=`echo $EDATE | sed y-:-/-`
  if [ -f ${moveto}${directoryname}${filename} ]; then
    x=0
    while [ -f ${moveto}${directoryname}${filename} ]; do
      let "x+=1"
      filename=${filename%.*}
      filename=${filename%_*} #already a duplicate
      filename="${filename}_$x"
      filename="$filename.$extension"
    done;
    x=0
  fi
  echo -n " Moving to ${moveto}${directoryname}${filename} ... "
  mkdir -p "${moveto}${directoryname}" && mv -b -f "$2" "${moveto}${directoryname}${filename}"
  echo "done."
  echo ""
  exit
fi;
#
###############################################################################
# Scanning (find) loop
# This is the normal loop that is run when the program is executed by the user.
# This runs find for the recursive searching, then find invokes this program with the two
# parameters required to trigger the above loop to do the heavy lifting of the sorting.
# Could probably be optimized into a function instead, but I don't think there's an
# advantage performance-wise. Suggestions are welcome at the URL at the top.

varbles
for x in "${FILETYPES[@]}"; do
  # Check for the presence of imagemagick and the identify command.
  # Assuming its valid and working if found.
  I=`which identify`
  if [ "$I" == "" ]; then
    echo "The 'identify' command is missing or not available."
    echo "Is imagemagick installed?"
    exit 1
  fi;
  echo "Scanning for $x..."
  # FIXME: Eliminate problems with unusual characters in filenames.
  # Currently the exec call will fail and they will be skipped.
  #Jeff suggest maxdepth 1 to prevent multiple directories being corrupted by mistake
  #find . -maxdepth 1 -iname "$x" -print0 -exec sh -c "$0 doAction '{}'" \;
  find . -iname "$x" -print0 -exec sh -c "$0 doAction '{}'" \;

  echo "... end of $x"
done;
# clean up empty directories. Find can do this easily.
# Remove Thumbs.db first because of thumbnail caching
echo -n "Removing Thumbs.db files ... "
find . -name Thumbs.db -delete
echo "done."
echo -n "Cleaning up empty directories ... "
find . -empty -delete
echo "done."
