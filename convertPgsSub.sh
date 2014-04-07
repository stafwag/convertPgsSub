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


BDSup2SubJar="/home/staf/scripts/jar/BDSup2Sub.jar"

ScriptName="`basename $0`"
TmpDir="/home/staf/tmp/`basename $ScriptName`"


echo "DEBUG: tmpDir= $TmpDir"

usage() {

	echo "Usage: $ScriptName inputFile.mkv outputFile"
	exit 1

}

if [ "$#" != "2" ]; then

	usage

fi

inputFile=$1
outputFile=$2

outputDir=`dirname $outputFile`
outputDir=`pwd`/$ouputDir
outputBaseFileName=`basename $outputFile`

outputFile="${outputDir}/${outputBaseFileName}"


echo "DEBUG: outputDir=\"$outputDir\""
echo "DEBUG: outputFile=\"$outputFile\""

if [ ! -r "$inputFile" ]; then

	echo "Sorry, failed to read $inputFile"
	exit 1

fi

VideoTmpDir="$TmpDir/`basename $inputFile`/"

if [ ! -d "$VideoTmpDir" ]; then

	echo "Creating:  $VideoTmpDir"

	mkdir -p $VideoTmpDir

	if [ $? != "0" ]; then

		echo "Sorry, failed to create $VideoTmpDir"
		exit 1

	fi

fi

cd $VideoTmpDir

if [ $? != "0" ]; then

	echo "Sorry, cd $VideoTmpDir failed"

	exit 1

fi

IndexFile="$VideoTmpDir/index"

rm $IndexFile > /dev/null

echo "Creating indexFile: $IndexFile: running  mkvmerge -I $inputFile > $IndexFile"
echo $IndexFile

mkvmerge -I  $inputFile > $IndexFile

if [ $? -ne  0 ]; then

	echo "Sorry, mkvmerge -I $inputFile failed"
	exit 1

fi


cat $IndexFile | grep "PGS" > /dev/null

if [ $? != "0" ]; then

	echo "No, PGS subtitles found"
	exit 1


fi

videoTracks=`cat $IndexFile | sed "1d" | head -n -1 | grep "^Track" |  sed -e 's/.*ID \(.*:\) \(.*\) (\(.*\)).*language:\(...\) .*$/\1\2\.\4.\3/' | sed -e 's/^\(.*\.\).*\(...\)$/\1\2/' | tr "A-Z" "a-z" | sed -e 's/^\(.*\)\:\(.*\)\.\(.*\)$/\1\:\2\.\1_\3/' | tr "\n" " "`

echo "Executing mkvextract tracks $inputFile $videoTracks"

echo "DEBUG: videoTracks: \"$videoTracks\""

echo "DEBUG: langTracks: \"$langTracks\""

mkvextract tracks $inputFile $videoTracks

if [ $? != "0" ]; then

	echo "Sorry, mkvextract tracks $inputFile $videoTracks failed"
	exit 1


fi


mergeTracks=""

for track in $videoTracks; do

	echo "t: $track"

	trackFile=`echo $track | cut -f2 -d ':'`

	echo $track | grep -E "pgs$"

	if [ $? = "0" ]; then

		outBasename=`echo $trackFile | cut -f 1 -d '.'`
		outSub="${outBasename}.sub"

		java -jar $BDSup2SubJar  $trackFile -o $trackFile.sub

		if [ $? != "0" ]; then

			echo "Sorry, subtitle convertion failed"
			exit 1


		fi

		trackFile="${trackFile}.idx"


	fi

	mergeTracks="$mergeTracks $trackFile"

done 

langTracks=`echo $mergeTracks | tr " " "\n" | sed '/^$/d' | sed -e 's/^\(\([^.]*\)\.\([^.]*\)\..*\)$/--language 0:\3 \1/' | tr "\n" " "`
echo "DEBUG: langTracks=\"$langTracks\""
echo "DEBUG: mergeTracks=\"$mergeTracks\""
echo "DEBUG: videoTracks=\"$videoTracks\""

mkvmerge -o ${outputFile} $langTracks

if [ $? != "0" ]; then

	echo "Sorry, mkvmerge failed \"mkvmerge -o ${outputFile}_lang $langTracks\""
	exit 1

fi

echo "DEBUG \"mkvmerge -o ${outputFile}_lang $langTracks\" executed"
