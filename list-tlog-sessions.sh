#!/bin/sh

SESSION_ID=$(journalctl -o verbose | grep -P "\"rec\".*?\." | awk -F\" '{print $12}' | sort -u)
SESSION_USER_ID=$(journalctl -o verbose | grep ${SESSION_ID} | grep -P "\"rec\".*?\." | head -1 | awk -F\" '{print $8}')
SESSION_EPOCH=$(journalctl -o verbose | grep ${SESSION_ID} | grep -P "\"rec\".*?\." | head -1 | awk -F\" '{print $29}' | cut -d : -f 2 | cut -d . -f 1)
SESSION_TIME=$(date -d @${SESSION_EPOCH} +"%m-%d-%Y %T")
echo "${SESSION_TIME}   user: ${SESSION_USER_ID}   session_id: ${SESSION_ID}"
