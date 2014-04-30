#!/bin/bash

# $1: link to m3u8
#$2 output file
# Download the m3u8 file, search for ts files, wget and combine them 

rm -f ts_1*
wget -T 30 -t 10 -q -O file.m3u8 "$1"

ts_files="`grep "\.ts" file.m3u8`"
index=0
for ts in $ts_files
do
   ts_out="ts_"`expr 1000 + $index`
   echo "`basename $ts` -> $ts_out"
   wget -T 30 -t 10 -q -O $ts_out $ts
   index=`expr $index + 1`
done

cat ts_1* > $2
rm -f ts_1* file.m3u8
