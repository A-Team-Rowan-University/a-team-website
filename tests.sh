#!/bin/bash

URL="localhost/api/v1"

ID_TOKEN=$1

function first_permission {
    echo
    echo First Access Registration
    curl -H id_token:$ID_TOKEN $URL/permission/first
}

function insert_users {
    echo
    echo Inserting John
    curl --data '{"first_name": "John", "last_name": "McAvoy", "banner_id": 987654321, "email": "mcavoyj5@students.rowan.edu", "permissions": []}' -H id_token:$ID_TOKEN $URL/users/
}

function insert_tests {

    echo
    echo Inserting questios
    cat test_questions.csv| awk -f ./format_questions.awk |
        parallel -d "\n\n" curl --data {} -H id_token:$ID_TOKEN $URL/question_categories/

    echo
    echo Inserting test
    curl --data '{
      "name": "ECE Safety Test 2",
      "questions": [
        {
          "number_of_questions": 1,
          "question_category_id": 1
        },
        {
          "number_of_questions": 2,
          "question_category_id": 2
        }
      ]
    }' -H id_token:$ID_TOKEN  $URL/tests/

    echo
    echo Creating a test session
    curl --data '{
      "test_id": 1,
      "name": "ECE Safety Test Session 1"
    }' -H id_token:$ID_TOKEN  $URL/test_sessions/
}

first_permission
insert_users
insert_tests

