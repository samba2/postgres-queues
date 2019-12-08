Simple Queues With Plain Postgres
=================================

This is work in progres.

Idea
----
Provide easy to use and fast enough queues on plain Postgres. 

The whole solution is based on two builtin Postgres features:
- asynchronous notifications via [LISTEN/NOTIFY](https://www.postgresql.org/docs/current/sql-notify.html)
- [SKIP LOCKED](https://www.2ndquadrant.com/en/blog/what-is-select-skip-locked-for-in-postgresql-9-5/)

For convinience there are a couple of small PL/PGSQL functions like `create_queue()` or `delete_queue()`.
See [functions.sql](./functions.sql) for details.


Using A Queue
-------------

Create queue:
```
SELECT create_queue('orderdata');
```

Writing to the queue:
```
INSERT INTO queue_orderdata VALUES ('this is the payload');
```

Reading (Python example):
```python
conn = psycopg2.connect("dbname=postgres user=samba")
conn.autocommit = True
cursor = conn.cursor()

def main():
    while True:
        entry = read_queue("orderdata", cursor)
        print("Received: " + entry)
```

Delete queue:
```
SELECT delete_queue('orderdata');
```

Contribute
-----------
See [Makefile](./Makefile) for how to:
- install the functions in the database
- create a Python virtual env for testing


Currently Done
--------------
- simple FIFO queue
- [Python example](./queue_reader.py)
