CREATE OR REPLACE FUNCTION isochron.generate_logged_call(
    p_original_call IN VARCHAR2
)
RETURN CLOB
IS
    v_procedure_name VARCHAR2(255);
    v_params_string VARCHAR2(32767);
    v_json_params CLOB := ' F';
    v_final_command CLOB;
    v_key VARCHAR2(255);
    v_value VARCHAR2(32767);
    v_call_body VARCHAR2(32767);
    v_param_count NUMBER := 0;

BEGIN
    -- 1. Extract the procedure name
    v_procedure_name := REGEXP_SUBSTR(p_original_call, '([a-zA-Z0-9_]+\.[a-zA-Z0-9_]+)', 1, 1, NULL, 1);

    IF v_procedure_name IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Could not parse procedure name from the provided call statement.');
    END IF;

    -- 2. Extract the full body of the call between the first '(' and the last ')'.
    v_call_body := REGEXP_SUBSTR(p_original_call, '\((.*)\)', 1, 1, NULL, 1);

    -- 3. If there are parameters, parse them into a JSON object.
    IF v_call_body IS NOT NULL AND TRIM(v_call_body) IS NOT NULL THEN
        -- Loop through the key-value pairs
        FOR i IN 1..REGEXP_COUNT(v_call_body, '=>')
        LOOP
            v_key := TRIM(REGEXP_SUBSTR(v_call_body, '([a-zA-Z_][a-zA-Z0-9_]*)', 1, i, NULL, 1));
            v_value := TRIM(REGEXP_SUBSTR(v_call_body, '=>\s*(''.*?''|[-+]?\d+(\.\d+)?|TRUE|FALSE|NULL)', 1, i, NULL, 1));
            -- remove leading '=>'
            v_value := SUBSTR(v_value, 3);
            v_value := TRIM(v_value);

            IF v_param_count > 0 THEN
                v_json_params := v_json_params || ',';
            END IF;

            -- Add to JSON string
            v_json_params := v_json_params || '"' || v_key || '":';

            IF v_value LIKE '''%''' THEN -- String literal
                v_json_params := v_json_params || '"' || SUBSTR(v_value, 2, LENGTH(v_value) - 2) || '"';
            ELSIF UPPER(v_value) IN ('TRUE', 'FALSE', 'NULL') THEN
                 v_json_params := v_json_params || LOWER(v_value);
            ELSE -- Number
                v_json_params := v_json_params || v_value;
            END IF;

            v_param_count := v_param_count + 1;
        END LOOP;
    END IF;

    v_json_params := v_json_params || '}';

    -- 5. Construct the final command string.
    v_final_command := 'BEGIN isochron.call_and_log(' || CHR(10) ||
                       '    p_procedure_name => ''' || v_procedure_name || ''',' || CHR(10) ||
                       '    p_parameters => ''' || v_json_params || '''' || CHR(10) ||
                       '); END;';

    RETURN v_final_command;
END;
/
