#!/bin/bash

set -uo pipefail
#set -x

trap "_ctrl_c" INT

function read_messages_forever() {
  local db_uri=$1
  local log_name=$2
  local per_message_callback=$3
  local message=

  _setup_poll "${db_uri}" "${log_name}"
  # read existing once
  _read_log_entries_from_db "${db_uri}" "${log_name}" "${per_message_callback}"
  while read line; do
    if echo "${line}" | grep -q "Asynchronous notification \"log_${log_name}\" received"; then
      _read_log_entries_from_db "${db_uri}" "${log_name}" "${per_message_callback}"
    fi
  done < ${output}
}

function _setup_poll() {
  local db_uri=$1
  local log_name=$2

  # setup polled psql in background
  input=$(mktemp -t --dry-run psql-input.XXXX)
  output=$(mktemp -t --dry-run psql-output.XXXX)
  mkfifo ${input} ${output}
  psql "${db_uri}" < ${input}  2>&1 > ${output} &
  psql_pid=$!
  exec 3>${input}
  _poll_loop "${log_name}" &
  poll_loop_pid=$!
}

function _poll_loop() {
  local log_name=$1

  echo "LISTEN log_${log_name};" >&3
  while true; do
    echo "SELECT 1;" >&3
    sleep 1
  done
}

function _read_log_entries_from_db() {
  local db_uri=$1
  local log_name=$2
  local per_message_callback=$3
  local message=

  while true; do
    message=$(echo "SELECT read_log_entry('${log_name}')" | psql -qtAX "${db_uri}")
    if [ "${message}" ]; then
      ${per_message_callback} "${message}"
    else
      break
    fi
  done
}

function _ctrl_c() {
  echo "Exiting"
  kill ${poll_loop_pid}
  kill ${psql_pid}
  rm -f ${input}
  rm -f ${output}
  exit
}


function print_message() {
  local message=$1
  echo "Received: ${message}"
}

read_messages_forever "postgres://samba@/postgres" "orderdata" "print_message"