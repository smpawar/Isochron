# Isochron for Oracle: Examples

This file provides examples of how to use the Isochron framework to log the execution of your stored procedures in an Oracle database.

## Example Setup

To run the examples in this guide, you first need to create the sample user (`my_schema`) and the sample procedure (`my_schema.my_procedure`).

Please run the `oracle/setup_examples.sql` script. It contains all the necessary `CREATE USER`, `GRANT`, and `CREATE PROCEDURE` statements. You will need to run different parts of the script as a privileged user (like `SYS`) and as the `my_schema` user, as detailed in the comments within the file.

Once you have successfully run the setup script, you can proceed with the examples below.

## Manual Logging with `call_and_log`

You can manually call the `isochron.call_and_log` procedure to execute and log your procedure. The parameters are passed as a JSON string.

### Example 1: Successful Execution

```sql
BEGIN
  isochron.call_and_log(
    p_procedure_name => 'my_schema.my_procedure',
    p_parameters => '{"p_name": "test_user", "p_value": 123, "p_is_active": true}'
  );
END;
/
```

### Example 2: Failed Execution

```sql
BEGIN
  isochron.call_and_log(
    p_procedure_name => 'my_schema.my_procedure',
    p_parameters => '{"p_name": "error_case", "p_value": -1, "p_is_active": true}'
  );
END;
/
```

After running these examples, you can query the log table to see the results:

```sql
SELECT
    procedure_name,
    status,
    execution_time_ms,
    log_entry,
    parameters
FROM
    isochron.sp_execution_log
ORDER BY
    start_time DESC;
```

## Using `generate_logged_call` to Create the Logging Call

The `isochron.generate_logged_call` function can be used to generate the `call_and_log` invocation from a standard procedure call string. This is useful for interactive use or for generating scripts.

```sql
SET LONG 2000000
SET PAGESIZE 0
SELECT isochron.generate_logged_call('my_schema.my_procedure(p_name => ''test_user'', p_value => 123, p_is_active => TRUE)') FROM DUAL;
```

The output of the above query will be a string that you can copy and execute:

```sql
BEGIN isochron.call_and_log(
    p_procedure_name => 'my_schema.my_procedure',
    p_parameters => '{"p_name":"test_user","p_value":123,"p_is_active":true}'
); END;
```
