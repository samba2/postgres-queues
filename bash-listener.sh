#!/bin/bash
#set -x

trap ctrl_c INT

CHANNEL="test"

function ctrl_c() {
        echo "Exiting"
        kill ${poll_loop_pid}
        kill ${psql_pid}
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
# TODO mktemp
rm -rf fifo  
rm -rf output
mkfifo fifo output
# TODO use postgres://..  syntax as constant
psql -d postgres -U samba < fifo  2>&1 > output &
psql_pid=$!
exec 3>fifo
poll_loop &
poll_loop_pid=$!

# main loop
while read line; do
  if echo "${line}" | grep -q "Asynchronous notification \"${CHANNEL}\" received"; then
    # TODO fetch db
    echo "async"
  fi
done < output

