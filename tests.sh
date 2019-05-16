#!/bin/bash

URL="localhost/api/v1"

ID_TOKEN='eyJhbGciOiJSUzI1NiIsImtpZCI6IjJjM2ZhYzE2YjczZmM4NDhkNDI2ZDVhMjI1YWM4MmJjMWMwMmFlZmQiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJhY2NvdW50cy5nb29nbGUuY29tIiwiYXpwIjoiOTE4MTg0OTU0NTQ0LWptMWF1ZnIzMWZpNnNkanMxMTQwcDdwM3JvdWFrYTE0LmFwcHMuZ29vZ2xldXNlcmNvbnRlbnQuY29tIiwiYXVkIjoiOTE4MTg0OTU0NTQ0LWptMWF1ZnIzMWZpNnNkanMxMTQwcDdwM3JvdWFrYTE0LmFwcHMuZ29vZ2xldXNlcmNvbnRlbnQuY29tIiwic3ViIjoiMTAzNDMxMzE0NDI4NDQ5OTAzOTQ3IiwiaGQiOiJzdHVkZW50cy5yb3dhbi5lZHUiLCJlbWFpbCI6ImhvbGxhYmF1dDFAc3R1ZGVudHMucm93YW4uZWR1IiwiZW1haWxfdmVyaWZpZWQiOnRydWUsImF0X2hhc2giOiJjc1ZMRm5vbjlwZmMweU9BZHNDS1l3IiwibmFtZSI6IlRpbW90aHkgSG9sbGFiYXVnaCIsInBpY3R1cmUiOiJodHRwczovL2xoNS5nb29nbGV1c2VyY29udGVudC5jb20vLUdNZlIwQi1aX0FjL0FBQUFBQUFBQUFJL0FBQUFBQUFBQUFjL3R2MzJhZmNXYzU4L3M5Ni1jL3Bob3RvLmpwZyIsImdpdmVuX25hbWUiOiJUaW1vdGh5IiwiZmFtaWx5X25hbWUiOiJIb2xsYWJhdWdoIiwibG9jYWxlIjoiZW4iLCJpYXQiOjE1NTgwNDY2MjYsImV4cCI6MTU1ODA1MDIyNiwianRpIjoiN2FkYjQxMzhkNWYxODBmNDU1Y2Q5MjRiZmU4MGY2MTZkYWY2ODhiNyJ9.d6FesTn66Qif_YqBJYHaW5tW1kFgkg5XMMbMoTfyV_KC_Vjpu-Mqh4SISIWL3KDPyf13CFI2BvMXZpA9Kdz-17h_VHQQ-MIRJHCuRiZotu8HTi_i8N_rCliWvDKQzjPp-pe9H9aIFs3Lb2HfMUudKikoqFT707j8hiWBA7YeH5KU74uBuEbRe2Ydp_N1NfqYAVf95x5baTzYPnwPLW2YRx3u_c1E1f-A-olQgbF6i1Zue3XspqsMB6jpx41V8tXeY49Id19Pjcq3fNH7SRF1gkWy3yO2QsESnlpG5c0KIic_1JlHFrdBe5yw_NqLzam85mxpEmu0i0rMr4A7zjWmBA'

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
}

insert_users
insert_tests

