import psycopg2
import time
import select

notify_conn = psycopg2.connect("dbname=postgres user=samba")
notify_conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)
# notify_conn.autocommit=False

CHANNEL="banktransactions"

# TODO vermutlich tut es auch eine transaktion
def main():
    # notify_conn = psycopg2.connect("dbname=postgres user=samba")
    # notify_conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)

    curs = notify_conn.cursor().execute(f"LISTEN {CHANNEL};")
    print(f"Waiting for notifications on channel '{CHANNEL}'")

    # process existing records
    while process_one_transaction() is not None:
        pass

    # wait for new records
    while True:
        if select.select([notify_conn],[],[],5) == ([],[],[]):
            print("Timeout")
        else:
            notify_conn.poll()
            while notify_conn.notifies:
                # pop is important to consume event
                notify = notify_conn.notifies.pop(0)
                print("Got NOTIFY:", notify.pid, notify.channel, notify.payload)
                process_one_transaction()
    notify_conn.close()
    # conn.close()

def process_one_transaction():
    cursor = notify_conn.cursor()
    cursor.execute("""
    DELETE FROM bank_transactions
    WHERE id = (
    SELECT id
    FROM bank_transactions
    ORDER BY id
    FOR UPDATE SKIP LOCKED
    LIMIT 1
    )
    RETURNING *;
    """)

    transaction=cursor.fetchone()
    if transaction is None:
        print("No transaction found")
        return None

    iban=transaction[2]
    amount=transaction[3]

    cursor.execute(f"""
    SELECT balance FROM bank_accounts
    WHERE iban='{iban}'
    """)
    old_balance=cursor.fetchone()[0]

    cursor.execute(f"""
    UPDATE bank_accounts
    SET balance=balance+{amount}
    WHERE iban='{iban}'
    RETURNING balance
    """)
    new_balance=cursor.fetchone()[0]

    print(f"""
    Updated account: '{iban}'
    Amount to be booked: {amount}
    Old balance: {old_balance}
    New balance is {new_balance}
    """)

    cursor.close()
    notify_conn.commit()
    return iban

if __name__ == '__main__': main()
