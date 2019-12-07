DROP TABLE IF EXISTS queue;
CREATE TABLE queue (
    value       text,
    id          bigserial PRIMARY KEY
);

-- trigger function
-- TODO make generic
CREATE OR REPLACE FUNCTION queue_notify() RETURNS trigger AS
$BODY$
BEGIN
    PERFORM pg_notify('queue', '');
    RETURN new;
END;
$BODY$
LANGUAGE 'plpgsql';

-- trigger requires trigger function
DROP TRIGGER IF EXISTS queue_trigger ON queue;
CREATE TRIGGER queue_trigger
AFTER INSERT
ON queue
FOR EACH ROW
EXECUTE PROCEDURE queue_notify();

CREATE OR REPLACE FUNCTION read_queue_entry() RETURNS text AS
$BODY$
DECLARE
    val text;
BEGIN
    DELETE FROM queue
    WHERE id = (
    SELECT id
    FROM queue
    ORDER BY id
    FOR UPDATE SKIP LOCKED
    LIMIT 1
    )
    RETURNING value into val;
    return val;
END;
$BODY$
LANGUAGE 'plpgsql';