CREATE SCHEMA IF NOT EXISTS isochron;
--DROP TABLE isochron.sp_execution_log;
-- Control table to store execution information of stored procedures
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


-- Automate partitions creation for sp_execution_log table, create 7 partitions in advance
SELECT partman.create_parent(
    p_parent_table => 'isochron.sp_execution_log'::text,
    p_control => 'log_date'::text,
    p_type => 'native'::text,
    p_interval => 'daily'::text,
    p_premake => 7::integer,
    p_automatic_maintenance => 'on'::text
);
--  clean log partitions every 7 days
UPDATE partman.part_config
	SET retention = '7 days'
	WHERE parent_table = 'isochron.sp_execution_log';
-- clean partitions manually
SELECT partman.run_maintenance(p_parent_table => 'isochron.sp_execution_log');
