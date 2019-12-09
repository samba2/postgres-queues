from contextlib import contextmanager
import psycopg2
import psycopg2.extensions
import select

conn = psycopg2.connect("dbname=postgres user=samba")

# prod code
def main():
    while True:
        # TODO move transaction to outside
        # https://github.com/malthe/pq/blob/b3381fee2f1a683c4178fd694a9c32af3aec5f55/pq/__init__.py#L182
        entry = read_log("orderdata", None)
        # raise
        print("Received: " + entry)


# library code
def read_log(log_name, cursor):
    while True:
        with transaction(conn) as cursor:
            # read as long as there are DB entries in the queue
            cursor.execute(f"SELECT read_log_entry('{log_name}')")
            entry = cursor.fetchone() 
            cursor.execute(f"LISTEN log_{log_name};")
            if entry:
                return entry[0]

        # block until event is received or timeout happens (100 years)
        select.select([conn],[],[], 3153600000) == ([],[],[])
        conn.poll()
        # "eat" all notifications
        conn.notifies[:] = []

@contextmanager
def transaction(conn, **kwargs):
    """Context manager.
    Execute statements within a transaction.
    >>> with transaction(conn) as cursor:
    ...     cursor.execute(...)
    ...     return cursor.fetchall()
    """

    cursor = conn.cursor(**kwargs)

    try:
        yield cursor
        conn.commit()
    except:
        conn.rollback()
        raise
    finally:
        cursor.close()

if __name__ == "__main__":
    main()
    