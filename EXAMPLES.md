# Isochron: Usage Examples and Testing

This document provides a set of practical examples to test the Isochron framework and demonstrate its features.

## Setup: Create Test Objects

First, run the following SQL to create a new schema and a few stored procedures for testing purposes. These examples cover different scenarios: a simple success case, a procedure with multiple parameter types, and a procedure that intentionally fails.

```sql
-- Create a dedicated schema for our test procedures
CREATE SCHEMA IF NOT EXISTS isochron_examples;

-- A simple dummy table for one of the procedures to write to
CREATE TABLE IF NOT EXISTS isochron_examples.test_log (
    id SERIAL PRIMARY KEY,
    message TEXT,
    logged_at TIMESTAMPTZ DEFAULT NOW()
);

-- TEST PROCEDURE 1: A simple procedure with no parameters that should succeed.
CREATE OR REPLACE PROCEDURE isochron_examples.log_message()
LANGUAGE plpgsql
AS $$
BEGIN
    -- This procedure simulates doing some work by inserting a message.
    INSERT INTO isochron_examples.test_log (message) VALUES ('log_message procedure executed successfully.');
END;
$$;

-- TEST PROCEDURE 2: A procedure with multiple data types as parameters.
CREATE OR REPLACE PROCEDURE isochron_examples.process_data(
    p_name TEXT,
    p_count INT,
    p_is_active BOOLEAN,
    p_process_date DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- This procedure doesn't perform any real action.
    -- It exists to show how different parameter types are logged by Isochron.
    RAISE NOTICE 'Processing data for % on %', p_name, p_process_date;
END;
$$;

-- TEST PROCEDURE 3: A procedure designed to fail.
CREATE OR REPLACE PROCEDURE isochron_examples.generate_error()
LANGUAGE plpgsql
AS $$
DECLARE
    v_result INT;
BEGIN
    -- This will cause a "division by zero" exception.
    v_result := 1 / 0;
END;
$$;
```

---

## Example 1: Logging a Simple, Successful Execution

This example calls the `log_message` procedure, which takes no parameters and should always succeed.

### Step 1: Execute the Procedure via Isochron

```sql
CALL isochron.call_and_log('isochron_examples.log_message');
```

### Step 2: Check the Logs

Query the log table to see the result. You can filter by the procedure name.

```sql
SELECT
    procedure_name,
    status,
    execution_time_ms,
    log_entry
FROM
    isochron.sp_execution_log
WHERE
    procedure_name = 'isochron_examples.log_message'
ORDER BY
    start_time DESC
LIMIT 1;
```

**Expected Output:** You will see a single row with `status = 'success'` and a short `execution_time_ms`. The `log_entry` will show 'Execution completed successfully.'

---

## Example 2: Logging a Call with Multiple Parameter Types

This example calls the `process_data` procedure, passing a JSON object with a string, a number, a boolean, and a date to demonstrate how parameters are captured.

### Step 1: Execute the Procedure via Isochron

```sql
CALL isochron.call_and_log(
    'isochron_examples.process_data',
    '{
        "p_name": "Test Customer",
        "p_count": 125,
        "p_is_active": true,
        "p_process_date": "2025-12-01"
    }'::jsonb
);
```

### Step 2: Check the Logs

Query the log table to see how the parameters were stored.

```sql
SELECT
    procedure_name,
    status,
    parameters
FROM
    isochron.sp_execution_log
WHERE
    procedure_name = 'isochron_examples.process_data'
ORDER BY
    start_time DESC
LIMIT 1;
```

**Expected Output:** You will see a `status = 'success'`. The `parameters` column will contain the full JSON object you passed in, demonstrating how Isochron keeps a perfect record of every call's inputs.

---

## Example 3: Logging a Failed Execution

This example calls the `generate_error` procedure, which is designed to fail. This demonstrates Isochron's ability to catch exceptions and log them.

### Step 1: Execute the Procedure via Isochron

```sql
CALL isochron.call_and_log('isochron_examples.generate_error');
```
*Note: This call will raise an exception, which is the expected behavior. Isochron catches this, logs it, and then re-raises it so you know the procedure failed.*

### Step 2: Check the Logs

Query the log table to see the failure record.

```sql
SELECT
    procedure_name,
    status,
    log_entry
FROM
    isochron.sp_execution_log
WHERE
    procedure_name = 'isochron_examples.generate_error'
ORDER BY
    start_time DESC
LIMIT 1;
```

**Expected Output:** You will see a row with `status = 'failed'`. The `log_entry` column will contain the actual database error message, for example: `Error: division by zero`. This is crucial for debugging failed runs.
