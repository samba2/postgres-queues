import psycopg2
import psycopg2.extensions
import select

CHANNEL="queue"

conn = psycopg2.connect("dbname=postgres user=samba")
conn.autocommit = True
conn.cursor().execute(f"LISTEN {CHANNEL};")
cursor = conn.cursor()

def main():
    while True:
        entry = read_queue_plpgsql()
        print("Received: " + entry)


# TODO make more robust (ignore events without value)
def read_queue_plpgsql():
    def read_single_queue_entry():
        cursor.execute('SELECT read_queue_entry()')
        return cursor.fetchone()[0]

    entry = read_single_queue_entry()        
    if entry:
        return entry
    if select.select([conn],[],[],60) == ([],[],[]):
        pass
    else:
        conn.poll()
        while conn.notifies:
            notify = conn.notifies.pop(0)
            return read_single_queue_entry()


def read_queue_all_python():
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