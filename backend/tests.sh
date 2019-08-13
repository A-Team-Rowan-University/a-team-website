#!/bin/bash

URL="localhost/api/v1"

function insert_users {
    echo
    echo Inserting Tim
    curl --data '{"first_name": "Tim", "last_name": "Hollabaugh", "banner_id": 123456789, "email": "hollabaut1@students.rowan.edu"}' $URL/users/
    echo
    echo Inserting John
    curl --data '{"first_name": "John", "last_name": "McAvoy", "banner_id": 987654321, "email": "mcavoyj5@students.rowan.edu"}' $URL/users/
}

insert_users

