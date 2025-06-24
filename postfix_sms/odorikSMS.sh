#!/bin/bash

# odorikSMS.sh <recipient> <message>
USER=userid
PASSWORD=api_pwd
RECIPIENT=${1}
MESSAGE=${2}

curl -v -X POST -i https://www.odorik.cz/api/v1/sms -d user=$USER -d password=$PASSWORD -d recipient=$1 --data-urlencode message="$MESSAGE"
RC=$?
printf "\n"
exit ${RC}
