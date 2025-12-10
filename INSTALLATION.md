# Isochron: Installation Guide

This guide provides step-by-step instructions to install the Isochron observability framework in a new PostgreSQL database.

## Prerequisites

-   Access to a PostgreSQL database with administrative privileges.
-   The `pg_partman` extension must be available on your PostgreSQL server.

## Installation Steps

Follow these steps to set up Isochron. You can execute these SQL commands using a tool like pgAdmin, psql, or any other PostgreSQL client.

### Step 1: Install the `pg_partman` Extension

Isochron relies on `pg_partman` for automatic table partitioning. Before proceeding, you must enable the extension within your database. This typically requires superuser privileges.

```sql
CREATE EXTENSION IF NOT EXISTS pg_partman;
```

### Step 2: Create the Isochron Schema

Next, create the `isochron` schema to house all the framework's objects.

```sql
CREATE SCHEMA IF NOT EXISTS isochron;
```

### Step 3: Create the `sp_execution_log` Table

This table will store the execution details of your stored procedures. It includes columns for procedure name, parameters, start/end times, execution duration, status, and log entries. The table is partitioned by `log_date` for efficient data management. Note that the `PRIMARY KEY` now includes `id` and `log_date` as it's a partitioned table.

```sql
CREATE TABLE IF NOT EXISTS isochron.sp_execution_log(
    id BIGSERIAL NOT NULL,
    procedure_name TEXT NOT NULL,
    parameters JSONB,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    execution_time_ms BIGINT,
    status TEXT NOT NULL CHECK (status IN ('running', 'success', 'failed')),
    log_entry TEXT,
    log_date DATE NOT NULL,
    PRIMARY KEY (id, log_date)
) PARTITION BY RANGE (log_date);

CREATE INDEX idx_procedure_name_start_time ON isochron.sp_execution_log (procedure_name, start_time, log_date);
```

### Step 4: Configure `pg_partman` for Partitioning

Now, configure `pg_partman` to manage partitions for the `sp_execution_log` table. This ensures efficient storage and automatic cleanup of old log data. These commands set up daily partitions and define a retention policy of 7 days.

```sql
SELECT partman.create_parent(
    p_parent_table => 'isochron.sp_execution_log',
    p_control => 'log_date',
    p_interval => '1 day',
    p_premake => 7
);


UPDATE partman.part_config
	SET retention = '7 days',
    automatic_maintenance = 'on'
	WHERE parent_table = 'isochron.sp_execution_log';

-- (Optional) Run maintenance manually after configuration to ensure partitions are created immediately
SELECT partman.run_maintenance(p_parent_table => 'isochron.sp_execution_log');
```

### Step 5: Create the `call_and_log` Stored Procedure

This is the core procedure of the Isochron framework. It dynamically executes any specified stored procedure, captures its parameters, logs its start and end times, calculates execution duration, and records its final status (success or failure).

```sql
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
```

## Verification

After completing the above steps, you can verify the installation by calling a sample procedure and checking the `isochron.sp_execution_log` table. Refer to the `README.md` file for examples on how to wrap your procedure calls with `isochron.call_and_log`.