#!/bin/bash

URL="localhost/api/v1"

ID_TOKEN=$1

function insert_user() {
    echo
    echo Inserting $1
    echo curl --data "'${1}'" -H id_token:$ID_TOKEN $URL/users/
    curl --data "'${1}'" -H id_token:$ID_TOKEN $URL/users/
}

while IFS= read user; do
    insert_user "${user}"
done
