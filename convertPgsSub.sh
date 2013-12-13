#!/bin/bash

ScriptName="`basename $0`"
TmpDir=/"home/staf/tmp/`basename $ScriptName`"

usage() {

	echo "Usage: $ScriptName inputFile.mkv outputFile"
	exit 1

}

if [ "$#" != "2" ]; then

	usage

fi

inputFile=$1
outputFile=$2

if [ ! -r "$inputFile" ]; then

	echo "Sorry, failed to read $inputFile"
	exit 1

fi

VideoTmpDir="$TmpDir/$inputFile"

if [ ! -d "$VideoTmpDir" ]; then

	mkdir -p $VideoTmpDir

	if [ $? != "0" ]; then

		echo "Sorry, failed to create $VideoTmpDir"
		exit 1

	fi

fi

IndexFile="$VideoTmpDir/index"

echo "Createing indexFile: $IndexFile"

mkvmerge -i $inputFile > $IndexFile

if [ $? != "0" ]; then

	echo "Sorry, mkvmerge -i $inputFile failed"
	exit 1

fi



cat $IndexFile | grep "PGS"

if [ $? != "0" ]; then

	echo "No, PGS subtitles found"
	exit 1


fi

# videoTracks=`cat $IndexFile | sed "1d" | head -n -1 | grep "^Track" |  sed -e 's/.*ID \(.*:\) \(.*\) (\(.*\))$/\1\2/' | sed -e 's/^\(.*\.\).*\(...\)$/\1\2/' | tr "\n" " "`

videoTracks=`cat $IndexFile | sed "1d" | head -n -1 | grep "^Track" |  sed -e 's/.*ID \(.*:\) \(.*\) (\(.*\))$/\1\2\.\3/' | sed -e 's/^\(.*\.\).*\(...\)$/\1\2/' | tr "A-Z" "a-z" | tr  "\n" " "`

echo "Executing mkvextract tracks $inputFile $videoTracks"

exit 2

# mkvextract tracks $inputFile $videoTracks

mergeTracks=""

for track in $videoTracks; do

	echo "t: $track"

	trackFile=`echo $track | cut -f2 -d ':'`

	echo $track | grep -E "\.pgs$"

	if [ $? = "0" ]; then

		outBasename=`echo $trackFile | cut -f 1 -d '.'`
		outSub="${outBasename}.sub"
		trackFile="${outBasename}.idx"

		java -jar BDSup2Sub.jar subtitles.pgs -o subtitles.sub

		if [ $? != "0" ]; then

			echo "Sorry, subtitle convertion failed"
			exit 1


		fi


	fi

	mergeTracks="$mergeTracks $trackFile"

done 

mkvmerge -o $outputFile $mergeTracks

if [ $? != "0" ]; then

	echo "Sorry, mkvmerge failed"
	exit 1


fi
