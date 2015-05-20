#!/bin/bash

# $1: link to m3u8
# $2 output file
# Download the m3u8 file, search for ts files, wget and combine them 

rm -f /tmp/ts_out $2
wget -T 30 -t 10 -q -O /tmp/file.m3u8 "$1"

ts_files="`grep "\.ts" /tmp/file.m3u8`"
nb_files=`echo "$ts_files" | wc -l`
index=1
for ts in $ts_files
do
   echo -en "Chunk $index / $nb_files\r"
   wget -T 30 -t 10 -q -O /tmp/ts_out $ts
   cat /tmp/ts_out >> $2
   index=`expr $index + 1`
done

echo ""
rm -f /tmp/ts_out /tmp/file.m3u8
