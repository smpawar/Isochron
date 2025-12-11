# Isochron for Oracle: Installation

This guide will walk you through the steps to install the Isochron framework in your Oracle database.

## Prerequisites

- An Oracle database instance (12c or later recommended for native JSON support).
- A SQL client (like SQL*Plus or SQL Developer) with privileges to create users, tables, procedures, and other database objects.

## Installation Steps

1.  **Create the Isochron User and Schema**:

    The framework objects are stored in a dedicated schema named `isochron`. The `oracle/tables/log_table.sql` script includes the `CREATE USER` command. Run this script to create the `isochron` user. **Remember to replace `'your_password'` with a secure password.**

    ```sql
    -- From oracle/tables/log_table.sql
    CREATE USER isochron IDENTIFIED BY your_password;
    ALTER USER isochron QUOTA UNLIMITED ON users;
    GRANT CREATE SESSION, CREATE TABLE, CREATE PROCEDURE, CREATE SEQUENCE, CREATE TRIGGER TO isochron;
    ```

2.  **Create the Log Table**:

    Connect to the database as the `isochron` user and run the `oracle/tables/log_table.sql` script. This will create the `sp_execution_log` table and the partition management procedure.

    ```bash
    sqlplus isochron/your_password @oracle/tables/log_table.sql
    ```

3.  **Create the `call_and_log` Procedure**:

    Run the `oracle/stored_procedures/call_and_log.sql` script to create the core logging procedure.

    ```bash
    sqlplus isochron/your_password @oracle/stored_procedures/call_and_log.sql
    ```

4.  **Create the `generate_logged_call` Function**:

    Run the `oracle/helpers/generate_logged_call.sql` script to create the helper function.

    ```bash
    sqlplus isochron/your_password @oracle/helpers/generate_logged_call.sql
    ```

5.  **Schedule Partition Management (Optional but Recommended)**:

    The `isochron.add_daily_partition` procedure should be run regularly to create new partitions. You can schedule this using `DBMS_SCHEDULER`. Here's an example of a job that runs daily at midnight:

    ```sql
    BEGIN
      DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'ISOCHRON_ADD_PARTITION_JOB',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN isochron.add_daily_partition; END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=0; BYMINUTE=0; BYSECOND=0',
        enabled         => TRUE,
        comments        => 'Daily job to add a new partition to the Isochron log table.'
      );
    END;
    /
    ```

## Installation Verification

After completing the installation steps, you can verify that the objects were created successfully by connecting as the `isochron` user and running the following queries:

```sql
-- Check for the log table
SELECT table_name FROM user_tables WHERE table_name = 'SP_EXECUTION_LOG';

-- Check for the procedure and function
SELECT object_name, object_type FROM user_objects WHERE object_name IN ('CALL_AND_LOG', 'GENERATE_LOGGED_CALL');
```

You are now ready to use the Isochron for Oracle framework. See the [EXAMPLES.md](oracle_EXAMPLES.md) file for usage examples.
