
-- ORSINI ORDERS — SILVER + GOLD SETUP - TRANFORMATION LOGIC JUST ASSUMPTON WILL CHANGE ONCE THE ACTUALS JUMPS IN 
-- Silver: one cleaned table 
-- Gold:   one per-customer sales summary (aggregated).
-- 1. SILVER TABLE — cleaned order lines 




CREATE OR REPLACE TABLE NEW_TEST.SILVER.ORDER_REPORTS (
    ORDER_LINE_KEY        VARCHAR(64),       -- SHA2(doc_id || '|' || line_id)
    TRANSACTION_DOCUMENT_NUMBER_ID VARCHAR(50),
    LINE_ID               NUMBER(38,0),
    ORDER_DATE            DATE,
    TRANSACTION_TYPE      VARCHAR(100),
    CUSTOMER_ENTITY_ID    VARCHAR(50),
    CUSTOMER_NAME         VARCHAR(200),
    SHIPPING_CITY         VARCHAR(200),
    SHIPPING_STATE        VARCHAR(10),
    SHIPPING_ZIP          VARCHAR(20),
    ITEM                  VARCHAR(50),
    AMOUNT                NUMBER(15,2),
    AMOUNT_NET            NUMBER(15,2),
    QUANTITY              NUMBER(38,0),
    SHIP_DATE             DATE,
    INVOICE_DATE          DATE,
    -- audit
    _AUDIT_CREATED_AT     TIMESTAMP_NTZ(9),
    _AUDIT_UPDATED_AT     TIMESTAMP_NTZ(9),
    _AUDIT_CREATED_BY     VARCHAR(100),
    _AUDIT_RUN_ID         VARCHAR(100),
    _AUDIT_SOURCE_RUN_ID  VARCHAR(100),
    _AUDIT_RECORD_HASH    VARCHAR(64),
    _AUDIT_IS_CURRENT     BOOLEAN,
    _AUDIT_DQ_STATUS      VARCHAR(20),
    _AUDIT_ENV            VARCHAR(20)
) COMMENT='Silver — cleaned Orsini order lines (quarantine-gated)';
 
 
-- ════════════════════════════════════════════════════════════════════
-- 2. GOLD TABLE — per-customer sales summary (one row per customer)
-- ════════════════════════════════════════════════════════════════════
CREATE OR REPLACE TABLE NEW_TEST.GOLD.ORDER_SUMMARY (
    CUSTOMER_KEY          VARCHAR(64),       -- SHA2(customer_entity_id)
    CUSTOMER_ENTITY_ID    VARCHAR(50),
    CUSTOMER_NAME         VARCHAR(200),
    TOTAL_ORDERS          NUMBER(38,0),      -- distinct documents
    TOTAL_LINES           NUMBER(38,0),      -- line count
    TOTAL_QUANTITY        NUMBER(38,0),
    TOTAL_AMOUNT          NUMBER(18,2),
    TOTAL_AMOUNT_NET      NUMBER(18,2),
    LAST_ORDER_DATE       DATE,
    -- audit
    _AUDIT_CREATED_AT     TIMESTAMP_NTZ(9),
    _AUDIT_UPDATED_AT     TIMESTAMP_NTZ(9),
    _AUDIT_CREATED_BY     VARCHAR(100),
    _AUDIT_RUN_ID         VARCHAR(100),
    _AUDIT_SOURCE_RUN_ID  VARCHAR(100),
    _AUDIT_RECORD_HASH    VARCHAR(64),
    _AUDIT_IS_CURRENT     BOOLEAN,
    _AUDIT_DQ_STATUS      VARCHAR(20),
    _AUDIT_ENV            VARCHAR(20)
) COMMENT='Gold — per-customer Orsini sales summary';

---------------sILVER & GOLD SP'S 

CREATE OR REPLACE PROCEDURE NEW_TEST.REFERENCE.SP_BUILD_SILVER_ORDERS("P_RUN_ID" VARCHAR, "P_ENV" VARCHAR, "P_RETRY_ATTEMPT" NUMBER(38,0) DEFAULT 0)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
  v_batch_id        VARCHAR := :P_RUN_ID;
  v_run_id          VARCHAR;
  v_config          VARIANT;
  v_load_type       VARCHAR;
  v_src_pipeline    VARCHAR;
  v_qtable          VARCHAR;
  v_qpk             VARCHAR;
  v_qgate           VARCHAR := '''';
  v_rows_read       NUMBER := 0;
  v_rows_inserted   NUMBER := 0;
  v_rows_updated    NUMBER := 0;
  v_rows_rejected   NUMBER := 0;
  v_insert_sql      VARCHAR;
  v_count_sql       VARCHAR;
  v_watermark_end   TIMESTAMP_NTZ;
  v_query_id        VARCHAR;
  v_dq_result       VARIANT;
  v_dq_status       VARCHAR;
  v_tests_passed    NUMBER := 0;
  v_tests_failed    NUMBER := 0;
  v_tests_warned    NUMBER := 0;
  v_is_retry        BOOLEAN;
  v_retry_reason    VARCHAR;
BEGIN
  v_is_retry := (:P_RETRY_ATTEMPT > 0);
  v_retry_reason := CASE WHEN v_is_retry THEN ''Retry attempt '' || :P_RETRY_ATTEMPT::VARCHAR ELSE NULL END;

  CALL NEW_TEST.AUDIT.LOG_PIPELINE_START(''SP_SILVER_ORDERS'', :P_ENV, :v_batch_id, :P_RETRY_ATTEMPT, :v_is_retry, :v_retry_reason) INTO :v_run_id;

  CALL NEW_TEST.REFERENCE.GET_PIPELINE_CONFIG(''SP_SILVER_ORDERS'', :P_ENV) INTO :v_config;
  v_load_type    := COALESCE(v_config:load_type::VARCHAR, ''FULL_REFRESH'');
  v_src_pipeline := TRIM(SPLIT_PART(v_config:depends_on_pipelines::VARCHAR, '','', 1));

  -- Resolve quarantine table + PK from registry for the SOURCE pipeline (dynamic)
  BEGIN
    SELECT QUARANTINE_TABLE, PK_COLUMN INTO v_qtable, v_qpk
    FROM NEW_TEST.REFERENCE.QUARANTINE_REGISTRY
    WHERE PIPELINE_CODE = :v_src_pipeline AND IS_ACTIVE = TRUE;
  EXCEPTION WHEN OTHER THEN
    v_qtable := NULL; v_qpk := NULL;
  END;

  -- Build the quarantine NOT EXISTS gate once (empty if no active quarantine)
  IF (v_qtable IS NOT NULL AND v_qpk IS NOT NULL) THEN
    v_qgate := '' AND NOT EXISTS (SELECT 1 FROM '' || v_qtable || '' q WHERE q.'' || v_qpk ||
               '' = b.'' || v_qpk ||
               '' AND q.QUARANTINE_STATUS IN (''''PENDING'''',''''RETRY_FAILED'''',''''REJECTED''''))'';
  END IF;

  -- ROWS_READ from Bronze (excluding quarantined order lines)
  v_count_sql := ''SELECT COUNT(*) FROM NEW_TEST.BRONZE.RAW_ORSINI3PL_ORDER_REPORTS b WHERE b._AUDIT_IS_DELETED = FALSE'' || v_qgate;
  EXECUTE IMMEDIATE v_count_sql;
  SELECT $1 INTO :v_rows_read FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

  BEGIN TRANSACTION;
  IF (v_load_type = ''FULL_REFRESH'') THEN
    TRUNCATE TABLE NEW_TEST.SILVER.ORDER_REPORTS;
    -- Dynamic INSERT so the quarantine gate (v_qgate) can be injected
    v_insert_sql := ''
      INSERT INTO NEW_TEST.SILVER.ORDER_REPORTS (
        ORDER_LINE_KEY, TRANSACTION_DOCUMENT_NUMBER_ID, LINE_ID, ORDER_DATE, TRANSACTION_TYPE,
        CUSTOMER_ENTITY_ID, CUSTOMER_NAME, SHIPPING_CITY, SHIPPING_STATE, SHIPPING_ZIP,
        ITEM, AMOUNT, AMOUNT_NET, QUANTITY, SHIP_DATE, INVOICE_DATE,
        _AUDIT_CREATED_AT, _AUDIT_UPDATED_AT, _AUDIT_CREATED_BY, _AUDIT_RUN_ID,
        _AUDIT_SOURCE_RUN_ID, _AUDIT_RECORD_HASH, _AUDIT_IS_CURRENT, _AUDIT_DQ_STATUS, _AUDIT_ENV
      )
      WITH src AS (
        SELECT
          TRANSACTION_DOCUMENT_NUMBER_ID,
          LINE_ID,
          DATE                       AS ORDER_DATE,
          TRIM(TRANSACTION_TYPE)     AS TRANSACTION_TYPE,
          TRIM(CUSTOMER_ENTITY_ID)   AS CUSTOMER_ENTITY_ID,
          TRIM(CUSTOMER_CUSTOMER)    AS CUSTOMER_NAME,
          TRIM(DEFAULT_SHIPPING_CITY)  AS SHIPPING_CITY,
          UPPER(TRIM(DEFAULT_SHIPPING_STATE)) AS SHIPPING_STATE,
          TRIM(DEFAULT_SHIPPING_ZIP) AS SHIPPING_ZIP,
          TRIM(ITEM)                 AS ITEM,
          COALESCE(AMOUNT, 0)        AS AMOUNT,
          COALESCE(AMOUNT_NET, 0)    AS AMOUNT_NET,
          COALESCE(QUANTITY, 0)      AS QUANTITY,
          SHIP_DATE,
          INVOICE_DATE,
          _AUDIT_RUN_ID              AS bronze_run_id,
          ROW_NUMBER() OVER (PARTITION BY TRANSACTION_DOCUMENT_NUMBER_ID, LINE_ID ORDER BY _AUDIT_LOAD_TS DESC) AS rn
        FROM NEW_TEST.BRONZE.RAW_ORSINI3PL_ORDER_REPORTS b
        WHERE b._AUDIT_IS_DELETED = FALSE'' || v_qgate || ''
      )
      SELECT
        SHA2(TRANSACTION_DOCUMENT_NUMBER_ID || ''''|'''' || LINE_ID::VARCHAR, 256),
        TRANSACTION_DOCUMENT_NUMBER_ID, LINE_ID, ORDER_DATE, TRANSACTION_TYPE,
        CUSTOMER_ENTITY_ID, CUSTOMER_NAME, SHIPPING_CITY, SHIPPING_STATE, SHIPPING_ZIP,
        ITEM, AMOUNT, AMOUNT_NET, QUANTITY, SHIP_DATE, INVOICE_DATE,
        CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), ''''SP_BUILD_SILVER_ORDERS'''',
        '''''' || :v_run_id || '''''', bronze_run_id,
        SHA2(CUSTOMER_ENTITY_ID || ''''|'''' || ITEM || ''''|'''' || AMOUNT::VARCHAR || ''''|'''' || QUANTITY::VARCHAR, 256),
        TRUE, ''''PASSED'''', '''''' || :P_ENV || ''''''
      FROM src WHERE rn = 1'';
    EXECUTE IMMEDIATE v_insert_sql;
    v_query_id := (SELECT LAST_QUERY_ID());
    SELECT $1 INTO :v_rows_inserted FROM TABLE(RESULT_SCAN(:v_query_id));
    v_rows_updated := 0;
  END IF;
  COMMIT;

  CALL NEW_TEST.REFERENCE.RUN_DQM_CHECKS(''SP_SILVER_ORDERS'', :v_run_id, :P_ENV) INTO :v_dq_result;
  v_tests_passed := COALESCE(v_dq_result:passed_checks::NUMBER, 0);
  v_tests_failed := COALESCE(v_dq_result:failed_checks::NUMBER, 0);
  v_tests_warned := COALESCE(v_dq_result:warned_checks::NUMBER, 0);
  v_dq_status    := COALESCE(v_dq_result:dq_status::VARCHAR, ''PASSED'');

  SELECT MAX(_AUDIT_UPDATED_AT) INTO v_watermark_end FROM NEW_TEST.SILVER.ORDER_REPORTS;

  CALL NEW_TEST.AUDIT.LOG_PIPELINE_SUCCESS(
    :v_run_id, ''SP_SILVER_ORDERS'', :P_ENV,
    :v_rows_read, :v_rows_inserted, :v_rows_updated, :v_rows_rejected, 0,
    :v_tests_passed, :v_tests_failed, :v_tests_warned, :v_dq_status, :v_watermark_end, :v_query_id);

  RETURN ''SP_BUILD_SILVER_ORDERS: SUCCESS | Load: '' || v_load_type
      || '' | Read: '' || v_rows_read::VARCHAR
      || '' | Inserted: '' || v_rows_inserted::VARCHAR
      || '' | DQ: '' || v_dq_status;
EXCEPTION
  WHEN OTHER THEN
    ROLLBACK;
    IF (v_run_id IS NOT NULL) THEN
      CALL NEW_TEST.AUDIT.LOG_PIPELINE_FAILURE(:v_run_id, ''SP_SILVER_ORDERS'', :P_ENV, SQLSTATE, SQLERRM, SQLERRM);
    END IF;
    RAISE;
END;
';


 CREATE OR REPLACE PROCEDURE NEW_TEST.REFERENCE.SP_BUILD_GOLD_ORDERS("P_RUN_ID" VARCHAR, "P_ENV" VARCHAR, "P_RETRY_ATTEMPT" NUMBER(38,0) DEFAULT 0)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS '
DECLARE
  v_batch_id        VARCHAR := :P_RUN_ID;
  v_run_id          VARCHAR;
  v_config          VARIANT;
  v_load_type       VARCHAR;
  v_rows_read       NUMBER := 0;
  v_rows_inserted   NUMBER := 0;
  v_rows_updated    NUMBER := 0;
  v_rows_rejected   NUMBER := 0;
  v_watermark_end   TIMESTAMP_NTZ;
  v_query_id        VARCHAR;
  v_dq_result       VARIANT;
  v_dq_status       VARCHAR;
  v_tests_passed    NUMBER := 0;
  v_tests_failed    NUMBER := 0;
  v_tests_warned    NUMBER := 0;
  v_is_retry        BOOLEAN;
  v_retry_reason    VARCHAR;
BEGIN
  v_is_retry := (:P_RETRY_ATTEMPT > 0);
  v_retry_reason := CASE WHEN v_is_retry THEN ''Retry attempt '' || :P_RETRY_ATTEMPT::VARCHAR ELSE NULL END;

  CALL NEW_TEST.AUDIT.LOG_PIPELINE_START(''SP_GOLD_ORDERS'', :P_ENV, :v_batch_id, :P_RETRY_ATTEMPT, :v_is_retry, :v_retry_reason) INTO :v_run_id;

  CALL NEW_TEST.REFERENCE.GET_PIPELINE_CONFIG(''SP_GOLD_ORDERS'', :P_ENV) INTO :v_config;
  v_load_type := COALESCE(v_config:load_type::VARCHAR, ''FULL_REFRESH'');

  -- rows read = current Silver order lines
  SELECT COUNT(*) INTO v_rows_read
  FROM NEW_TEST.SILVER.ORDER_REPORTS
  WHERE _AUDIT_IS_CURRENT = TRUE;

  BEGIN TRANSACTION;
  IF (v_load_type = ''FULL_REFRESH'') THEN
    TRUNCATE TABLE NEW_TEST.GOLD.ORDER_SUMMARY;
    INSERT INTO NEW_TEST.GOLD.ORDER_SUMMARY (
      CUSTOMER_KEY, CUSTOMER_ENTITY_ID, CUSTOMER_NAME,
      TOTAL_ORDERS, TOTAL_LINES, TOTAL_QUANTITY, TOTAL_AMOUNT, TOTAL_AMOUNT_NET, LAST_ORDER_DATE,
      _AUDIT_CREATED_AT, _AUDIT_UPDATED_AT, _AUDIT_CREATED_BY,
      _AUDIT_RUN_ID, _AUDIT_SOURCE_RUN_ID, _AUDIT_RECORD_HASH,
      _AUDIT_IS_CURRENT, _AUDIT_DQ_STATUS, _AUDIT_ENV
    )
    SELECT
      SHA2(CUSTOMER_ENTITY_ID, 256),
      CUSTOMER_ENTITY_ID,
      MAX(CUSTOMER_NAME),
      COUNT(DISTINCT TRANSACTION_DOCUMENT_NUMBER_ID),
      COUNT(*),
      SUM(QUANTITY),
      SUM(AMOUNT),
      SUM(AMOUNT_NET),
      MAX(ORDER_DATE),
      CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), ''SP_BUILD_GOLD_ORDERS'',
      :v_run_id, :v_run_id,
      SHA2(CUSTOMER_ENTITY_ID || ''|'' || SUM(AMOUNT)::VARCHAR || ''|'' || COUNT(*)::VARCHAR, 256),
      TRUE, ''PASSED'', :P_ENV
    FROM NEW_TEST.SILVER.ORDER_REPORTS
    WHERE _AUDIT_IS_CURRENT = TRUE AND CUSTOMER_ENTITY_ID IS NOT NULL
    GROUP BY CUSTOMER_ENTITY_ID;
    v_rows_inserted := SQLROWCOUNT;
    v_rows_updated  := 0;
    v_query_id      := (SELECT LAST_QUERY_ID());
  END IF;
  COMMIT;

  CALL NEW_TEST.REFERENCE.RUN_DQM_CHECKS(''SP_GOLD_ORDERS'', :v_run_id, :P_ENV) INTO :v_dq_result;
  v_tests_passed := COALESCE(v_dq_result:passed_checks::NUMBER, 0);
  v_tests_failed := COALESCE(v_dq_result:failed_checks::NUMBER, 0);
  v_tests_warned := COALESCE(v_dq_result:warned_checks::NUMBER, 0);
  v_dq_status    := COALESCE(v_dq_result:dq_status::VARCHAR, ''PASSED'');

  SELECT MAX(_AUDIT_UPDATED_AT) INTO v_watermark_end FROM NEW_TEST.GOLD.ORDER_SUMMARY;

  CALL NEW_TEST.AUDIT.LOG_PIPELINE_SUCCESS(
    :v_run_id, ''SP_GOLD_ORDERS'', :P_ENV,
    :v_rows_read, :v_rows_inserted, :v_rows_updated, :v_rows_rejected, 0,
    :v_tests_passed, :v_tests_failed, :v_tests_warned, :v_dq_status, :v_watermark_end, :v_query_id);

  RETURN ''SP_BUILD_GOLD_ORDERS: SUCCESS | Load: '' || v_load_type
      || '' | Read: '' || v_rows_read::VARCHAR
      || '' | Inserted: '' || v_rows_inserted::VARCHAR
      || '' | DQ: '' || v_dq_status;
EXCEPTION
  WHEN OTHER THEN
    ROLLBACK;
    IF (v_run_id IS NOT NULL) THEN
      CALL NEW_TEST.AUDIT.LOG_PIPELINE_FAILURE(:v_run_id, ''SP_GOLD_ORDERS'', :P_ENV, SQLSTATE, SQLERRM, SQLERRM);
    END IF;
    RAISE;
END;
';

----------------------
//QC 

-- check the audit log for any reprocess runs
