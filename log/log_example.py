import psycopg2
import psycopg2.extensions
import select

conn = psycopg2.connect("dbname=postgres user=samba")
conn.autocommit = True
cursor = conn.cursor()

cursor.execute("SELECT create_log('orderdata')")

# some test data
cursor.execute("INSERT INTO log_orderdata VALUES ('order1')")
cursor.execute("INSERT INTO log_orderdata VALUES ('order2')")

# prod code
def main():
    while True:
        entry = read_log("orderdata", cursor)
        print("Received: " + entry)

# library code
# TODO currently after we receive an event we read the DB twice:
#  - once to read the entry
#  - second time when we re-enter the loop 
#  -> we can't rely on that event = entry, NOTIFY can be called manually without an INSERT
#  -> use a generator to make this nicer
#   or maybe this is ok for robustnes??
def read_log(log_name, cursor):
    cursor.execute(f"LISTEN log_{log_name};")
    while True:
        # read as long as there are DB entries in the queue
        cursor.execute(f"SELECT read_log_entry('{log_name}')")
        entry = cursor.fetchone() 
        if entry:
            return entry[0]

        # block until event is received or timeout happens (100 years)
        select.select([conn],[],[], 3153600000) == ([],[],[])
        conn.poll()
        # "eat" all notifications
        conn.notifies[:] = []

if __name__ == "__main__":
    main()
    