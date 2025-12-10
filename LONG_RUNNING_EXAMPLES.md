# Isochron: Long-Running Examples

This document provides examples of stored procedures that are designed to run for a noticeable amount of time (from several seconds to a few minutes). These are useful for testing how Isochron logs the `execution_time_ms` for tasks that are not instantaneous.

## Setup: Ensure Test Objects Exist

Before running these examples, please make sure you have first run the setup DDL from the `EXAMPLES.md` file. This ensures the `isochron_examples` schema and the `test_log` table are available.

---

## Example 1: Simulating a Computationally Intensive Report

This procedure simulates a task that takes a fixed amount of time to complete, such as a complex financial calculation or a heavy data aggregation report. We use the `pg_sleep()` function to introduce a delay.

### Step 1: Create the Procedure

```sql
CREATE OR REPLACE PROCEDURE isochron_examples.calculate_report_data(
    p_simulation_seconds INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Log the start of the simulation
    INSERT INTO isochron_examples.test_log (message)
    VALUES ('Starting computationally intensive report simulation for ' || p_simulation_seconds || ' seconds.');

    -- Use pg_sleep() to simulate a long-running process
    PERFORM pg_sleep(p_simulation_seconds);

    -- Log the end of the simulation
    INSERT INTO isochron_examples.test_log (message)
    VALUES ('Finished report simulation.');
END;
$$;
```

### Step 2: Execute the Procedure via Isochron

Let's run a simulation for 10 seconds. After executing this command, wait for at least 10 seconds for it to complete.

```sql
CALL isochron.call_and_log(
    'isochron_examples.calculate_report_data',
    '{"p_simulation_seconds": 10}'::jsonb
);
```

### Step 3: Check the Logs

Query the log table to verify the execution time.

```sql
SELECT
    procedure_name,
    status,
    execution_time_ms
FROM
    isochron.sp_execution_log
WHERE
    procedure_name = 'isochron_examples.calculate_report_data'
ORDER BY
    start_time DESC
LIMIT 1;
```

**Expected Output:** You will see a `status = 'success'`. The `execution_time_ms` should be slightly more than `10000` (10 seconds), accounting for minor overhead.

---

## Example 2: Simulating Large Dataset Processing

This procedure simulates a batch job that processes a large number of rows, where each row takes a small amount of time. This is common in ETL (Extract, Transform, Load) processes.

### Step 1: Create the Procedure

```sql
CREATE OR REPLACE PROCEDURE isochron_examples.process_large_dataset(
    p_row_count INT,
    p_delay_per_row_ms INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_delay_seconds double precision;
BEGIN
    -- Calculate the delay per row in seconds (as a floating-point number)
    v_delay_seconds := p_delay_per_row_ms / 1000.0;

    FOR i IN 1..p_row_count LOOP
        -- Simulate work being done on a row using pg_sleep()
        PERFORM pg_sleep(v_delay_seconds);
    END LOOP;
END;
$$;
```

### Step 2: Execute the Procedure via Isochron

Let's simulate processing 50 rows with a 100-millisecond delay for each. This should take approximately 5 seconds (50 rows * 0.1s/row).

```sql
CALL isochron.call_and_log(
    'isochron_examples.process_large_dataset',
    '{"p_row_count": 50, "p_delay_per_row_ms": 100}'::jsonb
);
```

### Step 3: Check the Logs

```sql
SELECT
    procedure_name,
    status,
    execution_time_ms,
    parameters
FROM
    isochron.sp_execution_log
WHERE
    procedure_name = 'isochron_examples.process_large_dataset'
ORDER BY
    start_time DESC
LIMIT 1;
```

**Expected Output:** You will see a `status = 'success'`. The `execution_time_ms` will be approximately `5000` milliseconds, plus a small amount of overhead.

---

## Example 3: Simulating a Multi-Step Archival Process

This procedure simulates a task with several distinct stages, such as a nightly data archival job that might connect to another system, transfer data, and then verify the transfer, with pauses between each step.

### Step 1: Create the Procedure

```sql
CREATE OR REPLACE PROCEDURE isochron_examples.data_archival_simulation()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Step 1: Connect to remote storage (simulated)
    INSERT INTO isochron_examples.test_log (message) VALUES ('Archival: Connecting to remote storage...');
    PERFORM pg_sleep(5); -- Simulate 5-second connection time

    -- Step 2: Transferring data (simulated)
    INSERT INTO isochron_examples.test_log (message) VALUES ('Archival: Transferring data...');
    PERFORM pg_sleep(10); -- Simulate 10-second data transfer

    -- Step 3: Verifying integrity (simulated)
    INSERT INTO isochron_examples.test_log (message) VALUES ('Archival: Verifying data integrity...');
    PERFORM pg_sleep(3); -- Simulate 3-second verification

    INSERT INTO isochron_examples.test_log (message) VALUES ('Archival: Complete.');
END;
$$;
```

### Step 2: Execute the Procedure via Isochron

This procedure has no parameters. It is designed to run for a total of 18 seconds (5 + 10 + 3).

```sql
CALL isochron.call_and_log('isochron_examples.data_archival_simulation');
```

### Step 3: Check the Logs

```sql
SELECT
    procedure_name,
    status,
    execution_time_ms
FROM
    isochron.sp_execution_log
WHERE
    procedure_name = 'isochron_examples.data_archival_simulation'
ORDER BY
    start_time DESC
LIMIT 1;
```

**Expected Output:** You will see a `status = 'success'`. The `execution_time_ms` should be slightly over `18000` milliseconds.