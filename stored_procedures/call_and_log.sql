CREATE OR REPLACE PROCEDURE isochron.call_and_log(
    IN p_procedure_name TEXT,
    IN p_parameters JSONB DEFAULT '{}'
)
LANGUAGE plpgsql
AS $$
DECLARE
    log_id BIGINT;
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_dynamic_sql TEXT;
    v_param_string TEXT;
    v_params_array TEXT[];
    rec RECORD;
BEGIN
    v_start_time := clock_timestamp();

    -- Log the start of the execution
    INSERT INTO isochron.sp_execution_log (procedure_name, parameters, start_time, status, log_date)
    VALUES (p_procedure_name, p_parameters, v_start_time, 'running', v_start_time::date)
    RETURNING id INTO log_id;
    COMMIT;

    BEGIN
        -- Dynamically construct the named parameter string from the JSONB object
        -- This handles different data types (string, number, boolean, null) correctly.
        FOR rec IN SELECT key, value FROM jsonb_each(p_parameters)
        LOOP
            IF jsonb_typeof(rec.value) = 'string' THEN
                v_params_array := array_append(v_params_array, rec.key || ' => ' || quote_literal(rec.value #>> '{}'));
            ELSE
                -- For number, boolean, null, we can just cast the jsonb value to text.
                v_params_array := array_append(v_params_array, rec.key || ' => ' || (rec.value::text));
            END IF;
        END LOOP;

        v_param_string := array_to_string(v_params_array, ', ');

        -- Construct the dynamic SQL to call the target procedure
        v_dynamic_sql := 'CALL ' || p_procedure_name || '(' || COALESCE(v_param_string, '') || ')';
        RAISE NOTICE 'Executing: %', v_dynamic_sql;

        -- Execute the dynamic SQL
        EXECUTE v_dynamic_sql;

        v_end_time := clock_timestamp();

        -- Log the successful execution
        UPDATE isochron.sp_execution_log
        SET
            end_time = v_end_time,
            execution_time_ms = EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000,
            status = 'success',
            log_entry = 'Execution completed successfully.'
        WHERE id = log_id;

    EXCEPTION
        WHEN OTHERS THEN
            v_end_time := clock_timestamp();
            -- Log the failed execution
            UPDATE isochron.sp_execution_log
            SET
                end_time = v_end_time,
                execution_time_ms = EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000,
                status = 'failed',
                log_entry = 'Error: ' || SQLERRM
            WHERE id = log_id;
            -- Re-raise the exception
            RAISE;
    END;
END;
$$;