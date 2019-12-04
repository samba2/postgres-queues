import psycopg2
import time

conn = psycopg2.connect("dbname=postgres user=samba")

while True:
    cursor = conn.cursor()

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
        time.sleep(1)
        continue

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
    conn.commit()
    time.sleep(1)

conn.close()
