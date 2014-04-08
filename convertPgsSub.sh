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

ScriptName="`basename $0`"
TmpDir="/home/staf/tmp"


#
# Usage
#

usage() {

	echo "Usage: $ScriptName -i inputFile.mkv -o outputFile.mkv [OPTION]" >&2
	echo >&2
	echo "Options:">&2
	echo >&2
	echo " -i	inputFile" >&2
	echo " -o	outputFile" >&2
	echo " -v	enable verbosity" >&2
	echo " -d	delete temporary files" >&2
	echo >&2
	exit 1

}


#
# Get the options
#

outputFile=""
inputFile=""
Verbose=""
DeleteIt=0

while getopts ":o:i:vdh" opt; do

  	case $opt in

    	o)
		outputFile="$OPTARG"
		;;
    	i)
		inputFile="$OPTARG"
		;;

	v)
		Verbose=1
		;;

	d)
		DeleteIt=1
		;;

    	h)
      		usage
      		;;

    	\?)
      		usage
      		;;

  esac


done

if [ "$Verbose" ]; then


echo "DEBUG: tmpDir= $TmpDir" >&2

fi

if [ ! -d $TmpDir ]; then

	echo "Sorry TmpDir: $TmpDir is not a directory" >&2
	exit 1

fi

TmpDir="/home/staf/tmp/`basename $ScriptName`"

if [ ! -d $TmpDir ]; then

	echo >&2
	echo "Creating $TmpDir:" >&2
	echo >&2


	mkdir $TmpDir

	if [ $? != "0" ]; then

		echo >&2
		echo "Sorry, failed to create $TmpDir" >&2
		echo >&2


	fi 


fi

if [ "$Verbose" ]; then


echo >&2
echo "outputFile=\"$outputFile\"" >&2
echo "inputFile=\"$inputFile\"" >&2
echo "verbose=\"$Verbose\"" >&2
echo "DeleteIt=\"$DeleteIt\"" >&2
echo >&2

fi

#
# outputFile and inputFile required
#

if [ -z "$inputFile" ] || [ -z "$outputFile" ]; then   

	echo >&2
	echo "inputFile and outputFile are required" >&2
	echo >&2

	usage

fi

#
# set the ouputFile to the fullpathname
#


outputDir=`dirname $outputFile`

if [ "$outputDir" = "." ]; then

	 outputDir=`pwd`/$ouputDir

fi 

outputBaseFileName=`basename $outputFile`
outputFile="${outputDir}/${outputBaseFileName}"

if [ "Verbose" ]; then

echo >&2
echo "DEBUG: outputDir=\"$outputDir\"" >&2
echo "DEBUG: outputFile=\"$outputFile\"" >&2
echo >&2

fi

#
# no input, dont exec
#

if [ ! -r "$inputFile" ]; then

	echo >&2
	echo "Sorry, failed to read $inputFile" >&2
	echo >&2
	exit 1

fi

#
# Create the VideoTmpDir or die
#

VideoTmpDir="$TmpDir/`basename $inputFile`/"

if [ ! -d "$VideoTmpDir" ]; then

	echo >&2
	echo "Creating:  $VideoTmpDir" >&2
	echo >&2

	mkdir -p $VideoTmpDir

	if [ $? != "0" ]; then

		echo >&2
		echo "Sorry, failed to create $VideoTmpDir" >&2
		echo >&2
		exit 1

	fi

fi

cd $VideoTmpDir

if [ $? != "0" ]; then

	echo >&2
	echo "Sorry, cd $VideoTmpDir failed" >&2
	echo >&2

	exit 1

fi

#
# Create the video index file or die
#

IndexFile="$VideoTmpDir/index"

> $IndexFile > /dev/null

if [ $? != "0" ]; then

	echo >&2
	echo "Sorry failed to create the IndexFile: $IndexFile" >&2
	echo >&2

	exit 1

fi

echo >&2
echo "Creating indexFile: $IndexFile: running  mkvmerge -I $inputFile > $IndexFile" >&2
echo $IndexFile >&2

mkvmerge -I  $inputFile > $IndexFile

if [ $? != "0" ]; then

	echo >&2
	echo "Sorry, mkvmerge -I $inputFile failed" >&2
	echo >&2
	exit 1

fi

#
# check if there are pgs subtitles
#

cat $IndexFile | grep "PGS" > /dev/null

if [ $? != "0" ]; then

	echo >&2
	echo "No, PGS subtitles found" >&2
	echo >&2
	exit 1


fi

videoTracks=`cat $IndexFile | sed "1d" | head -n -1 | grep "^Track" |  sed -e 's/.*ID \(.*:\) \(.*\) (\(.*\)).*language:\(...\) .*$/\1\2\.\4.\3/' | sed -e 's/^\(.*\.\).*\(...\)$/\1\2/' | tr "A-Z" "a-z" | sed -e 's/^\(.*\)\:\(.*\)\.\(.*\)$/\1\:\2\.\1_\3/' | tr "\n" " "`

echo "Executing mkvextract tracks $inputFile $videoTracks" >&2

if [ "Verbose" ]; then

	echo >&2
	echo "DEBUG: videoTracks: \"$videoTracks\"" >&2
	echo "DEBUG: langTracks: \"$langTracks\"" >&2
	echo >&2

fi

mkvextract tracks $inputFile $videoTracks

if [ $? != "0" ]; then

	echo >&2
	echo "Sorry, mkvextract tracks $inputFile $videoTracks failed" >&2
	echo >&2
	exit 1


fi

mergeTracks=""

for track in $videoTracks; do

	echo >&2
	echo "t: $track" >&2
	echo >&2

	trackFile=`echo $track | cut -f2 -d ':'`

	echo $track | grep -E "pgs$"

	if [ $? = "0" ]; then

		outBasename=`echo $trackFile | cut -f 1 -d '.'`
		outSub="${outBasename}.sub"

		java -jar $BDSup2SubJar  $trackFile -o $trackFile.sub

		if [ $? != "0" ]; then

			echo >&2
			echo "Sorry, subtitle convertion failed" >&2
			echo >&2

			exit 1


		fi

		trackFile="${trackFile}.idx"


	fi

	mergeTracks="$mergeTracks $trackFile"

done 

langTracks=`echo $mergeTracks | tr " " "\n" | sed '/^$/d' | sed -e 's/^\(\([^.]*\)\.\([^.]*\)\..*\)$/--language 0:\3 \1/' | tr "\n" " "`

if [ "$Verbose" ]; then

	echo >&2
	echo "DEBUG: langTracks=\"$langTracks\"" >&2
	echo "DEBUG: mergeTracks=\"$mergeTracks\"" >&2
	echo "DEBUG: videoTracks=\"$videoTracks\"" >&2
	echo >&2

fi

mkvmerge -o ${outputFile} $langTracks

if [ $? != "0" ]; then

	echo >&2
	echo "Sorry, mkvmerge failed \"mkvmerge -o ${outputFile}_lang $langTracks\"" >&2
	echo >&2

	exit 1

fi

if [ "$Verbose" ]; then

	echo >&2
	echo "DEBUG \"mkvmerge -o ${outputFile}_lang $langTracks\" executed"
	echo >&2

fi
