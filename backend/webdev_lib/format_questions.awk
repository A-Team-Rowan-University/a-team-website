#!/bin/awk -f

#
# { "title": "Title", "questions": [
#   { "title": "t", "correct_answer": "c", "incorrect_answer_1": "ic1", ... },
#   { "title": "t", "correct_answer": "c", "incorrect_answer_1": "ic1", ... },
#   { "title": "t", "correct_answer": "c", "incorrect_answer_1": "ic1", ... }
# ] }
#

BEGIN {
    FS = "\t"
}

# New category
$2 == "" {
    if (cend) {
        print "]}\n\n"
    }

    print "{\"title\":" $1 ", \"questions\": ["

    cend = 1
    qend = 0
}

# Question
$2 != "" {
    if (qend) {
        print ","
    }
    print "{ \"title\":" $1 ","
    print "\"correct_answer\":" $2 ","
    print "\"incorrect_answer_1\":" $3 ","
    print "\"incorrect_answer_2\":" $4 ","
    print "\"incorrect_answer_3\":" $5
    print "}"

    qend = 1
}

END {
    print "]}"
}

