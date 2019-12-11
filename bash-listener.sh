#!/bin/bash

set -uo pipefail
#set -x

trap ctrl_c INT

CHANNEL="test"
POSTGRES_URL="postgres://samba@/postgres"

function ctrl_c() {
    echo "Exiting"
    kill ${poll_loop_pid}
    kill ${psql_pid}
    rm -f ${input}
    rm -f ${output}
    exit
}

function poll_loop() {
  echo "LISTEN ${CHANNEL};" >&3
  while true; do
    echo "SELECT 1;" >&3
    sleep 1
  done
}

# setup polled psql in background
input=$(mktemp -t --dry-run psql-input.XXXX)
output=$(mktemp -t --dry-run psql-output.XXXX)
mkfifo ${input} ${output}
psql "${POSTGRES_URL}" < ${input}  2>&1 > ${output} &
psql_pid=$!
exec 3>${input}
poll_loop &
poll_loop_pid=$!

# main loop
while read line; do
  if echo "${line}" | grep -q "Asynchronous notification \"${CHANNEL}\" received"; then
    echo "async"
    # TODO fetch db
#    message=$(echo "SELECT read_log_entry('orderdata')" | psql "postgres://samba@/postgres")
#    echo "${message}"
  fi
done < ${output}

