#!/bin/bash

# Discard common sendmail args (like -t -i)
while [[ "$1" =~ ^- ]]; do shift; done

# Read full email from stdin
email=$(cat)

# Optional: save for debugging
#echo "$email" > /tmp/last_email.txt

# Extract subject
subject=$(echo "$email" | grep -m1 '^Subject:' | sed 's/^Subject:[ \t]*//')

# Extract body
body=$(echo "$email" | sed -n '/^$/,$p' | tail -n +2)

# Combine and truncate
sms_text="${subject}-${body}"
sms_text=$(echo "$sms_text" | tr -d '\r' | tr -s '\n' ' ' | head -c 160)

# Send via your SMS wrapper
/usr/local/bin/odorikSMS.sh <phone_number> "$sms_text" 2>&1
