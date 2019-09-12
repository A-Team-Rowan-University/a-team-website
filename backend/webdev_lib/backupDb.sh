#!/bin/bash

DATE=`date '+%Y-%m-%d-%H-%M-%s'`
OUT_FILE="${DATE}_backup.sql"

docker exec ateamwebsite_db_1 /usr/bin/mysqldump -uroot -papple1 web_dev > $OUT_FILE
echo $OUT_FILE

if hash gdrive 2>/dev/null; then
    gdrive upload $OUT_FILE
else
    RED='\033[0;31m'
    NC='\033[0m' # No Color
    >&2 echo -e $RED gdrive is not installed. For more information go to https://github.com/gdrive-org/gdrive#installation $NC
fi
