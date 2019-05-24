#!/bin/bash

URL="localhost/api/v1"

ID_TOKEN=$1
#ID_TOKEN='eyJhbGciOiJSUzI1NiIsImtpZCI6IjJjM2ZhYzE2YjczZmM4NDhkNDI2ZDVhMjI1YWM4MmJjMWMwMmFlZmQiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJhY2NvdW50cy5nb29nbGUuY29tIiwiYXpwIjoiOTE4MTg0OTU0NTQ0LWptMWF1ZnIzMWZpNnNkanMxMTQwcDdwM3JvdWFrYTE0LmFwcHMuZ29vZ2xldXNlcmNvbnRlbnQuY29tIiwiYXVkIjoiOTE4MTg0OTU0NTQ0LWptMWF1ZnIzMWZpNnNkanMxMTQwcDdwM3JvdWFrYTE0LmFwcHMuZ29vZ2xldXNlcmNvbnRlbnQuY29tIiwic3ViIjoiMTAzNDMxMzE0NDI4NDQ5OTAzOTQ3IiwiaGQiOiJzdHVkZW50cy5yb3dhbi5lZHUiLCJlbWFpbCI6ImhvbGxhYmF1dDFAc3R1ZGVudHMucm93YW4uZWR1IiwiZW1haWxfdmVyaWZpZWQiOnRydWUsImF0X2hhc2giOiJWdFVmQ3FMVG40dERvak5WUEkxVEhnIiwibmFtZSI6IlRpbW90aHkgSG9sbGFiYXVnaCIsInBpY3R1cmUiOiJodHRwczovL2xoNS5nb29nbGV1c2VyY29udGVudC5jb20vLUdNZlIwQi1aX0FjL0FBQUFBQUFBQUFJL0FBQUFBQUFBQUFjL3R2MzJhZmNXYzU4L3M5Ni1jL3Bob3RvLmpwZyIsImdpdmVuX25hbWUiOiJUaW1vdGh5IiwiZmFtaWx5X25hbWUiOiJIb2xsYWJhdWdoIiwibG9jYWxlIjoiZW4iLCJpYXQiOjE1NTgzMTA3NDksImV4cCI6MTU1ODMxNDM0OSwianRpIjoiYjM0ZjUzNTg4YWM2YWMzODFmMmJhNjBjYzJmNjE0NWM4ZTU5NDc2NSJ9.iJbpSdIfgpHDe1psDIruVp9fLj5LufyDHqdK-HV8HIo9dEuizY3EulqMOHc5fAHAK6BEpI5Qsts7UVFA_a_t45PRQl-y36HiHtxpfNhwbx4BMWnoz3H64wWADKXUQUnb7_-feDVccHsF_qEJVimuOLvoS9rYaK_hfh_rQcbn9fgEvzRDa-AA3arC3FYE_dz7RWFpL0OHGYRgL8Tq5RkVCQzIuTq_T962arsQ3JPBo0ZeVznX5W0cWU_yRqVKYN8LXdAxvG6_j0el5KjfEW0ethGSi4Y0vX24MtSqQvluACTdaDeUJA-MQ8bLHh9blnZ0gpLxNx8y1zm3PyMr3s9MCw'

function first_access {
    echo
    echo First Access Registration
    curl -H id_token:$ID_TOKEN $URL/access/first
}

function insert_users {
    echo
    echo Inserting John
    curl --data '{"first_name": "John", "last_name": "McAvoy", "banner_id": 987654321, "email": "mcavoyj5@students.rowan.edu"}' -H id_token:$ID_TOKEN $URL/users/
}

function insert_tests {
    echo
    echo Inserting question category
    curl --data '{"title":"ECE Safety"}' -H id_token:$ID_TOKEN $URL/question_categories/
    echo
    echo Inserting questions
    curl --data '{
      "title": "\"What is the answer?\"",
      "correct_answer": "42",
      "incorrect_answer_1": "45",
      "incorrect_answer_2": "43",
      "incorrect_answer_3": "12",
      "category_id": 1
    }' -H id_token:$ID_TOKEN $URL/questions/
    curl --data '{
      "title": "\"What is the other answer?\"",
      "correct_answer": "qwerqwe",
      "incorrect_answer_1": "asdfsaf",
      "incorrect_answer_2": "qwerqwr",
      "incorrect_answer_3": "sdfg89",
      "category_id": 1
    }' -H id_token:$ID_TOKEN  $URL/questions/
    echo
    echo Inserting question category
    curl --data '{"title":"ECE Safety 2"}' -H id_token:$ID_TOKEN $URL/question_categories/
    echo
    echo Inserting questions
    curl --data '{
      "title": "\"What is the best answer?\"",
      "correct_answer": "42ish",
      "incorrect_answer_1": "45ish",
      "incorrect_answer_2": "43ish",
      "incorrect_answer_3": "12ish",
      "category_id": 1
    }' -H id_token:$ID_TOKEN $URL/questions/
    curl --data '{
      "title": "\"What is the other best answer?\"",
      "correct_answer": "qwerqwe best",
      "incorrect_answer_1": "asdfsaf best",
      "incorrect_answer_2": "qwerqwr best",
      "incorrect_answer_3": "sdfg89 best",
      "category_id": 1
    }' -H id_token:$ID_TOKEN  $URL/questions/
    echo
    echo Inserting test
    curl --data '{
      "name": "ECE Safety Test 2",
      "creator_id": 2,
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

