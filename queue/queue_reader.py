import psycopg2
import psycopg2.extensions
import select

conn = psycopg2.connect("dbname=postgres user=samba")
conn.autocommit = True
cursor = conn.cursor()

cursor.execute("SELECT drop_queue('orderdata')")
# create table + trigger
cursor.execute("SELECT make_queue('orderdata')")

# some test data
cursor.execute("INSERT INTO orderdata VALUES ('order1')")
cursor.execute("INSERT INTO orderdata VALUES ('order2')")

# prod code
def main():
    while True:
        entry = read_queue("orderdata", cursor)
        print("Received: " + entry)

# library code
#
# TODO make more robust (ignore events without value)
def read_queue(queue_name, cursor):
    def read_single_queue_entry():
        cursor.execute(f"SELECT read_queue_entry('{queue_name}')")
        entry = cursor.fetchone() 
        if entry:
            return entry[0]
        else:
            return None

    cursor.execute(f"LISTEN {queue_name};")
    entry = read_single_queue_entry()        
    if entry:
        return entry
    if select.select([conn],[],[],60) == ([],[],[]):  # stops after 60 sec?
        pass
    else:
        conn.poll()
        while conn.notifies:
            notify = conn.notifies.pop(0)
            return read_single_queue_entry()

if __name__ == "__main__":
    main()