-- queue implementation (data is deleted after read)
CREATE OR REPLACE FUNCTION create_queue(queue_name text) RETURNS void AS
$BODY$
DECLARE
    queue_table_name text := 'queue_' || queue_name;
BEGIN
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %s (  
        value       text, 
        id          bigserial PRIMARY KEY)'
        , queue_table_name);

    EXECUTE format('
        DROP TRIGGER IF EXISTS %s_trigger ON %s'
        , queue_table_name, queue_table_name);

    EXECUTE format('
        CREATE TRIGGER %s_trigger
        AFTER INSERT
        ON %s
        FOR EACH ROW
        EXECUTE PROCEDURE generic_queue_notify()'
        , queue_table_name, queue_table_name);
END;
$BODY$
LANGUAGE 'plpgsql';


-- used by queue tables to perform the notification
CREATE OR REPLACE FUNCTION generic_queue_notify() RETURNS trigger AS
$BODY$
BEGIN
    PERFORM pg_notify(TG_TABLE_NAME, '');
    RETURN new;
END;
$BODY$
LANGUAGE 'plpgsql';


CREATE OR REPLACE FUNCTION drop_queue(queue_name text) RETURNS void AS
$BODY$
DECLARE
    queue_table_name text := 'queue_' || queue_name;
BEGIN
    EXECUTE format('DROP TABLE IF EXISTS %s', queue_table_name);
END;
$BODY$
LANGUAGE 'plpgsql';


CREATE OR REPLACE FUNCTION read_queue_entry(queue_name text) RETURNS SETOF text AS
$BODY$
DECLARE
    queue_table_name text := 'queue_' || queue_name;
BEGIN
    RETURN QUERY EXECUTE format('
        DELETE FROM %s 
        WHERE id = ( 
            SELECT id 
            FROM %s 
            ORDER BY id 
            FOR UPDATE SKIP LOCKED 
            LIMIT 1 
        ) 
        RETURNING value'
    , queue_table_name, queue_table_name);
END;
$BODY$
LANGUAGE 'plpgsql';