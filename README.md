# Isochron: Stored Procedure Observability Framework

## What is Isochron?

Isochron is a simple yet powerful framework to automatically log the execution details of any stored procedure in PostgreSQL. It's designed for users who typically run procedures manually and want an easy way to track their performance and status without changing the procedure's code.

By making a small change to how you *call* your procedure, you get:
-   Automatic logging of start and end times.
-   Precise calculation of execution duration in milliseconds.
-   Tracking of success and failure states, with error messages included.
-   A historical record of all parameters used in each call.

## How to Use It

The process is straightforward. You simply wrap your existing stored procedure call inside the Isochron `call_and_log` procedure.

Let's take a common example.

### The OLD Way

You probably run your procedures manually in pgAdmin like this, using named parameters:

```sql
CALL financial_reports.generate_summary_report(
    report_type => 'weekly',
    start_date => '2024-01-01',
    end_date => '2024-01-07',
    user_id => 12345,
    is_final_run => FALSE
);
```

### The NEW Way with Isochron

To use Isochron, you make two simple changes to your call:

1.  Provide the **procedure name as a string** for the first argument.
2.  Convert your list of parameters into a **single JSON object** for the second argument.

Here is the same call, now wrapped with Isochron:

```sql
CALL isochron.call_and_log(
    'financial_reports.generate_summary_report',  -- 1. Procedure name as a string
    '{
        "report_type": "weekly",
        "start_date": "2024-01-01",
        "end_date": "2024-01-07",
        "user_id": 12345,
        "is_final_run": false
    }'::jsonb
);
```
That's it! Your procedure will execute exactly as it did before, but now its runtime and status will be logged automatically.

**Pro Tip:** For non-text parameters like numbers or booleans, you can write them directly in the JSON without quotes. This helps maintain the correct data types.

```sql
CALL isochron.call_and_log(
    'process.update_customer_stats',
    '{
        "customer_id": 4815,
        "force_recalc": true,
        "notes": "Manual run for Q3 corrections."
    }'::jsonb
);
```

### Calling Procedures without Parameters

If your procedure has no parameters, it's even simpler. Just provide the name.

**OLD Way:**
```sql
CALL maintenance.reindex_all_tables();
```

**NEW Isochron Way:**
```sql
CALL isochron.call_and_log('maintenance.reindex_all_tables');
```

## Viewing the Logs

All execution data is stored in the `isochron.sp_execution_log` table. You can easily query it to see the performance history of your procedures.

Here is a simple query to see the 10 most recent executions:

```sql
SELECT
    procedure_name,
    start_time,
    execution_time_ms,
    status,
    log_entry,
    parameters
FROM
    isochron.sp_execution_log
ORDER BY
    start_time DESC
LIMIT 10;
```

This will give you a clear overview of what ran, when it ran, how long it took, and whether it was successful.
