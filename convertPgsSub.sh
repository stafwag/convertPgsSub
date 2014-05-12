#!/bin/bash

#
#  convertPgsSub.sh
#
#  Copyright (C) 2014  Staf Wagemakers Belgie/Belgium
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
# 


#
# basic settings
#


BDSup2SubJar="/home/staf/scripts/jar/BDSup2Sub.jar"

ScriptName="$(basename "$0")"
TmpDir="/home/staf/tmp"

Version="1.0.0preXXX"

cat <<-_END_OF_HEADER_ >&2
	${ScriptName}  version ${Version}
	Copyright (C) 2014  Staf Wagemakers Belgie/Belgium
	----------------------------------------------------------------------
_END_OF_HEADER_

#
# Usage
#

usage() {
	cat <<-_END_OF_HELP_ >&2
		Usage: ${ScriptName} -i inputFile.mkv -o outputFile.mkv [OPTION]

		Options:

		 -i	inputFile
		 -o	outputFile
		 -v	enable verbosity
		 -d	delete temporary files

	_END_OF_HELP_
	return 0
}

#
# getFullPathDir
#

getFullPathDir() {


	currentDir="$(pwd)"

	myDir="$(dirname "$1")"

	cd "$myDir"

	if [ $? != "0" ]; then

		echo "$myDir"

		return 1


	fi

	myDir="$(pwd)"

	cd "$currentDir"

	echo $myDir


	return 0

}

debug_vars() {
	((! Verbose || 0 == $#)) && return 0
	{	echo ''
		declare -p -- "$@" | sed -e 's/^/DEBUG: /'
		echo ''
	} >&2
	return 0
}

msg() {
	{	echo ''
		printf '%s\n' "$@"
		echo ''
	} >&2
	return 0
}

exit_msg() {
	local ret=$1
	shift
	msg "$@"
	exit "$ret"
}

#
# Get the options
#

declare    outputFile inputFile
declare -i Verbose DeleteIt

while getopts ":o:i:vdh" opt; do case "$opt" in
  (o)	outputFile="$OPTARG" ;;
  (i)	inputFile="$OPTARG"  ;;
  (v)	Verbose=1            ;;
  (d)	DeleteIt=1           ;;
  (h|*)	usage ; exit 0       ;;
esac ; done ; shift $((OPTIND-1))

#
# set TmpDir
#

debug_vars TmpDir

if [ ! -d $TmpDir ]; then
	exit_msg 1 "Sorry TmpDir: $TmpDir is not a directory"
fi

TmpDir="/home/staf/tmp/$(basename "$ScriptName")"

if [ ! -d $TmpDir ]; then

	msg "Creating $TmpDir:"

	mkdir "$TmpDir"

	if [ $? != "0" ]; then

		msg "Sorry, failed to create $TmpDir"

	fi 


fi

#
# settings
#

debug_vars outputFile inputFile Verbose DeleteIt

#
# outputFile and inputFile required
#

if [ -z "$inputFile" ] || [ -z "$outputFile" ]; then   

	msg "Sorry, inputFile and outputFile are required"
	usage 
	exit 1

fi

#
# set the outputFile to the fullpathdir
#


outputDir="$(getFullPathDir "$outputFile")"

outputBaseFileName="$(basename "$outputFile")"
outputFile="${outputDir}/${outputBaseFileName}"

debug_vars outputDir outputFile

#
# set the inputFile to the fullpathdir
#

inputDir="$(getFullPathDir "$inputFile")"

inputBaseFileName="$(basename "$inputFile")"
inputFile="${inputDir}/${inputBaseFileName}"

debug_vars inputDir inputFile

#
# no input, dont exec
#

if [ ! -r "$inputFile" ]; then
	exit_msg 1 "Sorry, failed to read $inputFile"
fi

#
# Create the VideoTmpDir or die
#

VideoTmpDir="$TmpDir/$(basename "$inputFile")/"

if [ ! -d "$VideoTmpDir" ]; then

	msg "Creating:  $VideoTmpDir"

	mkdir -p "$VideoTmpDir"

	if [ $? != "0" ]; then
		exit_msg 1 "Sorry, failed to create $VideoTmpDir"
	fi

fi

cd "$VideoTmpDir"

if [ $? != "0" ]; then
	exit_msg 1 "Sorry, cd $VideoTmpDir failed"
fi

#
# Create the video index file or die
#

IndexFile="$VideoTmpDir/index"

> $IndexFile > /dev/null

if [ $? != "0" ]; then
	exit_msg 1 "Sorry failed to create the IndexFile: $IndexFile"
fi

msg "Creating indexFile: $IndexFile: running  mkvmerge -I $inputFile > $IndexFile"
echo $IndexFile >&2

mkvmerge -I  "$inputFile" > "$IndexFile"

if [ $? != "0" ]; then
	exit_msg 1 "Sorry, mkvmerge -I $inputFile failed"
fi

#
# check if there are pgs subtitles
#

cat "$IndexFile" | grep "PGS" > /dev/null

if [ $? != "0" ]; then
	exit_msg 1 "No, PGS subtitles found"
fi

#
# Get the videoTracks from the index
#

videoTracks=$( \
  cat $IndexFile | sed "1d" | head -n -1 | grep "^Track" | \
  sed -e 's/.*ID \(.*:\) \(.*\) (\(.*\)).*language:\(...\) .*$/\1\2\.\4.\3/' | \
  sed -e 's/^\(.*\.\).*\(...\)$/\1\2/' | tr "A-Z" "a-z" | \
  sed -e 's/^\(.*\)\:\(.*\)\.\(.*\)$/\1\:\2\.\1_\3/' | tr "\n" " "
)

#
# extractIt
#

echo "Executing mkvextract tracks $inputFile $videoTracks" >&2

debug_vars videoTracks langTracks

mkvextract tracks "$inputFile" $videoTracks

if [ $? != "0" ]; then
	exit_msg 1 "Sorry, mkvextract tracks $inputFile $videoTracks failed"
fi

declare mergeTracks extraSubFiles

#
# convert the pgs subtitles
#

for track in $videoTracks; do

	msg "t: $track"

	trackFile="$(echo $track | cut -f2 -d ':')"

	echo "$track" | grep -E "pgs$"

	if [ $? = "0" ]; then

		outBasename="$(echo "$trackFile" | cut -f 1 -d '.')"
		outSub="${outBasename}.sub"

		java -jar "$BDSup2SubJar" "$trackFile" -o "${trackFile}.sub"

		if [ $? != "0" ]; then
			exit_msg 1 "Sorry, subtitle convertion failed"
		fi

		extraSubFiles="${extraSubFiles} ${trackFile}.sub ${trackFile}.idx"

		trackFile="${trackFile}.idx"

	fi

	mergeTracks="$mergeTracks $trackFile"

done 

#
# set the lang for each track
#

langTracks="$( \
  echo $mergeTracks | tr " " "\n" | \
  sed '/^$/d' | \
  sed -e 's/^\(\([^.]*\)\.\([^.]*\)\..*\)$/--language 0:\3 \1/' | \
  tr "\n" " "
)"

debug_vars langTracks mergeTracks videoTracks

#
# merge them
#

mkvmerge -o "${outputFile}" $langTracks

if [ $? != "0" ]; then
	exit_msg 1 "Sorry, mkvmerge failed \"mkvmerge -o ${outputFile}_lang $langTracks\""
fi

((Verbose)) && \
  msg "DEBUG \"mkvmerge -o ${outputFile}_lang $langTracks\" executed"

#
# delete the temporary files
#

if [ "$DeleteIt" ]; then

	debug_vars videoTracks extraSubFiles indexFile

	echo "Removing video tracks:"

	for file in $videoTracks; do

		fileToDel="$(echo $file | cut -f2- -d  ':')"

		if [ -f "$fileToDel" ]; then

		echo "deleting:  \"$fileToDel\""

			rm "$fileToDel"

			if [ $? != "0" ]; then
				exit_msg 1 "Sorry failed to delete \"$fileToDel\""
			fi

		fi

	done

	echo "Removing extra subFiles"

	for fileToDel in $extraSubFiles; do

		if [ -f "$fileToDel" ]; then

			echo "deleting:  \"$fileToDel\""

			rm "$fileToDel"

		fi

	done

	echo "Removing indexFile"

	rm "$IndexFile"

fi
