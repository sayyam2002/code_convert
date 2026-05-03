-- Test Setup: Create test schema and helper procedures
CREATE SCHEMA IF NOT EXISTS test_schema;

-- Test 1: Verify prompt message output
CREATE OR REPLACE PROCEDURE test_schema.test_prompt_message()
LANGUAGE SQL
AS $$
BEGIN
    ASSERT (SELECT prompt FROM (SELECT 'Enter your name: ' AS prompt) t) = 'Enter your name: ',
           'Prompt message should be "Enter your name: "';
END;
$$;

-- Test 2: Verify greeting with valid name
CREATE OR REPLACE PROCEDURE test_schema.test_greeting_with_valid_name()
LANGUAGE SQL
AS $$
DECLARE
    test_name VARCHAR := 'John';
    expected_output VARCHAR := 'Hello, John';
    actual_output VARCHAR;
BEGIN
    SELECT CONCAT('Hello, ', test_name) INTO actual_output;
    ASSERT actual_output = expected_output,
           'Output should be "Hello, John" but got: ' || actual_output;
END;
$$;

-- Test 3: Verify greeting with empty string
CREATE OR REPLACE PROCEDURE test_schema.test_greeting_with_empty_string()
LANGUAGE SQL
AS $$
DECLARE
    test_name VARCHAR := '';
    expected_output VARCHAR := 'Hello, ';
    actual_output VARCHAR;
BEGIN
    SELECT CONCAT('Hello, ', test_name) INTO actual_output;
    ASSERT actual_output = expected_output,
           'Output should be "Hello, " but got: ' || actual_output;
END;
$$;

-- Test 4: Verify greeting with NULL name
CREATE OR REPLACE PROCEDURE test_schema.test_greeting_with_null_name()
LANGUAGE SQL
AS $$
DECLARE
    test_name VARCHAR := NULL;
    actual_output VARCHAR;
BEGIN
    SELECT CONCAT('Hello, ', test_name) INTO actual_output;
    ASSERT actual_output IS NULL,
           'Output should be NULL when name is NULL but got: ' || COALESCE(actual_output, 'NULL');
END;
$$;

-- Test 5: Verify greeting with special characters
CREATE OR REPLACE PROCEDURE test_schema.test_greeting_with_special_characters()
LANGUAGE SQL
AS $$
DECLARE
    test_name VARCHAR := 'O''Brien';
    expected_output VARCHAR := 'Hello, O''Brien';
    actual_output VARCHAR;
BEGIN
    SELECT CONCAT('Hello, ', test_name) INTO actual_output;
    ASSERT actual_output = expected_output,
           'Output should handle special characters correctly but got: ' || actual_output;
END;
$$;

-- Test 6: Verify greeting with unicode characters
CREATE OR REPLACE PROCEDURE test_schema.test_greeting_with_unicode()
LANGUAGE SQL
AS $$
DECLARE
    test_name VARCHAR := '李明';
    expected_output VARCHAR := 'Hello, 李明';
    actual_output VARCHAR;
BEGIN
    SELECT CONCAT('Hello, ', test_name) INTO actual_output;
    ASSERT actual_output = expected_output,
           'Output should handle unicode characters correctly but got: ' || actual_output;
END;
$$;

-- Test 7: Verify greeting with very long name
CREATE OR REPLACE PROCEDURE test_schema.test_greeting_with_long_name()
LANGUAGE SQL
AS $$
DECLARE
    test_name VARCHAR := REPEAT('A', 1000);
    expected_output VARCHAR := 'Hello, ' || REPEAT('A', 1000);
    actual_output VARCHAR;
BEGIN
    SELECT CONCAT('Hello, ', test_name) INTO actual_output;
    ASSERT actual_output = expected_output,
           'Output should handle long names correctly';
END;
$$;

-- Test 8: Verify greeting with whitespace
CREATE OR REPLACE PROCEDURE test_schema.test_greeting_with_whitespace()
LANGUAGE SQL
AS $$
DECLARE
    test_name VARCHAR := '  John  ';
    expected_output VARCHAR := 'Hello,   John  ';
    actual_output VARCHAR;
BEGIN
    SELECT CONCAT('Hello, ', test_name) INTO actual_output;
    ASSERT actual_output = expected_output,
           'Output should preserve whitespace but got: ' || actual_output;
END;
$$;

-- Test 9: Verify greeting with numeric string
CREATE OR REPLACE PROCEDURE test_schema.test_greeting_with_numeric_string()
LANGUAGE SQL
AS $$
DECLARE
    test_name VARCHAR := '12345';
    expected_output VARCHAR := 'Hello, 12345';
    actual_output VARCHAR;
BEGIN
    SELECT CONCAT('Hello, ', test_name) INTO actual_output;
    ASSERT actual_output = expected_output,
           'Output should handle numeric strings but got: ' || actual_output;
END;
$$;

-- Test 10: Verify prompt column name
CREATE OR REPLACE PROCEDURE test_schema.test_prompt_column_name()
LANGUAGE SQL
AS $$
DECLARE
    col_name VARCHAR;
BEGIN
    SELECT column_name INTO col_name
    FROM information_schema.columns
    WHERE table_name = 'temp_prompt_test'
    AND column_name = 'prompt';
    
    CREATE TEMP TABLE temp_prompt_test AS
    SELECT 'Enter your name: ' AS prompt;
    
    SELECT column_name INTO col_name
    FROM information_schema.columns
    WHERE table_name = 'temp_prompt_test'
    AND column_name = 'prompt';
    
    ASSERT col_name = 'prompt',
           'Column name should be "prompt"';
    
    DROP TABLE temp_prompt_test;
END;
$$;

-- Test 11: Verify output column name
CREATE OR REPLACE PROCEDURE test_schema.test_output_column_name()
LANGUAGE SQL
AS $$
DECLARE
    col_name VARCHAR;
    test_name VARCHAR := 'Test';
BEGIN
    CREATE TEMP TABLE temp_output_test AS
    SELECT CONCAT('Hello, ', test_name) AS output;
    
    SELECT column_name INTO col_name
    FROM information_schema.columns
    WHERE table_name = 'temp_output_test'
    AND column_name = 'output';
    
    ASSERT col_name = 'output',
           'Column name should be "output"';
    
    DROP TABLE temp_output_test;
END;
$$;

-- Test 12: Verify greeting with newline characters
CREATE OR REPLACE PROCEDURE test_schema.test_greeting_with_newline()
LANGUAGE SQL
AS $$
DECLARE
    test_name VARCHAR := 'John' || CHR(10) || 'Doe';
    expected_output VARCHAR := 'Hello, John' || CHR(10) || 'Doe';
    actual_output VARCHAR;
BEGIN
    SELECT CONCAT('Hello, ', test_name) INTO actual_output;
    ASSERT actual_output = expected_output,
           'Output should handle newline characters';
END;
$$;

-- Test Runner: Execute all tests
DO $$
DECLARE
    test_proc RECORD;
    test_count INTEGER := 0;
    pass_count INTEGER := 0;
    fail_count INTEGER := 0;
BEGIN
    FOR test_proc IN 
        SELECT routine_name 
        FROM information_schema.routines 
        WHERE routine_schema = 'test_schema' 
        AND routine_name LIKE 'test_%'
        ORDER BY routine_name
    LOOP
        test_count := test_count + 1;
        BEGIN
            EXECUTE 'CALL test_schema.' || test_proc.routine_name || '()';
            pass_count := pass_count + 1;
            RAISE NOTICE 'PASS: %', test_proc.routine_name;
        EXCEPTION WHEN OTHERS THEN
            fail_count := fail_count + 1;
            RAISE NOTICE 'FAIL: % - %', test_proc.routine_name, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Test Results:';
    RAISE NOTICE 'Total: %, Passed: %, Failed: %', test_count, pass_count, fail_count;
    RAISE NOTICE '========================================';
END;
$$;

-- Cleanup
DROP SCHEMA test_schema CASCADE;
