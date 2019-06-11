#!/bin/bash

URL="localhost/api/v1"

ID_TOKEN=$1

function first_access {
    echo
    echo First Access Registration
    curl -H id_token:$ID_TOKEN $URL/access/first
}

function insert_users {
    echo
    echo Inserting John
    curl --data '{"first_name": "John", "last_name": "McAvoy", "banner_id": 987654321, "email": "mcavoyj5@students.rowan.edu", "accesses": []}' -H id_token:$ID_TOKEN $URL/users/
}

function insert_tests {

    echo
    echo Inserting questios
    cat test_questions.csv| awk -f ./format_questions.awk |
        parallel -d "\n\n" curl --data {} -H id_token:$ID_TOKEN $URL/question_categories/

    #echo
    #echo Inserting question category
    #curl --data '{"title":"ECE Safety"}' -H id_token:$ID_TOKEN $URL/question_categories/
    #echo
    #echo Inserting questions
    #curl --data '{
      #"title": "\"What is the answer?\"",
      #"correct_answer": "42",
      #"incorrect_answer_1": "45",
      #"incorrect_answer_2": "43",
      #"incorrect_answer_3": "12",
      #"category_id": 1
    #}' -H id_token:$ID_TOKEN $URL/questions/
    #curl --data '{
      #"title": "\"What is the other answer?\"",
      #"correct_answer": "qwerqwe",
      #"incorrect_answer_1": "asdfsaf",
      #"incorrect_answer_2": "qwerqwr",
      #"incorrect_answer_3": "sdfg89",
      #"category_id": 1
    #}' -H id_token:$ID_TOKEN  $URL/questions/
    #echo
    #echo Inserting question category
    #curl --data '{"title":"ECE Safety 2"}' -H id_token:$ID_TOKEN $URL/question_categories/
    #echo
    #echo Inserting questions
    #curl --data '{
      #"title": "\"What is the best answer?\"",
      #"correct_answer": "42ish",
      #"incorrect_answer_1": "45ish",
      #"incorrect_answer_2": "43ish",
      #"incorrect_answer_3": "12ish",
      #"category_id": 1
    #}' -H id_token:$ID_TOKEN $URL/questions/
    #curl --data '{
      #"title": "\"What is the other best answer?\"",
      #"correct_answer": "qwerqwe best",
      #"incorrect_answer_1": "asdfsaf best",
      #"incorrect_answer_2": "qwerqwr best",
      #"incorrect_answer_3": "sdfg89 best",
      #"category_id": 1
    #}' -H id_token:$ID_TOKEN  $URL/questions/
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

first_access
insert_users
insert_tests

