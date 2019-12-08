-- queue implementation (data is deleted after read)
CREATE OR REPLACE FUNCTION create_queue(queue_name text) RETURNS void AS
$BODY$
DECLARE
    queue_table_name text := 'queue_' || queue_name;
BEGIN
    EXECUTE format('
        CREATE TABLE %s (  
        value       text, 
        id          bigserial PRIMARY KEY)'
        , queue_table_name);

    EXECUTE format('
        CREATE TRIGGER %s_trigger
        AFTER INSERT
        ON %s
        FOR EACH ROW
        EXECUTE PROCEDURE generic_queue_notify()'
        , queue_table_name, queue_table_name);

    RAISE NOTICE 'Table "%" was successfully created.', queue_table_name;
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
    RAISE NOTICE 'Table "%" has been removed.', queue_table_name;
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

-- log implementation (data is not deleted, like Kafka topics)
-- also supports autocleanup of read (consumed) values
CREATE OR REPLACE FUNCTION create_log(log_name text, expire_after_days integer DEFAULT 30) RETURNS void AS
$BODY$
DECLARE
    log_table_name text := 'log_' || log_name;
BEGIN
    EXECUTE format('
        CREATE TABLE %s (  
        value       text,
        inserted_at timestamptz DEFAULT now(),
        read_at     timestamptz,
        id          bigserial PRIMARY KEY)'
        , log_table_name);

    EXECUTE format('
        COMMENT ON TABLE %s IS ''expire_after_days=%s'''
        , log_table_name, expire_after_days);

    EXECUTE format('
        CREATE TRIGGER %s_trigger
        AFTER INSERT
        ON %s
        FOR EACH ROW
        EXECUTE PROCEDURE generic_queue_notify()'
        , log_table_name, log_table_name);

    RAISE NOTICE 'Table "%" was successfully created.', log_table_name;
END;
$BODY$
LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION read_log_entry(log_name text) RETURNS SETOF text AS
$BODY$
DECLARE
    log_table_name text := 'log_' || log_name;
    expire_after_days text;
BEGIN
    -- delete old stuff
    -- TODO too late now. read expiry date from comment and select into variable + use this var in DELETE below
    --SELECT SPLIT_PART(OBJ_DESCRIPTION('log_b'::regclass), '=', 2) INTO expire_after_days;
    EXECUTE format('
        DELETE FROM %s 
        WHERE read_at IS NOT NULL 
        AND inserted_at < now() - ''5 days''::interval', log_table_name);

    RETURN QUERY EXECUTE format('
        UPDATE %s SET read_at = now()
        WHERE id = ( 
            SELECT id 
            FROM %s 
            WHERE read_at IS NULL
            ORDER BY id 
            FOR UPDATE SKIP LOCKED 
            LIMIT 1 
        ) 
        RETURNING value'
    , log_table_name, log_table_name);
END;
$BODY$
LANGUAGE 'plpgsql';