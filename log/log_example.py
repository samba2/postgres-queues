from contextlib import contextmanager
import psycopg2
import psycopg2.extensions
import select

message_log_connection = psycopg2.connect("dbname=postgres user=samba")

# prod code
def main():
    read_messages_forever(
        log_name="orderdata", 
        connection=message_log_connection, 
        per_message_callback=print_message)

def print_message(received_message):
    print("Received: " + received_message)


# library code
def read_messages_forever(log_name, connection, per_message_callback):

    @contextmanager
    def transaction(conn,):
        cursor = conn.cursor()
        try:
            yield cursor
            conn.commit()
        except:
            conn.rollback()
            raise
        finally:
            cursor.close()

    with transaction(connection) as cursor:
        cursor.execute(f"LISTEN log_{log_name};")

    while True:
        # read as long as there are DB entries in the queue        
        with transaction(connection) as cursor:
            cursor.execute(f"SELECT read_log_entry('{log_name}')")
            entry = cursor.fetchone() 
            if entry:
                per_message_callback(entry[0])
                continue

        # block until event is received or timeout happens (100 years)
        select.select([connection],[],[], 3153600000) == ([],[],[])
        connection.poll()
        # "eat" all notifications
        connection.notifies[:] = []


if __name__ == "__main__":
    main()
    