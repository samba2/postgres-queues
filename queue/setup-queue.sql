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

CREATE OR REPLACE FUNCTION read_queue_entry(queue_name text) RETURNS SETOF text AS
$BODY$
DECLARE
    QUEUE_READ_STATEMENT constant text := 
        'DELETE FROM %s '
        'WHERE id = ( '
            'SELECT id '
            'FROM %s '
            'ORDER BY id '
            'FOR UPDATE SKIP LOCKED '
            'LIMIT 1 '
        ') '
        'RETURNING value';
BEGIN
    RETURN QUERY EXECUTE format(QUEUE_READ_STATEMENT, queue_name, queue_name);
END;
$BODY$
LANGUAGE 'plpgsql';