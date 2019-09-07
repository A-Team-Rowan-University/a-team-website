#!/bin/bash

export URL="localhost/api/v1"

export ID_TOKEN=$1

function insert_user() {
    echo
    echo Inserting $1
    echo curl --data "'${1}'" -H id_token:$ID_TOKEN $URL/users/
    curl --data "${1}" -H id_token:$ID_TOKEN $URL/users/
}

export -f insert_user
parallel insert_user {}
