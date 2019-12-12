#!/bin/bash

set -uo pipefail
#set -x

### Library ###
function read_messages_forever() (
  trap "cleanup" INT

  local g_log_name=$1
  local g_db_uri=$2
  local g_per_message_callback=$3
  
  local g_poll_loop_pid=
  local g_psql_input=
  local g_psql_output=

  # started at the bottom
  function run_poll_loop() {
    # read existing once
    _read_log_entries_from_db
    _poll_psql
    while read line; do
      if echo "${line}" | \
         grep -q "Asynchronous notification \"log_${g_log_name}\" received"; then
        _read_log_entries_from_db
      fi
    done < ${g_psql_output}
  }

  function _read_log_entries_from_db() {
    local message=

    while true; do
      message=$(echo "SELECT read_log_entry('${g_log_name}')" | \
                psql --quiet --tuples-only --no-align --no-psqlrc "${g_db_uri}")
      if [ "${message}" ]; then
        ${g_per_message_callback} "${message}"
      else
        break
      fi
    done
  }

  function _poll_psql() {
    _setup_named_pipes
    psql --no-psqlrc "${g_db_uri}" < ${g_psql_input}  2>&1 > ${g_psql_output} &
    exec 3>${g_psql_input} # keep input open
    _poll_loop &
    g_poll_loop_pid=$!
  }

  function _setup_named_pipes() {
    g_psql_input=$(mktemp -t --dry-run psql-psql_input.XXXX)
    g_psql_output=$(mktemp -t --dry-run psql-psql_output.XXXX)
    mkfifo ${g_psql_input} ${g_psql_output}
  }
  
  function _poll_loop() {
    echo "LISTEN log_${g_log_name};" > ${g_psql_input}
    while true; do
      echo "SELECT 1;" > ${g_psql_input}
      sleep 1
    done
  }

  function cleanup() {
    echo "Exiting"
    kill ${g_poll_loop_pid} 2>/dev/null
    echo "end; \quit" > ${g_psql_input}
    rm -f ${g_psql_input}
    rm -f ${g_psql_output}
    exit
  }

  run_poll_loop
)


######   Production code #########
function print_message() {
  local message=$1
  echo "Received: ${message}"
}

read_messages_forever "orderdata" "postgres://samba@/postgres" "print_message"