DROP TABLE bank_accounts;
CREATE TABLE bank_accounts (
    iban        text PRIMARY KEY,
    owner       text NOT NULL,
    balance     numeric(20,2) DEFAULT 0 NOT NULL
);

INSERT INTO bank_accounts VALUES ('DE00000000000000000001', 'Martin', 100);
INSERT INTO bank_accounts VALUES ('DE00000000000000000002', 'Dave', 100);
INSERT INTO bank_accounts VALUES ('DE00000000000000000003', 'Robert', 100);

DROP TABLE bank_transactions;
CREATE TABLE bank_transactions (
    id                bigserial PRIMARY KEY,
    time_created      TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW() NOT NULL,
    iban              text NOT NULL,
    amount            numeric(20,2) DEFAULT 0 NOT NULL
);

-- TODO this should not be needed
CREATE OR REPLACE FUNCTION NOTIFY() RETURNS trigger AS
$BODY$
BEGIN
    PERFORM pg_notify('banktransactions', '');
    RETURN new;
END;
$BODY$
LANGUAGE 'plpgsql';

DROP TRIGGER IF EXISTS bank_transactions_trigger ON bank_transactions;
CREATE TRIGGER bank_transactions_trigger
AFTER INSERT
ON bank_transactions
FOR EACH ROW
EXECUTE PROCEDURE notify();


INSERT INTO bank_transactions (iban, amount) VALUES ('DE00000000000000000001', 10);
INSERT INTO bank_transactions (iban, amount) VALUES ('DE00000000000000000003', -11);
INSERT INTO bank_transactions (iban, amount) VALUES ('DE00000000000000000002', 30);
INSERT INTO bank_transactions (iban, amount) VALUES ('DE00000000000000000001', 3);
INSERT INTO bank_transactions (iban, amount) VALUES ('DE00000000000000000003', 50);
INSERT INTO bank_transactions (iban, amount) VALUES ('DE00000000000000000001', -5);
INSERT INTO bank_transactions (iban, amount) VALUES ('DE00000000000000000002', -8);
INSERT INTO bank_transactions (iban, amount) VALUES ('DE00000000000000000003', -20);
INSERT INTO bank_transactions (iban, amount) VALUES ('DE00000000000000000002', 20);

