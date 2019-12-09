-- log implementation (data is not deleted, like Kafka topics)
-- also supports autocleanup of read (consumed) values
CREATE OR REPLACE FUNCTION create_log(log_name text, expire_after_days integer DEFAULT 30) RETURNS void AS
$BODY$
DECLARE
    log_table_name text := 'log_' || log_name;
BEGIN
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %s (  
        value       text,
        inserted_at timestamptz DEFAULT now(),
        read_at     timestamptz,
        id          bigserial PRIMARY KEY)'
        , log_table_name);

    EXECUTE format('
        COMMENT ON TABLE %s IS ''expire_after_days=%s'''
        , log_table_name, expire_after_days);

    EXECUTE format('
        DROP TRIGGER IF EXISTS %s_trigger ON %s'
        , log_table_name, log_table_name);

    EXECUTE format('
        CREATE TRIGGER %s_trigger
        AFTER INSERT
        ON %s
        FOR EACH ROW
        EXECUTE PROCEDURE generic_queue_notify()'
        , log_table_name, log_table_name);
END;
$BODY$
LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION drop_log(log_name text) RETURNS void AS
$BODY$
DECLARE
    log_table_name text := 'log_' || log_name;
BEGIN
    EXECUTE format('DROP TABLE IF EXISTS %s', log_table_name);
END;
$BODY$
LANGUAGE 'plpgsql';


CREATE OR REPLACE FUNCTION read_log_entry(log_name text) RETURNS SETOF text AS
$BODY$
DECLARE
    log_table_name text := 'log_' || log_name;
    expire_after_days text;
BEGIN
    -- get expire date metadata from table description
    SELECT SPLIT_PART(OBJ_DESCRIPTION('log_b'::regclass), '=', 2) INTO expire_after_days;
    -- delete old stuff
    EXECUTE format('
        DELETE FROM %s 
        WHERE read_at IS NOT NULL 
        AND inserted_at < now() - ''%s days''::interval', log_table_name, expire_after_days);

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