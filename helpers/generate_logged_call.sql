-- This script creates a helper function to automate the creation of Isochron-logged calls.
CREATE OR REPLACE FUNCTION isochron.generate_logged_call(
    p_original_call TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_procedure_name TEXT;
    v_params_string TEXT;
    v_json_params JSONB := '{}'::jsonb;
    rec RECORD;
    v_final_command TEXT;
    v_key TEXT;
    v_value TEXT;
    v_cleaned_value TEXT;
    v_call_body TEXT;
BEGIN
    -- 1. Extract the procedure name using a corrected, single-line regular expression.
    -- The invalid newline character that caused the previous errors has been removed.
    SELECT (regexp_match(p_original_call, 'CALL\s+([a-zA-Z0-9_]+\.[a-zA-Z0-9_]+)\s*\('))[1]
    INTO v_procedure_name;

    IF v_procedure_name IS NULL THEN
        RAISE EXCEPTION 'Could not parse procedure name from the provided call statement. Ensure it is in the format "CALL schema.procedure(...)".';
    END IF;

    -- 2. Extract the full body of the call between the first '(' and the last ')'.
    v_call_body := substring(p_original_call from '\((.*)\)');

    -- 3. Pre-process the string to handle multi-line formatting by replacing newlines with spaces.
    v_params_string := regexp_replace(v_call_body, '[\n\r]+', ' ', 'g');

    -- 4. If there are parameters, parse them into a JSONB object.
    IF v_params_string IS NOT NULL AND trim(v_params_string) != '' THEN
        -- This regex captures key => value pairs. It handles quoted strings, numbers, booleans, and NULL.
        FOR rec IN
            SELECT
                (regexp_matches(v_params_string, '([a-zA-Z_][a-zA-Z0-9_]*)\s*=>\s*(''.*?''|[-+]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|TRUE|FALSE|NULL)', 'g')) AS match

        LOOP
            v_key := rec.match[1];
            v_value := trim(rec.match[2]);

            -- Convert the captured SQL value into a valid JSON value with the correct type.
            IF v_value ~ '^''.*''$ THEN
                -- It's a string, so remove the outer quotes.
                v_cleaned_value := substr(v_value, 2, length(v_value) - 2);
                v_json_params := jsonb_set(v_json_params, ARRAY[v_key], to_jsonb(v_cleaned_value));
            ELSIF upper(v_value) IN ('TRUE', 'FALSE') THEN
                 -- It's a boolean
                v_json_params := jsonb_set(v_json_params, ARRAY[v_key], to_jsonb(v_value::boolean));
            ELSIF upper(v_value) = 'NULL' THEN
                -- It's a NULL value
                v_json_params := jsonb_set(v_json_params, ARRAY[v_key], 'null'::jsonb);
            ELSE
                -- It must be a number
                v_json_params := jsonb_set(v_json_params, ARRAY[v_key], to_jsonb(v_value::numeric));
            END IF;
        END LOOP;
    END IF;

    -- 5. Construct the final, nicely formatted command string.
    v_final_command := 'CALL isochron.call_and_log(' || chr(10) ||
                       '    ''' || v_procedure_name || ''',' || chr(10) ||
                       '    ' || '''' || jsonb_pretty(v_json_params) || '''::jsonb' || chr(10) ||
                       ');';

    RETURN v_final_command;
END;
$$;
