CREATE OR REPLACE FUNCTION make_queue(queue_name text) RETURNS void AS
$BODY$
BEGIN
    EXECUTE format('
        CREATE TABLE %s (  
        value       text, 
        id          bigserial PRIMARY KEY)'
        , queue_name);

    EXECUTE format('
        CREATE TRIGGER %s_trigger
        AFTER INSERT
        ON %s
        FOR EACH ROW
        EXECUTE PROCEDURE generic_queue_notify()'
        , queue_name, queue_name);

    RAISE NOTICE 'Queue "queue_name" was successfully created.';
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
BEGIN
    EXECUTE format('DROP TABLE IF EXISTS %s', queue_name);
    RAISE NOTICE 'Queue "queue_name" has been removed.';
END;
$BODY$
LANGUAGE 'plpgsql';


CREATE OR REPLACE FUNCTION read_queue_entry(queue_name text) RETURNS SETOF text AS
$BODY$
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
    , queue_name, queue_name);
END;
$BODY$
LANGUAGE 'plpgsql';