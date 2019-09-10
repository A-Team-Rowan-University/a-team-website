#!/bin/bash

DATE=`date '+%Y-%m-%d-%H-%M-%s'`
OUT_FILE="${DATE}_backup.sql"

docker exec resourcewebsite_db_1 /usr/bin/mysqldump -uroot -papple1 web_dev > $OUT_FILE
echo $OUT_FILE
gdrive upload $OUT_FILE
