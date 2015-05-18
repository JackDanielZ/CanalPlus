#!/bin/bash
# $1: id to download

OUTPUT=~/Desktop/CanalPlus
if [ ! -d $OUTPUT ]
then
   mkdir -p $OUTPUT
fi

if [ $# -eq 1 ]
then
   firstId=$1
   lastId=$1
   special=1
else
   rm -f index.html
   wget -T 30 -t 10 -q -O index.html "www.canalplus.fr"
   iconv -f iso-8859-1 -t ascii//TRANSLIT//IGNORE index.html > index.html2
   mv index.html2 index.html
   lastId=`cat index.html | grep 'vid=[0-9]' | sed 's/.*vid=\([0-9]*\).*/\1/' | cut -b 1-7 | sort -rg | head -n 1`
   rm -f index.html

   if [ -z "$lastId" ]
   then
      echo "Problem with lastId retrieval"
      exit
   fi

   firstId=`cat lastId`
   special=0
fi

echo FirstId $firstId LastId $lastId

for vid in `seq $firstId $lastId`
do
   URL=http://service.canal-plus.com/video/rest/getVideos/cplus/$vid
   wget -T 30 -t 10 -q -O index.html "$URL"
   rubrique=`cat index.html | sed -n 's/.*<RUBRIQUE>\([^<]*\)<\/RUBRIQUE>.*/\1/p' | tr ' ' '_'`
   categorie=`cat index.html | sed -n 's/.*<CATEGORIE>\([^<]*\)<\/CATEGORIE>.*/\1/p'`
   date=`cat index.html | sed -n 's/.*<DATE>\([^<]*\)<\/DATE>.*/\1/p' | sed -n 's/\(.*\)\/\(.*\)\/\(.*\)/\3_\2_\1/p'`
   link=`cat index.html | sed -n 's/.*<HLS>\([^<]*\)<\/HLS>.*/\1/p'`
   if [ -z "$link" ]
   then
      link=`cat index.html | sed -n 's/.*<BAS_DEBIT>\([^<]*\)<\/BAS_DEBIT>.*/\1/p'`
   fi
   rm -f index.html
   download=""
   if [ ! -z "$rubrique" ]
   then
      echo $rubrique $categorie $date $link
      if [ "$rubrique" = ZAPPING -a "$categorie" = EMISSION ]; then download="ZAPPING"; fi
      if [ "$rubrique" = LES_GUIGNOLS -a "$categorie" = QUOTIDIEN ]; then download="GUIGNOLS"; fi
      if [ "$rubrique" = GROLAND -a "$categorie" = EMISSION ]; then download="GROLAND"; fi
      if [ "$rubrique" = GROLAND_EMISSIONS -a "$categorie" = INTEGRALE ]; then download="GROLAND"; fi
      if [ "$rubrique" = "LE_PETIT_JOURNAL" -a "$categorie" = QUOTIDIEN ]; then download="PETIT_JOURNAL"; fi
      if [ "$rubrique" = "PETIT_JOURNAL" -a "$categorie" = EMISSION ]; then download="PETIT_JOURNAL"; fi
      if [ "$rubrique" = "LE_GRAND_JOURNAL" -a "$categorie" = GORAFI ]; then download="GORAFI"; fi
      if [ "$rubrique" = "CONNASSE" ]; then download="CONNASSE"; fi
      if [ "$rubrique" = "FILLES_D_AUJOURD_HUI" ]; then download="FILLES_D_AUJOURD_HUI"; fi
      if [ "$rubrique" = "L_OEIL_DE_LINKS" -a "$categorie" = EMISSION ]; then download="L_OEIL_DE_LINKS"; fi
   fi
   if [ $special -eq 1 -a -z "$download" ]
   then
      download="SPECIAL"
   fi


   echo $vid: $link
   if [ ! -z "$download" ]
   then
      if [ $special -eq 1 -o -z "`grep $link history`" ]
      then
         filename="$download"_"$date"_"$vid".mp4
         if [ ! -z "`echo $link | grep "m3u8"`" ]
         then
            rm -f $OUTPUT/$filename
            wget -T 30 -t 10 -q -O master.m3u8 "$link"
            sh Download_m3u8.sh `tail -n 1 master.m3u8` $OUTPUT/$filename
            rm -f master.m3u8
            res_dwnl=0
         fi
         if [ ! -z "`echo $link | grep "rtmp"`" ]
         then
            nb_tries=500
            res_dwnl=1
            while [ $nb_tries -ne 0 -a $res_dwnl -ne 0 ]
            do
               rm -f $OUTPUT/$filename
               rtmpdump -r $link -o $OUTPUT/$filename &
               rtmp_pid=$!
               last_dwnl_size=0
               frozen_dwnl=5
               while [ ! -z `ps -eo pid | grep $rtmp_pid` ]
               do
                  sleep 1;
                  dwnl_size=`stat -c "%s" $OUTPUT/$filename`
                  if [ $last_dwnl_size -eq $dwnl_size ]
                  then
                     frozen_dwnl=`expr $frozen_dwnl - 1`
                     echo "$filename: Frozen-- -> ($nb_tries;$frozen_dwnl)"
                     if [ $frozen_dwnl -eq 0 ]
                     then
                        echo "i$filename: Frozen -> kill"
                        kill -9 $rtmp_pid
                        wait $rtmp_pid
                     fi
                  else
                     last_dwnl_size=$dwnl_size
                     frozen_dwnl=5
                  fi
               done
               if [ $frozen_dwnl -ne 0 ]
               then
                  wait $rtmp_pid
                  res_dwnl=$?
                  if [ $res_dwnl -eq 0 -a $last_dwnl_size -le 1000000 ]
                  then
                     echo "OK but wrong size ($last_dwnl_size) -> do it again"
                     res_dwnl=1
                  fi
               fi
               nb_tries=`expr $nb_tries - 1`
            done
         fi
         if [ $res_dwnl -eq 0 ]
         then
            echo $link >> history
         else
            if [ -f $OUTPUT/$filename ]
            then
               rm $OUTPUT/$filename
               exit
            fi
         fi
      fi
   fi
   # In case no arg is given, we update the lastId file
   if [ $# -ne 1 ]
   then
      echo $vid > lastId
   fi
done
