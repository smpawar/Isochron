-- 1. Create a sample user/schema to own the example procedure
-- Run this block as a privileged user (e.g., SYS or SYSTEM)
CREATE USER my_schema IDENTIFIED BY a_secure_password;
ALTER USER my_schema QUOTA UNLIMITED ON users;
GRANT CREATE SESSION, CREATE PROCEDURE TO my_schema;
GRANT EXECUTE ON DBMS_LOCK TO my_schema;

-- 2. Grant the ISOCHRON user the ability to execute procedures owned by MY_SCHEMA
-- This is necessary for the call_and_log procedure to work.
-- Run this block as a privileged user (e.g., SYS or SYSTEM)
GRANT EXECUTE ANY PROCEDURE TO isochron;

-- 3. Create the example procedure
-- Connect as the 'my_schema' user before running this.
CREATE OR REPLACE PROCEDURE my_schema.my_procedure(
    p_name IN VARCHAR2,
    p_value IN NUMBER,
    p_is_active IN BOOLEAN
)
AS
BEGIN
    -- Simulate some work
    DBMS_LOCK.SLEEP(2);

    IF p_is_active THEN
        DBMS_OUTPUT.PUT_LINE('Procedure executed for ' || p_name || ' with value ' || p_value);
    ELSE
        DBMS_OUTPUT.PUT_LINE('Procedure is not active for ' || p_name);
    END IF;

    -- Simulate a failure condition
    IF p_value < 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Value cannot be negative.');
    END IF;
END;
/

-- 4. Grant specific execute rights from my_schema to isochron
-- Run this as the 'my_schema' user.
GRANT EXECUTE ON my_schema.my_procedure TO isochron;
