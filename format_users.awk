#!/bin/awk -f

#
# { "first_name": "fn", "last_name": "ln", "banner_id": 91600000, "email": "e@mail.com", "permissions": [
# 1,
# 2,
# 3,
# ] }
#

BEGIN {
    FS = ","
}

{
# Banner Id
banner_id=$2
# First Name
first_name=$3
# Last Name
last_name=$4
# Email
email=$5

print "{\"first_name\": \"" first_name "\", \"last_name\": " last_name "\", \"banner_id\": " banner_id "\", \"email\": " email "\", \"permissions\": [] }"
}

END {
}
