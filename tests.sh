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

function insert_tests {
    echo
    echo Inserting question category
    curl --data '{"title":"ECE Safety"}' $URL/question_categories/
    echo
    echo Inserting questions
    curl --data '{
      "title": "\"What is the answer?\"",
      "correct_answer": "42",
      "incorrect_answer_1": "45",
      "incorrect_answer_2": "43",
      "incorrect_answer_3": "12",
      "category_id": 1
    }' $URL/questions/
    curl --data '{
      "title": "\"What is the other answer?\"",
      "correct_answer": "qwerqwe",
      "incorrect_answer_1": "asdfsaf",
      "incorrect_answer_2": "qwerqwr",
      "incorrect_answer_3": "sdfg89",
      "category_id": 1
    }' $URL/questions/
    echo
    echo Inserting test
    curl --data '{
      "name": "ECE Safety Test 2",
      "creator_id": 2,
      "questions": [{
        "number_of_questions": 3,
        "question_category_id": 2
      },
      {
        "number_of_questions": 6,
        "question_category_id": 4
      },
      {
        "number_of_questions": 9,
        "question_category_id": 3
      },
      {
        "number_of_questions": 12,
        "question_category_id": 5
      }]
    }' $URL/tests/
}

insert_users
insert_tests

