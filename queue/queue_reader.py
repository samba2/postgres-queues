import psycopg2
import psycopg2.extensions
import select

CHANNEL="queue"

conn = psycopg2.connect("dbname=postgres user=samba")
conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)
conn.cursor().execute(f"LISTEN {CHANNEL};")
cursor = conn.cursor()

def main():
    while True:
        entry = read_queue()
        print("Received: " + entry)

def read_queue():
    entry=read_queue_entry()
    if entry:
        return entry

    if select.select([conn],[],[],60) == ([],[],[]):
        print("DEBUG Timeout")
    else:
        conn.poll()
        while conn.notifies:
            # pop is important to consume event
            notify = conn.notifies.pop(0)
            # print("DEBUG: Got NOTIFY:", notify.pid, notify.channel, notify.payload)
            return read_queue_entry()

def read_queue_entry():
    cursor.execute("""
    DELETE FROM queue
    WHERE id = (
    SELECT id
    FROM queue
    ORDER BY id
    FOR UPDATE SKIP LOCKED
    LIMIT 1
    )
    RETURNING *;
    """)

    entry=cursor.fetchone()
    if entry is None:
        return None
    else:
        return entry[0]

if __name__ == "__main__":
    main()