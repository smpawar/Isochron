CREATE OR REPLACE PROCEDURE isochron.call_and_log(
    p_procedure_name IN VARCHAR2,
    p_parameters IN CLOB DEFAULT '{}'
)
AS
    log_id NUMBER;
    v_start_time TIMESTAMP WITH TIME ZONE;
    v_end_time TIMESTAMP WITH TIME ZONE;
    v_dynamic_sql CLOB;
    v_param_string VARCHAR2(32767);
    v_errm VARCHAR2(32767);

    -- JSON parsing variables
    jo JSON_OBJECT_T;
    keys JSON_KEY_LIST;
    v_key VARCHAR2(255);
    j_val JSON_ELEMENT_T;
    v_val_str VARCHAR2(32767);
BEGIN
    v_start_time := SYSTIMESTAMP;

    -- Log the start of the execution
    INSERT INTO isochron.sp_execution_log (procedure_name, parameters, start_time, status, log_date)
    VALUES (p_procedure_name, p_parameters, v_start_time, 'running', TRUNC(v_start_time))
    RETURNING id INTO log_id;
    COMMIT;

    BEGIN
        -- Dynamically construct the named parameter string from the JSON object
        jo := JSON_OBJECT_T.parse(p_parameters);
        keys := jo.get_keys;
        FOR i IN 1 .. keys.COUNT LOOP
            v_key := keys(i);
            j_val := jo.get(v_key);
            v_val_str := j_val.to_string();

            IF j_val.is_string THEN
                -- Value is a JSON string like "some text". Convert to SQL literal 'some text'
                -- 1. Substr to remove leading/trailing double quotes from JSON string
                -- 2. Replace any single quotes with two single quotes for SQL escaping
                -- 3. Wrap in single quotes for the literal
                v_param_string := v_param_string || v_key || ' => ' || '''' || REPLACE(SUBSTR(v_val_str, 2, LENGTH(v_val_str) - 2), '''', '''''') || '''' || ', ';
            ELSE
                -- Value is a number, boolean, or null. to_string() gives the direct literal.
                v_param_string := v_param_string || v_key || ' => ' || v_val_str || ', ';
            END IF;
        END LOOP;


        -- Remove trailing comma and space
        IF v_param_string IS NOT NULL THEN
            v_param_string := SUBSTR(v_param_string, 1, LENGTH(v_param_string) - 2);
        END IF;

        -- Construct the dynamic SQL to call the target procedure
        v_dynamic_sql := 'BEGIN ' || p_procedure_name || '(' || COALESCE(v_param_string, '') || '); END;';
        -- For debugging: DBMS_OUTPUT.PUT_LINE('Executing: ' || v_dynamic_sql);

        -- Execute the dynamic SQL
        EXECUTE IMMEDIATE v_dynamic_sql;

        v_end_time := SYSTIMESTAMP;

        -- Log the successful execution
        UPDATE isochron.sp_execution_log
        SET
            end_time = v_end_time,
            execution_time_ms = (EXTRACT(DAY FROM (v_end_time - v_start_time)) * 24 * 60 * 60 +
                                 EXTRACT(HOUR FROM (v_end_time - v_start_time)) * 60 * 60 +
                                 EXTRACT(MINUTE FROM (v_end_time - v_start_time)) * 60 +
                                 EXTRACT(SECOND FROM (v_end_time - v_start_time))) * 1000,
            status = 'success',
            log_entry = 'Execution completed successfully.'
        WHERE id = log_id;

    EXCEPTION
        WHEN OTHERS THEN
            v_end_time := SYSTIMESTAMP;
            v_errm := SQLERRM;
            -- Log the failed execution
            UPDATE isochron.sp_execution_log
            SET
                end_time = v_end_time,
                execution_time_ms = (EXTRACT(DAY FROM (v_end_time - v_start_time)) * 24 * 60 * 60 +
                                     EXTRACT(HOUR FROM (v_end_time - v_start_time)) * 60 * 60 +
                                     EXTRACT(MINUTE FROM (v_end_time - v_start_time)) * 60 +
                                     EXTRACT(SECOND FROM (v_end_time - v_start_time))) * 1000,
                status = 'failed',
                log_entry = 'Error: ' || v_errm
            WHERE id = log_id;
            -- Re-raise the exception
            RAISE;
    END;
    COMMIT;
END;
/
