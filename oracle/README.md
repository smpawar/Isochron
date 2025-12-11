# Isochron for Oracle

Isochron for Oracle is a lightweight framework for logging the execution of stored procedures in an Oracle database. It provides a simple way to capture runtime statistics, parameters, and success/failure status of your procedures.

## Features

- **Execution Logging**: Automatically log the start time, end time, and execution duration of your stored procedures.
- **Parameter Capture**: Store the parameters passed to your procedures in a JSON format.
- **Status Tracking**: Record whether a procedure call succeeded or failed.
- **Dynamic Procedure Calls**: A helper procedure allows you to call any stored procedure and have its execution logged automatically.
- **Table Partitioning**: The log table is partitioned by date to ensure efficient data management and querying.

## Core Components

- **`isochron.sp_execution_log` Table**: The central table where all execution data is stored.
- **`isochron.call_and_log` Procedure**: A stored procedure that takes the name of another procedure and its parameters, executes it, and logs the details to the `sp_execution_log` table.
- **`isochron.generate_logged_call` Function**: A helper function that generates the `call_and_log` invocation for a given procedure call.
- **Partition Management Procedure**: A procedure to automate the creation of new partitions for the log table.

## Getting Started

To get started with Isochron for Oracle, please see the [INSTALLATION.md](oracle_INSTALLATION.md) file for instructions on how to set up the framework in your database. For examples of how to use the framework, please refer to the [EXAMPLES.md](oracle_EXAMPLES.md) file.
