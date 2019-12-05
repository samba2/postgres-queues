DROP TABLE IF EXISTS queue;
CREATE TABLE queue (
    value       text,
    id          bigserial PRIMARY KEY
);

CREATE OR REPLACE FUNCTION queue_notify() RETURNS trigger AS
$BODY$
BEGIN
    PERFORM pg_notify('queue', '');
    RETURN new;
END;
$BODY$
LANGUAGE 'plpgsql';

DROP TRIGGER IF EXISTS queue_trigger ON queue;
CREATE TRIGGER queue
AFTER INSERT
ON queue
FOR EACH ROW
EXECUTE PROCEDURE queue_notify();