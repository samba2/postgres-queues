import psycopg2

import select
import psycopg2
import psycopg2.extensions

conn = psycopg2.connect("dbname=postgres user=samba")
conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)

curs = conn.cursor()
curs.execute("LISTEN test;")

# in psql: 
# postgres=> notify test,'miau'; 
# 
# funktioniert super aber bitte verstehen wie das funktioniert
print("Waiting for notifications on channel 'test'")
while True:
    if select.select([conn],[],[],5) == ([],[],[]):
        print("Timeout")
    else:
        conn.poll()
        while conn.notifies:
            notify = conn.notifies.pop(0)
            print("Got NOTIFY:", notify.pid, notify.channel, notify.payload)