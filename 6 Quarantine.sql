-- ═══════════════════════════════════════════════════════════════════════════
-- 8 QUARANTINE — Schema, Tables, Registry, Reprocess SP, Auto-Reprocess Task
-- ═══════════════════════════════════════════════════════════════════════════
-- PURPOSE:
--   Captures rows that fail DQM rules (ACTION_ON_FAIL = 'QUARANTINE') into
--   dedicated quarantine tables. Provides reprocessing logic to re-validate
--   and MERGE fixed rows back into their target tables.
--
-- DEPENDENCIES:
--   - NEW_TEST.REFERENCE.DQM_RULES (ACTION_ON_FAIL = 'QUARANTINE')
--   - NEW_TEST.AUDIT.LOG_PIPELINE_START / LOG_PIPELINE_SUCCESS
--   - RUN_DQM_CHECKS (in 3 STORED PROCEDURES.sql) handles quarantine INSERT
--
-- FLOW:
--   DQM Rule fails → INSERT into quarantine table → mark PENDING
--   → Fix source data (or manual fix in quarantine table)
--   → CALL SP_REPROCESS_QUARANTINE → re-validates → MERGE back or RETRY_FAILED
--   → DELETE reprocessed rows from quarantine
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────
-- SCHEMA
-- ─────────────────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS NEW_TEST.QUARANTINE;

-- ─────────────────────────────────────────────────────────────────────────
-- QUARANTINE REGISTRY — maps pipeline → quarantine table
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE NEW_TEST.REFERENCE.QUARANTINE_REGISTRY (
    PIPELINE_CODE       VARCHAR(100)    NOT NULL,
    PIPELINE_LAYER      VARCHAR(20)     NOT NULL,
    SOURCE_TABLE        VARCHAR(200)    NOT NULL,
    QUARANTINE_TABLE    VARCHAR(200)    NOT NULL,
    PK_COLUMN           VARCHAR(200)    NOT NULL,
    IS_ACTIVE           BOOLEAN         DEFAULT TRUE,
    AUTO_REPROCESS      BOOLEAN         DEFAULT FALSE,
    RETENTION_DAYS      NUMBER(5,0)     DEFAULT 90,
    CREATED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    UNIQUE (PIPELINE_CODE, PIPELINE_LAYER)
)
COMMENT = 'Registry mapping pipelines to their quarantine tables';

INSERT INTO NEW_TEST.REFERENCE.QUARANTINE_REGISTRY
(PIPELINE_CODE, PIPELINE_LAYER, SOURCE_TABLE, QUARANTINE_TABLE, PK_COLUMN, IS_ACTIVE, AUTO_REPROCESS)
VALUES
('SP_SILVER_HCP', 'SILVER', 'NEW_TEST.SILVER.HCP_MASTER', 'NEW_TEST.QUARANTINE.HCP_MASTER', 'NPI', TRUE, TRUE),
('SP_GOLD_HCP',   'GOLD',   'NEW_TEST.GOLD.DIM_HCP',     'NEW_TEST.QUARANTINE.DIM_HCP',     'NPI', TRUE, TRUE);

-- ─────────────────────────────────────────────────────────────────────────
-- QUARANTINE TABLE — HCP Silver Layer
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE NEW_TEST.QUARANTINE.HCP_MASTER (
    QUARANTINE_ID           VARCHAR(100)  DEFAULT UUID_STRING(),
    -- ── source columns (must match SILVER.HCP_MASTER order) ──
    UHCP_ID                 VARCHAR(100),
    NPI                     VARCHAR(10),
    FIRST_NAME              VARCHAR(100),
    LAST_NAME               VARCHAR(100),
    FULL_NAME               VARCHAR(200),
    SPECIALTY               VARCHAR(100),
    TERRITORY_CODE          VARCHAR(50),
    REP_ID                  VARCHAR(50),
    LAST_CALL_DATE          DATE,
    TOTAL_CALLS_YTD         NUMBER(10,0),
    // IVE ADDED FEW COLUMS BASED ON MY SCHEMA 
    _AUDIT_CREATED_AT       TIMESTAMP_NTZ,
    _AUDIT_UPDATED_AT       TIMESTAMP_NTZ,
    _AUDIT_CREATED_BY       VARCHAR(100),
    _AUDIT_RUN_ID           VARCHAR(100),
    _AUDIT_SOURCE_RUN_ID    VARCHAR(100),
    _AUDIT_RECORD_HASH      VARCHAR(64),
    _AUDIT_IS_CURRENT       BOOLEAN,
    _AUDIT_DQ_STATUS        VARCHAR(20),
    _AUDIT_ENV              VARCHAR(20),
    -- ── quarantine NEW  columns (10) ──
    QUARANTINE_REASON       VARCHAR(1000) NOT NULL,
    QUARANTINE_RULE_CODE    VARCHAR(100)  NOT NULL,
    QUARANTINE_SEVERITY     VARCHAR(20),
    QUARANTINED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    BATCH_ID                VARCHAR(100),
    RUN_ID                  VARCHAR(100),
    QUARANTINE_STATUS       VARCHAR(20)   DEFAULT 'PENDING',
    REPROCESS_ATTEMPTS      NUMBER(5,0)   DEFAULT 0,
    LAST_REPROCESS_AT       TIMESTAMP_NTZ,
    REPROCESSED_RUN_ID      VARCHAR(100)
)
DATA_RETENTION_TIME_IN_DAYS = 90
COMMENT = 'Quarantined HCP records from Silver layer — pending review/reprocessing';

ALTER TABLE NEW_TEST.QUARANTINE.HCP_MASTER
  CLUSTER BY (QUARANTINE_STATUS, QUARANTINED_AT::DATE);
  // WHAT THIS IS DOING -- TELLING SF TO GROUP BY STATUS ANd DATE - FOR FASTER QUERING YEAH 
-- ─────────────────────────────────────────────────────────────────────────
-- QUARANTINE TABLE — HCP Gold Layer
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE NEW_TEST.QUARANTINE.DIM_HCP (
    QUARANTINE_ID           VARCHAR(100)  DEFAULT UUID_STRING(),
    -- ── source columns (must match GOLD.DIM_HCP order) ──
    HCP_KEY                 VARCHAR(64),
    UHCP_ID                 VARCHAR(100),
    NPI                     VARCHAR(10),
    FIRST_NAME              VARCHAR(100),
    LAST_NAME               VARCHAR(100),
    FULL_NAME               VARCHAR(200),
    SPECIALTY               VARCHAR(100),
    TERRITORY_CODE          VARCHAR(50),
    REP_ID                  VARCHAR(50),
    LAST_CALL_DATE          DATE,
    TOTAL_CALLS_YTD         NUMBER(10,0),
    IS_ACTIVE               BOOLEAN,
    VALID_FROM              TIMESTAMP_NTZ,
    VALID_TO                TIMESTAMP_NTZ,
    _AUDIT_CREATED_AT       TIMESTAMP_NTZ,
    _AUDIT_UPDATED_AT       TIMESTAMP_NTZ,
    _AUDIT_CREATED_BY       VARCHAR(100),
    _AUDIT_RUN_ID           VARCHAR(100),
    _AUDIT_SOURCE_RUN_ID    VARCHAR(100),
    _AUDIT_RECORD_HASH      VARCHAR(64),
    _AUDIT_IS_CURRENT       BOOLEAN,
    _AUDIT_DQ_STATUS        VARCHAR(20),
    _AUDIT_ENV              VARCHAR(20),
    -- ── quarantine meta columns (10) ──
    QUARANTINE_REASON       VARCHAR(1000) NOT NULL,
    QUARANTINE_RULE_CODE    VARCHAR(100)  NOT NULL,
    QUARANTINE_SEVERITY     VARCHAR(20),
    QUARANTINED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    BATCH_ID                VARCHAR(100),
    RUN_ID                  VARCHAR(100),
    QUARANTINE_STATUS       VARCHAR(20)   DEFAULT 'PENDING',
    REPROCESS_ATTEMPTS      NUMBER(5,0)   DEFAULT 0,
    LAST_REPROCESS_AT       TIMESTAMP_NTZ,
    REPROCESSED_RUN_ID      VARCHAR(100)
)
DATA_RETENTION_TIME_IN_DAYS = 90
COMMENT = 'Quarantined HCP records from Gold layer — pending review/reprocessing';


ALTER TABLE NEW_TEST.QUARANTINE.DIM_HCP
  CLUSTER BY (QUARANTINE_STATUS, QUARANTINED_AT::DATE);
SHOW TABLES IN SCHEMA NEW_TEST.QUARANTINE;

-- ═══════════════════════════════════════════════════════════════════════════
-- SP_REPROCESS_QUARANTINE — Re-validate quarantined rows and MERGE back
-- ─────────────────────────────────────────────────────────────────────────
-- Reads PENDING rows from quarantine table, re-runs DQM checks:
--   PASSED  → MERGE into target table, DELETE from quarantine
--   FAILED  → Increment REPROCESS_ATTEMPTS, mark RETRY_FAILED
-- Logs to PIPELINE_RUN_LOG with RUN_TRIGGER_TYPE = 'REPROCESS'
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE PROCEDURE NEW_TEST.REFERENCE.SP_REPROCESS_QUARANTINE(
  P_PIPELINE_CODE VARCHAR,
  P_ENVIRONMENT VARCHAR
) RETURNS VARIANT LANGUAGE SQL EXECUTE AS OWNER AS
$$
DECLARE
  v_quarantine_tbl  VARCHAR;
  v_target_tbl      VARCHAR;
  v_pk_column       VARCHAR;
  v_run_id          VARCHAR;
  v_pending_count   NUMBER := 0;
  v_reprocessed     NUMBER := 0;
  v_still_failed    NUMBER := 0;
  v_rule_code       VARCHAR;
  v_rule_type       VARCHAR;
  v_col_name        VARCHAR;
  v_expression      VARCHAR;
  v_sql             VARCHAR;
  v_rs              RESULTSET;
  v_start_ts        TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
BEGIN
  SELECT QUARANTINE_TABLE, SOURCE_TABLE, PK_COLUMN
  INTO v_quarantine_tbl, v_target_tbl, v_pk_column
  FROM NEW_TEST.REFERENCE.QUARANTINE_REGISTRY
  WHERE PIPELINE_CODE = :P_PIPELINE_CODE AND IS_ACTIVE = TRUE;

  IF (:v_quarantine_tbl IS NULL) THEN
    RETURN OBJECT_CONSTRUCT('status', 'SKIPPED', 'reason', 'No active quarantine registry for ' || :P_PIPELINE_CODE);
  END IF;

  v_sql := 'SELECT COUNT(*) FROM ' || :v_quarantine_tbl || ' WHERE QUARANTINE_STATUS = ''PENDING''';
  v_rs := (EXECUTE IMMEDIATE :v_sql);
  LET cr_cnt CURSOR FOR v_rs; OPEN cr_cnt; FETCH cr_cnt INTO v_pending_count; CLOSE cr_cnt;

  IF (:v_pending_count = 0) THEN
    RETURN OBJECT_CONSTRUCT('status', 'SKIPPED', 'reason', 'No PENDING rows in quarantine');
  END IF;

  CALL NEW_TEST.AUDIT.LOG_PIPELINE_START(
    :P_PIPELINE_CODE, :P_ENVIRONMENT, NULL, 'REPROCESS', FALSE, NULL
  ) INTO v_run_id;

  DECLARE
    rs_rules RESULTSET DEFAULT (
      SELECT RULE_CODE, RULE_TYPE, COLUMN_NAME, RULE_EXPRESSION
      FROM NEW_TEST.REFERENCE.DQM_RULES
      WHERE PIPELINE_CODE = :P_PIPELINE_CODE AND IS_ACTIVE = TRUE AND ACTION_ON_FAIL = 'QUARANTINE'
    );
    cr_rules CURSOR FOR rs_rules;
  BEGIN
    FOR rec IN cr_rules DO
      v_rule_code := rec.RULE_CODE;
      v_rule_type := rec.RULE_TYPE;
      v_col_name  := rec.COLUMN_NAME;
      v_expression := rec.RULE_EXPRESSION;

      IF (:v_rule_type = 'NOT_NULL') THEN
        v_sql := 'UPDATE ' || :v_quarantine_tbl ||
          ' SET QUARANTINE_STATUS = ''RETRY_FAILED'', REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1, LAST_REPROCESS_AT = CURRENT_TIMESTAMP(), REPROCESSED_RUN_ID = ''' || :v_run_id ||
          ''' WHERE QUARANTINE_STATUS = ''PENDING'' AND QUARANTINE_RULE_CODE = ''' || :v_rule_code ||
          ''' AND ' || :v_col_name || ' IS NULL';
        EXECUTE IMMEDIATE :v_sql;

        v_sql := 'UPDATE ' || :v_quarantine_tbl ||
          ' SET QUARANTINE_STATUS = ''REPROCESSED'', REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1, LAST_REPROCESS_AT = CURRENT_TIMESTAMP(), REPROCESSED_RUN_ID = ''' || :v_run_id ||
          ''' WHERE QUARANTINE_STATUS = ''PENDING'' AND QUARANTINE_RULE_CODE = ''' || :v_rule_code ||
          ''' AND ' || :v_col_name || ' IS NOT NULL';
        EXECUTE IMMEDIATE :v_sql;

      ELSEIF (:v_rule_type = 'ACCEPTED_VALUES') THEN
        v_sql := 'UPDATE ' || :v_quarantine_tbl ||
          ' SET QUARANTINE_STATUS = ''RETRY_FAILED'', REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1, LAST_REPROCESS_AT = CURRENT_TIMESTAMP(), REPROCESSED_RUN_ID = ''' || :v_run_id ||
          ''' WHERE QUARANTINE_STATUS = ''PENDING'' AND QUARANTINE_RULE_CODE = ''' || :v_rule_code ||
          ''' AND ' || :v_col_name || ' NOT IN (''' || REPLACE(:v_expression, ',', ''',''') || ''')';
        EXECUTE IMMEDIATE :v_sql;

        v_sql := 'UPDATE ' || :v_quarantine_tbl ||
          ' SET QUARANTINE_STATUS = ''REPROCESSED'', REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1, LAST_REPROCESS_AT = CURRENT_TIMESTAMP(), REPROCESSED_RUN_ID = ''' || :v_run_id ||
          ''' WHERE QUARANTINE_STATUS = ''PENDING'' AND QUARANTINE_RULE_CODE = ''' || :v_rule_code || '''';
        EXECUTE IMMEDIATE :v_sql;

      ELSEIF (:v_rule_type = 'REGEX') THEN
        v_sql := 'UPDATE ' || :v_quarantine_tbl ||
          ' SET QUARANTINE_STATUS = ''RETRY_FAILED'', REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1, LAST_REPROCESS_AT = CURRENT_TIMESTAMP(), REPROCESSED_RUN_ID = ''' || :v_run_id ||
          ''' WHERE QUARANTINE_STATUS = ''PENDING'' AND QUARANTINE_RULE_CODE = ''' || :v_rule_code ||
          ''' AND NOT REGEXP_LIKE(' || :v_col_name || ', ''' || :v_expression || ''')';
        EXECUTE IMMEDIATE :v_sql;

        v_sql := 'UPDATE ' || :v_quarantine_tbl ||
          ' SET QUARANTINE_STATUS = ''REPROCESSED'', REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1, LAST_REPROCESS_AT = CURRENT_TIMESTAMP(), REPROCESSED_RUN_ID = ''' || :v_run_id ||
          ''' WHERE QUARANTINE_STATUS = ''PENDING'' AND QUARANTINE_RULE_CODE = ''' || :v_rule_code || '''';
        EXECUTE IMMEDIATE :v_sql;

      ELSE
        v_sql := 'UPDATE ' || :v_quarantine_tbl ||
          ' SET QUARANTINE_STATUS = ''REPROCESSED'', REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1, LAST_REPROCESS_AT = CURRENT_TIMESTAMP(), REPROCESSED_RUN_ID = ''' || :v_run_id ||
          ''' WHERE QUARANTINE_STATUS = ''PENDING'' AND QUARANTINE_RULE_CODE = ''' || :v_rule_code || '''';
        EXECUTE IMMEDIATE :v_sql;
      END IF;
    END FOR;
  END;

  v_sql := 'MERGE INTO ' || :v_target_tbl || ' tgt USING (SELECT * FROM ' || :v_quarantine_tbl ||
    ' WHERE QUARANTINE_STATUS = ''REPROCESSED'' AND REPROCESSED_RUN_ID = ''' || :v_run_id || ''') src ON tgt.' ||
    :v_pk_column || ' = src.' || :v_pk_column ||
    ' WHEN MATCHED THEN UPDATE SET ' ||
    'tgt._AUDIT_UPDATED_AT = CURRENT_TIMESTAMP(), tgt._AUDIT_DQ_STATUS = ''REPROCESSED''' ||
    ' WHEN NOT MATCHED THEN INSERT (' || :v_pk_column || ', _AUDIT_DQ_STATUS, _AUDIT_CREATED_AT, _AUDIT_UPDATED_AT, _AUDIT_IS_CURRENT)' ||
    ' VALUES (src.' || :v_pk_column || ', ''REPROCESSED'', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), TRUE)';
  EXECUTE IMMEDIATE :v_sql;

  v_sql := 'SELECT COUNT(*) FROM ' || :v_quarantine_tbl || ' WHERE REPROCESSED_RUN_ID = ''' || :v_run_id || ''' AND QUARANTINE_STATUS = ''REPROCESSED''';
  v_rs := (EXECUTE IMMEDIATE :v_sql);
  LET cr_r CURSOR FOR v_rs; OPEN cr_r; FETCH cr_r INTO v_reprocessed; CLOSE cr_r;

  v_sql := 'SELECT COUNT(*) FROM ' || :v_quarantine_tbl || ' WHERE REPROCESSED_RUN_ID = ''' || :v_run_id || ''' AND QUARANTINE_STATUS = ''RETRY_FAILED''';
  v_rs := (EXECUTE IMMEDIATE :v_sql);
  LET cr_f CURSOR FOR v_rs; OPEN cr_f; FETCH cr_f INTO v_still_failed; CLOSE cr_f;

  v_sql := 'DELETE FROM ' || :v_quarantine_tbl || ' WHERE QUARANTINE_STATUS = ''REPROCESSED'' AND REPROCESSED_RUN_ID = ''' || :v_run_id || '''';
  EXECUTE IMMEDIATE :v_sql;

  CALL NEW_TEST.AUDIT.LOG_PIPELINE_SUCCESS(
    :v_run_id, :P_PIPELINE_CODE, :P_ENVIRONMENT,
    :v_pending_count, :v_reprocessed, NULL, NULL, NULL, NULL, NULL, NULL,
    CASE WHEN :v_still_failed > 0 THEN 'WARNING' ELSE 'PASSED' END,
    CURRENT_TIMESTAMP(), LAST_QUERY_ID());

  RETURN OBJECT_CONSTRUCT(
    'status', 'COMPLETED',
    'pipeline_code', :P_PIPELINE_CODE,
    'pending_rows', :v_pending_count,
    'reprocessed', :v_reprocessed,
    'still_failed', :v_still_failed,
    'run_id', :v_run_id,
    'execution_secs', DATEDIFF('second', :v_start_ts, CURRENT_TIMESTAMP())
  );
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO-REPROCESS TASK — Daily task to reprocess quarantined rows
-- Runs SP_REPROCESS_QUARANTINE for all pipelines with AUTO_REPROCESS = TRUE
-- Schedule: Daily 6 AM UTC (created SUSPENDED — resume when ready)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TASK NEW_TEST.REFERENCE.TASK_QUARANTINE_REPROCESS
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = 'USING CRON 0 6 * * * UTC'
  COMMENT = 'Daily auto-reprocess of quarantined rows at 6 AM UTC'
AS
DECLARE
  v_pipeline_code VARCHAR;
  v_result VARIANT;
BEGIN
  DECLARE
    rs_pipelines RESULTSET DEFAULT (
      SELECT PIPELINE_CODE FROM NEW_TEST.REFERENCE.QUARANTINE_REGISTRY WHERE IS_ACTIVE = TRUE AND AUTO_REPROCESS = TRUE
    );
    cr_pipelines CURSOR FOR rs_pipelines;
  BEGIN
    FOR rec IN cr_pipelines DO
      v_pipeline_code := rec.PIPELINE_CODE;
      CALL NEW_TEST.REFERENCE.SP_REPROCESS_QUARANTINE(:v_pipeline_code, 'DEV') INTO v_result;
    END FOR;
  END;
END;

ALTER TASK NEW_TEST.REFERENCE.TASK_QUARANTINE_REPROCESS SUSPEND;

SHOW TASKS IN SCHEMA NEW_TEST.REFERENCE;



-- ═══════════════════════════════════════════════════════════════
-- SEED: QUARANTINE_REGISTRY — maps pipelines to quarantine tables
-- ═══════════════════════════════════════════════════════════════

TRUNCATE TABLE NEW_TEST.REFERENCE.QUARANTINE_REGISTRY;

INSERT INTO NEW_TEST.REFERENCE.QUARANTINE_REGISTRY
(PIPELINE_CODE, PIPELINE_LAYER, SOURCE_TABLE, QUARANTINE_TABLE, PK_COLUMN, IS_ACTIVE, AUTO_REPROCESS)
VALUES
('SP_SILVER_HCP',    'SILVER', 'NEW_TEST.SILVER.HCP_MASTER', 'NEW_TEST.QUARANTINE.HCP_MASTER', 'NPI', TRUE, TRUE),
('SP_GOLD_HCP',      'GOLD',   'NEW_TEST.GOLD.DIM_HCP',     'NEW_TEST.QUARANTINE.DIM_HCP',     'NPI', TRUE, TRUE);

SELECT * FROM NEW_TEST.REFERENCE.QUARANTINE_REGISTRY

-- ═══════════════════════════════════════════════════════════════
-- SEED: DQM_RULES with QUARANTINE action examples
-- ═══════════════════════════════════════════════════════════════

INSERT INTO NEW_TEST.REFERENCE.DQM_RULES
(RULE_CODE, RULE_NAME, PIPELINE_CODE, PIPELINE_LAYER, DOMAIN, RULE_TYPE, COLUMN_NAME, SEVERITY, ACTION_ON_FAIL, IS_ACTIVE, RULE_EXPRESSION)
VALUES
('HCP_NPI_NOT_NULL',     'NPI must not be null',          'SP_SILVER_HCP', 'SILVER', 'HCP', 'NOT_NULL',        'NPI',            'CRITICAL', 'QUARANTINE', TRUE, NULL),
('HCP_NPI_FORMAT',       'NPI must be 10-digit numeric',  'SP_SILVER_HCP', 'SILVER', 'HCP', 'REGEX',           'NPI',            'HIGH',     'QUARANTINE', TRUE, '^[0-9]{10}$'),
('HCP_SPECIALTY_VALID',  'Specialty must be valid value', 'SP_SILVER_HCP', 'SILVER', 'HCP', 'ACCEPTED_VALUES', 'SPECIALTY',      'MEDIUM',   'WARN_AND_CONTINUE', TRUE, 'Cardiology,Oncology,Neurology,Dermatology,Endocrinology,General Practice,Internal Medicine,Rheumatology'),
('HCP_CALLS_RANGE',     'Total calls must be 0-10000',   'SP_SILVER_HCP', 'SILVER', 'HCP', 'RANGE',           'TOTAL_CALLS',    'MEDIUM',   'QUARANTINE', TRUE, '0,10000'),
('GOLD_NPI_NOT_NULL',   'Gold NPI must not be null',     'SP_GOLD_HCP',   'GOLD',   'HCP', 'NOT_NULL',        'NPI',            'CRITICAL', 'QUARANTINE', TRUE, NULL);


-- ═══════════════════════════════════════════════════════════════════════════
-- USAGE EXAMPLES
-- ═══════════════════════════════════════════════════════════════════════════

-- View pending quarantined rows:
-- SELECT * FROM NEW_TEST.QUARANTINE.HCP_MASTER WHERE QUARANTINE_STATUS = 'PENDING';

-- Manually reprocess:
-- CALL NEW_TEST.REFERENCE.SP_REPROCESS_QUARANTINE('SP_SILVER_HCP', 'DEV');

-- Enable auto-reprocess:
-- ALTER TASK NEW_TEST.REFERENCE.TASK_QUARANTINE_REPROCESS RESUME;

-- Check quarantine stats:
-- SELECT QUARANTINE_STATUS, COUNT(*) FROM NEW_TEST.QUARANTINE.HCP_MASTER GROUP BY 1;

----------------------------------------------------------
CREATE OR REPLACE PROCEDURE NEW_TEST.REFERENCE.SP_REPROCESS_QUARANTINE(
  P_PIPELINE_CODE VARCHAR,
  P_ENVIRONMENT VARCHAR
) RETURNS VARIANT LANGUAGE SQL EXECUTE AS OWNER AS
$$
DECLARE
  v_quarantine_tbl  VARCHAR;
  v_target_tbl      VARCHAR;
  v_pk_column       VARCHAR;
  v_run_id          VARCHAR;
  v_pending_count   NUMBER := 0;
  v_reprocessed     NUMBER := 0;
  v_still_failed    NUMBER := 0;
  v_rule_code       VARCHAR;
  v_rule_type       VARCHAR;
  v_col_name        VARCHAR;
  v_expression      VARCHAR;
  v_sql             VARCHAR;
  v_rs              RESULTSET;
  v_start_ts        TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
BEGIN
  SELECT QUARANTINE_TABLE, SOURCE_TABLE, PK_COLUMN
  INTO v_quarantine_tbl, v_target_tbl, v_pk_column
  FROM NEW_TEST.REFERENCE.QUARANTINE_REGISTRY
  WHERE PIPELINE_CODE = :P_PIPELINE_CODE AND IS_ACTIVE = TRUE;

  IF (:v_quarantine_tbl IS NULL) THEN
    RETURN OBJECT_CONSTRUCT('status', 'SKIPPED', 'reason', 'No active quarantine registry for ' || :P_PIPELINE_CODE);
  END IF;

  v_sql := 'SELECT COUNT(*) FROM ' || :v_quarantine_tbl || ' WHERE QUARANTINE_STATUS = ''PENDING''';
  v_rs := (EXECUTE IMMEDIATE :v_sql);
  LET cr_cnt CURSOR FOR v_rs; OPEN cr_cnt; FETCH cr_cnt INTO v_pending_count; CLOSE cr_cnt;

  IF (:v_pending_count = 0) THEN
    RETURN OBJECT_CONSTRUCT('status', 'SKIPPED', 'reason', 'No PENDING rows in quarantine');
  END IF;

  CALL NEW_TEST.AUDIT.LOG_PIPELINE_START(
    :P_PIPELINE_CODE, :P_ENVIRONMENT, NULL, 0, FALSE, 'REPROCESS'
  ) INTO v_run_id;

  DECLARE
    rs_rules RESULTSET DEFAULT (
      SELECT RULE_CODE, RULE_TYPE, COLUMN_NAME, RULE_EXPRESSION
      FROM NEW_TEST.REFERENCE.DQM_RULES
      WHERE PIPELINE_CODE = :P_PIPELINE_CODE AND IS_ACTIVE = TRUE AND ACTION_ON_FAIL = 'QUARANTINE'
    );
    cr_rules CURSOR FOR rs_rules;
  BEGIN
    FOR rec IN cr_rules DO
      v_rule_code := rec.RULE_CODE;
      v_rule_type := rec.RULE_TYPE;
      v_col_name  := rec.COLUMN_NAME;
      v_expression := rec.RULE_EXPRESSION;

      IF (:v_rule_type = 'NOT_NULL') THEN
        v_sql := 'UPDATE ' || :v_quarantine_tbl ||
          ' SET QUARANTINE_STATUS = ''RETRY_FAILED'', REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1, LAST_REPROCESS_AT = CURRENT_TIMESTAMP(), REPROCESSED_RUN_ID = ''' || :v_run_id ||
          ''' WHERE QUARANTINE_STATUS = ''PENDING'' AND QUARANTINE_RULE_CODE = ''' || :v_rule_code ||
          ''' AND ' || :v_col_name || ' IS NULL';
        EXECUTE IMMEDIATE :v_sql;

        v_sql := 'UPDATE ' || :v_quarantine_tbl ||
          ' SET QUARANTINE_STATUS = ''REPROCESSED'', REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1, LAST_REPROCESS_AT = CURRENT_TIMESTAMP(), REPROCESSED_RUN_ID = ''' || :v_run_id ||
          ''' WHERE QUARANTINE_STATUS = ''PENDING'' AND QUARANTINE_RULE_CODE = ''' || :v_rule_code ||
          ''' AND ' || :v_col_name || ' IS NOT NULL';
        EXECUTE IMMEDIATE :v_sql;

      ELSEIF (:v_rule_type = 'ACCEPTED_VALUES') THEN
        v_sql := 'UPDATE ' || :v_quarantine_tbl ||
          ' SET QUARANTINE_STATUS = ''RETRY_FAILED'', REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1, LAST_REPROCESS_AT = CURRENT_TIMESTAMP(), REPROCESSED_RUN_ID = ''' || :v_run_id ||
          ''' WHERE QUARANTINE_STATUS = ''PENDING'' AND QUARANTINE_RULE_CODE = ''' || :v_rule_code ||
          ''' AND ' || :v_col_name || ' NOT IN (''' || REPLACE(:v_expression, ',', ''',''') || ''')';
        EXECUTE IMMEDIATE :v_sql;

        v_sql := 'UPDATE ' || :v_quarantine_tbl ||
          ' SET QUARANTINE_STATUS = ''REPROCESSED'', REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1, LAST_REPROCESS_AT = CURRENT_TIMESTAMP(), REPROCESSED_RUN_ID = ''' || :v_run_id ||
          ''' WHERE QUARANTINE_STATUS = ''PENDING'' AND QUARANTINE_RULE_CODE = ''' || :v_rule_code || '''';
        EXECUTE IMMEDIATE :v_sql;

      ELSEIF (:v_rule_type = 'REGEX') THEN
        v_sql := 'UPDATE ' || :v_quarantine_tbl ||
          ' SET QUARANTINE_STATUS = ''RETRY_FAILED'', REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1, LAST_REPROCESS_AT = CURRENT_TIMESTAMP(), REPROCESSED_RUN_ID = ''' || :v_run_id ||
          ''' WHERE QUARANTINE_STATUS = ''PENDING'' AND QUARANTINE_RULE_CODE = ''' || :v_rule_code ||
          ''' AND NOT REGEXP_LIKE(' || :v_col_name || ', ''' || :v_expression || ''')';
        EXECUTE IMMEDIATE :v_sql;

        v_sql := 'UPDATE ' || :v_quarantine_tbl ||
          ' SET QUARANTINE_STATUS = ''REPROCESSED'', REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1, LAST_REPROCESS_AT = CURRENT_TIMESTAMP(), REPROCESSED_RUN_ID = ''' || :v_run_id ||
          ''' WHERE QUARANTINE_STATUS = ''PENDING'' AND QUARANTINE_RULE_CODE = ''' || :v_rule_code || '''';
        EXECUTE IMMEDIATE :v_sql;

      ELSE
        v_sql := 'UPDATE ' || :v_quarantine_tbl ||
          ' SET QUARANTINE_STATUS = ''REPROCESSED'', REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1, LAST_REPROCESS_AT = CURRENT_TIMESTAMP(), REPROCESSED_RUN_ID = ''' || :v_run_id ||
          ''' WHERE QUARANTINE_STATUS = ''PENDING'' AND QUARANTINE_RULE_CODE = ''' || :v_rule_code || '''';
        EXECUTE IMMEDIATE :v_sql;
      END IF;
    END FOR;
  END;

  v_sql := 'MERGE INTO ' || :v_target_tbl || ' tgt USING (SELECT * FROM ' || :v_quarantine_tbl ||
    ' WHERE QUARANTINE_STATUS = ''REPROCESSED'' AND REPROCESSED_RUN_ID = ''' || :v_run_id || ''') src ON tgt.' ||
    :v_pk_column || ' = src.' || :v_pk_column ||
    ' WHEN MATCHED THEN UPDATE SET ' ||
    'tgt._AUDIT_UPDATED_AT = CURRENT_TIMESTAMP(), tgt._AUDIT_DQ_STATUS = ''REPROCESSED''' ||
    ' WHEN NOT MATCHED THEN INSERT (' || :v_pk_column || ', _AUDIT_DQ_STATUS, _AUDIT_CREATED_AT, _AUDIT_UPDATED_AT, _AUDIT_IS_CURRENT)' ||
    ' VALUES (src.' || :v_pk_column || ', ''REPROCESSED'', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), TRUE)';
  EXECUTE IMMEDIATE :v_sql;

  v_sql := 'SELECT COUNT(*) FROM ' || :v_quarantine_tbl || ' WHERE REPROCESSED_RUN_ID = ''' || :v_run_id || ''' AND QUARANTINE_STATUS = ''REPROCESSED''';
  v_rs := (EXECUTE IMMEDIATE :v_sql);
  LET cr_r CURSOR FOR v_rs; OPEN cr_r; FETCH cr_r INTO v_reprocessed; CLOSE cr_r;

  v_sql := 'SELECT COUNT(*) FROM ' || :v_quarantine_tbl || ' WHERE REPROCESSED_RUN_ID = ''' || :v_run_id || ''' AND QUARANTINE_STATUS = ''RETRY_FAILED''';
  v_rs := (EXECUTE IMMEDIATE :v_sql);
  LET cr_f CURSOR FOR v_rs; OPEN cr_f; FETCH cr_f INTO v_still_failed; CLOSE cr_f;

  v_sql := 'DELETE FROM ' || :v_quarantine_tbl || ' WHERE QUARANTINE_STATUS = ''REPROCESSED'' AND REPROCESSED_RUN_ID = ''' || :v_run_id || '''';
  EXECUTE IMMEDIATE :v_sql;

  CALL NEW_TEST.AUDIT.LOG_PIPELINE_SUCCESS(
    :v_run_id, :P_PIPELINE_CODE, :P_ENVIRONMENT,
    :v_pending_count, :v_reprocessed, NULL, NULL, NULL, NULL, NULL, NULL,
    CASE WHEN :v_still_failed > 0 THEN 'WARNING' ELSE 'PASSED' END,
    NULL, LAST_QUERY_ID());

  RETURN OBJECT_CONSTRUCT(
    'status', 'COMPLETED',
    'pipeline_code', :P_PIPELINE_CODE,
    'pending_rows', :v_pending_count,
    'reprocessed', :v_reprocessed,
    'still_failed', :v_still_failed,
    'run_id', :v_run_id,
    'execution_secs', DATEDIFF('second', :v_start_ts, CURRENT_TIMESTAMP())
  );
END;
$$;

--------------------------------------------------------------------------
- SP_REPROCESS_QUARANTINE — CORRECTED
-- Fixes:
--   P1: WHEN MATCHED now updates ALL business columns (not just audit)
--   P2: WHEN NOT MATCHED now inserts the FULL row (not just PK + audit)
--   P4: RANGE / UNIQUE / REFERENTIAL now re-validated (not auto-passed)
-- Column lists are built DYNAMICALLY from the target table, so this one SP
-- works for any pipeline (HCP / Gold / Veeva) regardless of their columns.
-- ═══════════════════════════════════════════════════════════════════════════
 
CREATE OR REPLACE PROCEDURE NEW_TEST.REFERENCE.SP_REPROCESS_QUARANTINE(
  P_PIPELINE_CODE VARCHAR, P_ENVIRONMENT VARCHAR
) RETURNS VARIANT LANGUAGE SQL EXECUTE AS OWNER AS
$$
DECLARE
  v_quarantine_tbl  VARCHAR;
  v_target_tbl      VARCHAR;
  v_pk_column       VARCHAR;
  v_run_id          VARCHAR;
  v_pending_count   NUMBER := 0;
  v_reprocessed     NUMBER := 0;
  v_still_failed    NUMBER := 0;
  v_rule_code       VARCHAR;
  v_rule_type       VARCHAR;
  v_col_name        VARCHAR;
  v_expression      VARCHAR;
  v_sql             VARCHAR;
  v_rs              RESULTSET;
  v_start_ts        TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
  -- dynamic column handling
  v_target_db       VARCHAR;
  v_target_schema   VARCHAR;
  v_target_name     VARCHAR;
  v_set_list        VARCHAR;   -- "tgt.col = src.col, ..."  (for UPDATE)
  v_col_list        VARCHAR;   -- "col1, col2, ..."         (for INSERT)
  v_src_list        VARCHAR;   -- "src.col1, src.col2, ..." (for INSERT VALUES)
BEGIN
  -- ── 1. Read registry (where to read from / write to, and the stable key) ──
  SELECT QUARANTINE_TABLE, SOURCE_TABLE, PK_COLUMN
  INTO v_quarantine_tbl, v_target_tbl, v_pk_column
  FROM NEW_TEST.REFERENCE.QUARANTINE_REGISTRY
  WHERE PIPELINE_CODE = :P_PIPELINE_CODE AND IS_ACTIVE = TRUE;
 
  IF (v_quarantine_tbl IS NULL) THEN
    RETURN OBJECT_CONSTRUCT('status','SKIPPED','reason','No active quarantine registry for ' || :P_PIPELINE_CODE);
  END IF;
 
  -- ── 2. Anything pending? ──
  v_sql := 'SELECT COUNT(*) FROM ' || :v_quarantine_tbl || ' WHERE QUARANTINE_STATUS = ''PENDING''';
  v_rs := (EXECUTE IMMEDIATE :v_sql);
  LET cr_cnt CURSOR FOR v_rs; OPEN cr_cnt; FETCH cr_cnt INTO v_pending_count; CLOSE cr_cnt;
 
  IF (v_pending_count = 0) THEN
    RETURN OBJECT_CONSTRUCT('status','SKIPPED','reason','No PENDING rows in quarantine');
  END IF;
 
  CALL NEW_TEST.AUDIT.LOG_PIPELINE_START(
    :P_PIPELINE_CODE, :P_ENVIRONMENT, NULL, 0, FALSE, 'REPROCESS'
  ) INTO v_run_id;
 
  -- ── 3. Re-validate each PENDING row against its quarantine rules ──
  --     Pass  -> mark REPROCESSED ; Fail -> mark RETRY_FAILED
  DECLARE
    rs_rules RESULTSET DEFAULT (
      SELECT RULE_CODE, RULE_TYPE, COLUMN_NAME, RULE_EXPRESSION
      FROM NEW_TEST.REFERENCE.DQM_RULES
      WHERE PIPELINE_CODE = :P_PIPELINE_CODE AND IS_ACTIVE = TRUE AND ACTION_ON_FAIL = 'QUARANTINE'
    );
    cr_rules CURSOR FOR rs_rules;
  BEGIN
    FOR rec IN cr_rules DO
      v_rule_code  := rec.RULE_CODE;
      v_rule_type  := rec.RULE_TYPE;
      v_col_name   := rec.COLUMN_NAME;
      v_expression := rec.RULE_EXPRESSION;
 
      -- failing condition per rule type (rows STILL bad -> RETRY_FAILED)
      LET v_fail_cond VARCHAR :=
        CASE :v_rule_type
          WHEN 'NOT_NULL'        THEN v_col_name || ' IS NULL'
          WHEN 'REGEX'           THEN 'NOT REGEXP_LIKE(' || v_col_name || ', ''' || v_expression || ''')'
          WHEN 'ACCEPTED_VALUES' THEN v_col_name || ' NOT IN (''' || REPLACE(v_expression, ',', ''',''') || ''')'
          WHEN 'RANGE'           THEN '(' || v_col_name || ' < ' || SPLIT_PART(v_expression, ',', 1) ||
                                       ' OR ' || v_col_name || ' > ' || SPLIT_PART(v_expression, ',', 2) || ')'
          WHEN 'UNIQUE'          THEN v_col_name || ' IN (SELECT ' || v_col_name || ' FROM ' || v_quarantine_tbl ||
                                       ' WHERE QUARANTINE_STATUS = ''PENDING'' GROUP BY ' || v_col_name || ' HAVING COUNT(*) > 1)'
          WHEN 'REFERENTIAL'     THEN v_col_name || ' NOT IN (SELECT ' || SPLIT_PART(v_expression,'.',4) ||
                                       ' FROM ' || SPLIT_PART(v_expression,'.',1) || '.' || SPLIT_PART(v_expression,'.',2) || '.' || SPLIT_PART(v_expression,'.',3) || ')'
          ELSE NULL
        END;
 
      IF (v_fail_cond IS NOT NULL) THEN
        -- still-bad rows -> RETRY_FAILED
        v_sql := 'UPDATE ' || v_quarantine_tbl ||
          ' SET QUARANTINE_STATUS = ''RETRY_FAILED'', REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1,' ||
          ' LAST_REPROCESS_AT = CURRENT_TIMESTAMP(), REPROCESSED_RUN_ID = ''' || v_run_id || '''' ||
          ' WHERE QUARANTINE_STATUS = ''PENDING'' AND QUARANTINE_RULE_CODE = ''' || v_rule_code || '''' ||
          ' AND (' || v_fail_cond || ')';
        EXECUTE IMMEDIATE :v_sql;
 
        -- now-good rows -> REPROCESSED
        v_sql := 'UPDATE ' || v_quarantine_tbl ||
          ' SET QUARANTINE_STATUS = ''REPROCESSED'', REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1,' ||
          ' LAST_REPROCESS_AT = CURRENT_TIMESTAMP(), REPROCESSED_RUN_ID = ''' || v_run_id || '''' ||
          ' WHERE QUARANTINE_STATUS = ''PENDING'' AND QUARANTINE_RULE_CODE = ''' || v_rule_code || '''' ||
          ' AND NOT (' || v_fail_cond || ')';
        EXECUTE IMMEDIATE :v_sql;
      ELSE
        -- unknown rule type: do NOT auto-pass; leave PENDING (safer)
        NULL;
      END IF;
    END FOR;
  END;
 
  -- ── 4. Build the dynamic column lists from the TARGET table ──
  --     (copy every target column that also exists in quarantine, except the PK
  --      which is only used for matching in the UPDATE branch)
  v_target_db     := SPLIT_PART(v_target_tbl, '.', 1);
  v_target_schema := SPLIT_PART(v_target_tbl, '.', 2);
  v_target_name   := SPLIT_PART(v_target_tbl, '.', 3);
 
  v_sql :=
    'SELECT ' ||
    '  LISTAGG(''tgt.'' || COLUMN_NAME || '' = src.'' || COLUMN_NAME, '', '') WITHIN GROUP (ORDER BY ORDINAL_POSITION), ' ||
    '  LISTAGG(COLUMN_NAME, '', '') WITHIN GROUP (ORDER BY ORDINAL_POSITION), ' ||
    '  LISTAGG(''src.'' || COLUMN_NAME, '', '') WITHIN GROUP (ORDER BY ORDINAL_POSITION) ' ||
    'FROM ' || v_target_db || '.INFORMATION_SCHEMA.COLUMNS ' ||
    'WHERE TABLE_SCHEMA = ''' || v_target_schema || ''' ' ||
    '  AND TABLE_NAME = ''' || v_target_name || ''' ' ||
    '  AND COLUMN_NAME NOT IN (' ||
    '    ''QUARANTINE_ID'',''QUARANTINE_REASON'',''QUARANTINE_RULE_CODE'',''QUARANTINE_SEVERITY'',' ||
    '    ''QUARANTINED_AT'',''BATCH_ID'',''RUN_ID'',''QUARANTINE_STATUS'',''REPROCESS_ATTEMPTS'',' ||
    '    ''LAST_REPROCESS_AT'',''REPROCESSED_RUN_ID'')';
  v_rs := (EXECUTE IMMEDIATE :v_sql);
  LET cr_cols CURSOR FOR v_rs;
  OPEN cr_cols;
  FETCH cr_cols INTO v_set_list, v_col_list, v_src_list;
  CLOSE cr_cols;
 
  -- ── 5. MERGE the now-good (REPROCESSED) rows back into the target ──
  --     UPDATE if PK exists, INSERT full row if not. Carries ALL columns.
  v_sql := 'MERGE INTO ' || v_target_tbl || ' tgt' ||
           ' USING (SELECT * FROM ' || v_quarantine_tbl ||
           '   WHERE QUARANTINE_STATUS = ''REPROCESSED'' AND REPROCESSED_RUN_ID = ''' || v_run_id || ''') src' ||
           ' ON tgt.' || v_pk_column || ' = src.' || v_pk_column ||
           ' WHEN MATCHED THEN UPDATE SET ' || v_set_list ||
           ' WHEN NOT MATCHED THEN INSERT (' || v_col_list || ') VALUES (' || v_src_list || ')';
  EXECUTE IMMEDIATE :v_sql;
 
  -- ── 6. Counts ──
  v_sql := 'SELECT COUNT(*) FROM ' || v_quarantine_tbl || ' WHERE REPROCESSED_RUN_ID = ''' || v_run_id || ''' AND QUARANTINE_STATUS = ''REPROCESSED''';
  v_rs := (EXECUTE IMMEDIATE :v_sql);
  LET cr_r CURSOR FOR v_rs; OPEN cr_r; FETCH cr_r INTO v_reprocessed; CLOSE cr_r;
 
  v_sql := 'SELECT COUNT(*) FROM ' || v_quarantine_tbl || ' WHERE REPROCESSED_RUN_ID = ''' || v_run_id || ''' AND QUARANTINE_STATUS = ''RETRY_FAILED''';
  v_rs := (EXECUTE IMMEDIATE :v_sql);
  LET cr_f CURSOR FOR v_rs; OPEN cr_f; FETCH cr_f INTO v_still_failed; CLOSE cr_f;
 
  -- ── 7. Remove successfully reprocessed rows from quarantine ──
  v_sql := 'DELETE FROM ' || v_quarantine_tbl || ' WHERE QUARANTINE_STATUS = ''REPROCESSED'' AND REPROCESSED_RUN_ID = ''' || v_run_id || '''';
  EXECUTE IMMEDIATE :v_sql;
 
  CALL NEW_TEST.AUDIT.LOG_PIPELINE_SUCCESS(
    :v_run_id, :P_PIPELINE_CODE, :P_ENVIRONMENT,
    :v_pending_count, :v_reprocessed, NULL, NULL, NULL, NULL, NULL, NULL,
    CASE WHEN :v_still_failed > 0 THEN 'WARNING' ELSE 'PASSED' END,
    NULL, LAST_QUERY_ID());
 
  RETURN OBJECT_CONSTRUCT(
    'status','COMPLETED',
    'pipeline_code', :P_PIPELINE_CODE,
    'pending_rows',  :v_pending_count,
    'reprocessed',   :v_reprocessed,
    'still_failed',  :v_still_failed,
    'run_id',        :v_run_id,
    'execution_secs', DATEDIFF('second', :v_start_ts, CURRENT_TIMESTAMP())
  );
EXCEPTION
  WHEN OTHER THEN
    RETURN OBJECT_CONSTRUCT('status','ERROR','pipeline_code', :P_PIPELINE_CODE, 'error', SQLERRM);
END;
$$;



 -------------------------
 //MODIFICATIONS DATED : 08062026

 // ADDING ONE COLUMN MAX_ATTEMPST TO Q REGISTER 
 ALTER TABLE NEW_TEST.REFERENCE.QUARANTINE_REGISTRY
ADD COLUMN IF NOT EXISTS MAX_ATTEMPTS NUMBER(5,0) DEFAULT 3;

DESC TABLE NEW_TEST.REFERENCE.QUARANTINE_REGISTRY;

// NEW SP MODIFIED WITH RERY ATTEMPTS AND STATUS (PENDING AND RETRY FAILED LOGIC)


CREATE OR REPLACE PROCEDURE NEW_TEST.REFERENCE.SP_REPROCESS_QUARANTINE(
  P_PIPELINE_CODE VARCHAR, P_ENVIRONMENT VARCHAR
) RETURNS VARIANT LANGUAGE SQL EXECUTE AS OWNER AS
$$
DECLARE
  v_quarantine_tbl  VARCHAR;
  v_target_tbl      VARCHAR;
  v_pk_column       VARCHAR;
  v_max_attempts    NUMBER;            -- ★ from registry (no hardcoding)
  v_run_id          VARCHAR;
  v_candidate_count NUMBER := 0;       -- ★ PENDING + RETRY_FAILED
  v_reprocessed     NUMBER := 0;
  v_still_failed    NUMBER := 0;
  v_rejected        NUMBER := 0;       -- ★ hit max attempts this run
  v_sql             VARCHAR;
  v_rs              RESULTSET;
  v_start_ts        TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
  -- combined fail expression (ANY rule failing = row still bad)
  v_fail_any        VARCHAR := '';     -- ★ "(cond1) OR (cond2) OR ..."
  -- dynamic target column lists for MERGE
  v_target_db       VARCHAR;
  v_target_schema   VARCHAR;
  v_target_name     VARCHAR;
  v_set_list        VARCHAR;
  v_col_list        VARCHAR;
  v_src_list        VARCHAR;
BEGIN
  -- ── 1. Registry: tables, stable key, AND max attempts (all dynamic) ──
  SELECT QUARANTINE_TABLE, SOURCE_TABLE, PK_COLUMN, MAX_ATTEMPTS
  INTO v_quarantine_tbl, v_target_tbl, v_pk_column, v_max_attempts
  FROM NEW_TEST.REFERENCE.QUARANTINE_REGISTRY
  WHERE PIPELINE_CODE = :P_PIPELINE_CODE AND IS_ACTIVE = TRUE;

  IF (v_quarantine_tbl IS NULL) THEN
    RETURN OBJECT_CONSTRUCT('status','SKIPPED','reason','No active quarantine registry for ' || :P_PIPELINE_CODE);
  END IF;

  IF (v_max_attempts IS NULL) THEN
    v_max_attempts := 3;   -- registry fallback only (column default should supply this)
  END IF;

  -- ── 2. Anything to do? (PENDING or RETRY_FAILED — never REJECTED) ──
  v_sql := 'SELECT COUNT(*) FROM ' || :v_quarantine_tbl ||
           ' WHERE QUARANTINE_STATUS IN (''PENDING'',''RETRY_FAILED'')';
  v_rs := (EXECUTE IMMEDIATE :v_sql);
  LET cr_cnt CURSOR FOR v_rs; OPEN cr_cnt; FETCH cr_cnt INTO v_candidate_count; CLOSE cr_cnt;

  IF (v_candidate_count = 0) THEN
    RETURN OBJECT_CONSTRUCT('status','SKIPPED','reason','No PENDING/RETRY_FAILED rows in quarantine');
  END IF;

  CALL NEW_TEST.AUDIT.LOG_PIPELINE_START(
    :P_PIPELINE_CODE, :P_ENVIRONMENT, NULL, 0, FALSE, 'REPROCESS'
  ) INTO v_run_id;

  -- ── 3. Build ONE combined fail-expression across ALL active rules ──
  --     A row is STILL BAD if it fails ANY rule. A row PASSES only if it
  --     fails NONE. This is the pro-safe part: a partially-fixed row
  --     (passes one rule, fails another) is NOT promoted.
  DECLARE
    rs_rules RESULTSET DEFAULT (
      SELECT RULE_CODE, RULE_TYPE, COLUMN_NAME, RULE_EXPRESSION
      FROM NEW_TEST.REFERENCE.DQM_RULES
      WHERE PIPELINE_CODE = :P_PIPELINE_CODE AND IS_ACTIVE = TRUE AND ACTION_ON_FAIL = 'QUARANTINE'
    );
    cr_rules CURSOR FOR rs_rules;
  BEGIN
    FOR rec IN cr_rules DO
      LET v_cond VARCHAR :=
        CASE rec.RULE_TYPE
          WHEN 'NOT_NULL'        THEN rec.COLUMN_NAME || ' IS NULL'
          WHEN 'REGEX'           THEN 'NOT REGEXP_LIKE(' || rec.COLUMN_NAME || ', ''' || rec.RULE_EXPRESSION || ''')'
          WHEN 'ACCEPTED_VALUES' THEN rec.COLUMN_NAME || ' NOT IN (''' || REPLACE(rec.RULE_EXPRESSION, ',', ''',''') || ''')'
          WHEN 'RANGE'           THEN '(' || rec.COLUMN_NAME || ' < ' || SPLIT_PART(rec.RULE_EXPRESSION, ',', 1) ||
                                       ' OR ' || rec.COLUMN_NAME || ' > ' || SPLIT_PART(rec.RULE_EXPRESSION, ',', 2) || ')'
          WHEN 'REFERENTIAL'     THEN rec.COLUMN_NAME || ' NOT IN (SELECT ' || SPLIT_PART(rec.RULE_EXPRESSION,'.',4) ||
                                       ' FROM ' || SPLIT_PART(rec.RULE_EXPRESSION,'.',1) || '.' || SPLIT_PART(rec.RULE_EXPRESSION,'.',2) || '.' || SPLIT_PART(rec.RULE_EXPRESSION,'.',3) || ')'
          ELSE NULL
        END;

      -- UNIQUE handled separately below (needs self-join on candidate set); skip here
      IF (rec.RULE_TYPE = 'UNIQUE') THEN
        v_cond := rec.COLUMN_NAME || ' IN (SELECT ' || rec.COLUMN_NAME || ' FROM ' || v_quarantine_tbl ||
                  ' WHERE QUARANTINE_STATUS IN (''PENDING'',''RETRY_FAILED'') GROUP BY ' || rec.COLUMN_NAME ||
                  ' HAVING COUNT(*) > 1)';
      END IF;

      IF (v_cond IS NOT NULL) THEN
        IF (v_fail_any = '') THEN
          v_fail_any := '(' || v_cond || ')';
        ELSE
          v_fail_any := v_fail_any || ' OR (' || v_cond || ')';
        END IF;
      END IF;
    END FOR;
  END;

  -- Safety: if no rules resolved, do nothing (don't auto-pass everything)
  IF (v_fail_any = '') THEN
    CALL NEW_TEST.AUDIT.LOG_PIPELINE_SUCCESS(
      :v_run_id, :P_PIPELINE_CODE, :P_ENVIRONMENT,
      :v_candidate_count, 0, NULL, NULL, NULL, NULL, NULL, NULL,
      'WARNING', NULL, LAST_QUERY_ID());
    RETURN OBJECT_CONSTRUCT('status','SKIPPED','reason','No resolvable active rules — nothing promoted');
  END IF;

  -- ── 4. Mark rows that PASS ALL rules as REPROCESSED ──
  --     (candidate rows whose PK does NOT satisfy the combined fail expression)
  v_sql := 'UPDATE ' || v_quarantine_tbl ||
           ' SET QUARANTINE_STATUS = ''REPROCESSED'',' ||
           '     REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1,' ||
           '     LAST_REPROCESS_AT = CURRENT_TIMESTAMP(),' ||
           '     REPROCESSED_RUN_ID = ''' || v_run_id || '''' ||
           ' WHERE QUARANTINE_STATUS IN (''PENDING'',''RETRY_FAILED'')' ||
           '   AND NOT (' || v_fail_any || ')';
  EXECUTE IMMEDIATE :v_sql;

  -- ── 5. Still-bad rows: attempt+1; RETRY_FAILED, or REJECTED at the cap ──
  v_sql := 'UPDATE ' || v_quarantine_tbl ||
           ' SET REPROCESS_ATTEMPTS = REPROCESS_ATTEMPTS + 1,' ||
           '     QUARANTINE_STATUS = CASE WHEN REPROCESS_ATTEMPTS + 1 >= ' || v_max_attempts ||
           '                              THEN ''REJECTED'' ELSE ''RETRY_FAILED'' END,' ||
           '     LAST_REPROCESS_AT = CURRENT_TIMESTAMP(),' ||
           '     REPROCESSED_RUN_ID = ''' || v_run_id || '''' ||
           ' WHERE QUARANTINE_STATUS IN (''PENDING'',''RETRY_FAILED'')' ||
           '   AND (' || v_fail_any || ')';
  EXECUTE IMMEDIATE :v_sql;

  -- ── 6. Build dynamic column lists from the TARGET table (carry all cols) ──
  v_target_db     := SPLIT_PART(v_target_tbl, '.', 1);
  v_target_schema := SPLIT_PART(v_target_tbl, '.', 2);
  v_target_name   := SPLIT_PART(v_target_tbl, '.', 3);

  v_sql :=
    'SELECT ' ||
    '  LISTAGG(''tgt.'' || COLUMN_NAME || '' = src.'' || COLUMN_NAME, '', '') WITHIN GROUP (ORDER BY ORDINAL_POSITION), ' ||
    '  LISTAGG(COLUMN_NAME, '', '') WITHIN GROUP (ORDER BY ORDINAL_POSITION), ' ||
    '  LISTAGG(''src.'' || COLUMN_NAME, '', '') WITHIN GROUP (ORDER BY ORDINAL_POSITION) ' ||
    'FROM ' || v_target_db || '.INFORMATION_SCHEMA.COLUMNS ' ||
    'WHERE TABLE_SCHEMA = ''' || v_target_schema || ''' ' ||
    '  AND TABLE_NAME = ''' || v_target_name || ''' ' ||
    '  AND COLUMN_NAME NOT IN (' ||
    '    ''QUARANTINE_ID'',''QUARANTINE_REASON'',''QUARANTINE_RULE_CODE'',''QUARANTINE_SEVERITY'',' ||
    '    ''QUARANTINED_AT'',''BATCH_ID'',''RUN_ID'',''QUARANTINE_STATUS'',''REPROCESS_ATTEMPTS'',' ||
    '    ''LAST_REPROCESS_AT'',''REPROCESSED_RUN_ID'')';
  v_rs := (EXECUTE IMMEDIATE :v_sql);
  LET cr_cols CURSOR FOR v_rs;
  OPEN cr_cols; FETCH cr_cols INTO v_set_list, v_col_list, v_src_list; CLOSE cr_cols;

  -- ── 7. MERGE the now-good (REPROCESSED) rows back to target (PK from registry) ──
  v_sql := 'MERGE INTO ' || v_target_tbl || ' tgt' ||
           ' USING (SELECT * FROM ' || v_quarantine_tbl ||
           '   WHERE QUARANTINE_STATUS = ''REPROCESSED'' AND REPROCESSED_RUN_ID = ''' || v_run_id || ''') src' ||
           ' ON tgt.' || v_pk_column || ' = src.' || v_pk_column ||
           ' WHEN MATCHED THEN UPDATE SET ' || v_set_list ||
           ' WHEN NOT MATCHED THEN INSERT (' || v_col_list || ') VALUES (' || v_src_list || ')';
  EXECUTE IMMEDIATE :v_sql;

  -- ── 8. Counts ──
  v_sql := 'SELECT COUNT(*) FROM ' || v_quarantine_tbl || ' WHERE REPROCESSED_RUN_ID = ''' || v_run_id || ''' AND QUARANTINE_STATUS = ''REPROCESSED''';
  v_rs := (EXECUTE IMMEDIATE :v_sql);
  LET cr_r CURSOR FOR v_rs; OPEN cr_r; FETCH cr_r INTO v_reprocessed; CLOSE cr_r;

  v_sql := 'SELECT COUNT(*) FROM ' || v_quarantine_tbl || ' WHERE REPROCESSED_RUN_ID = ''' || v_run_id || ''' AND QUARANTINE_STATUS = ''RETRY_FAILED''';
  v_rs := (EXECUTE IMMEDIATE :v_sql);
  LET cr_f CURSOR FOR v_rs; OPEN cr_f; FETCH cr_f INTO v_still_failed; CLOSE cr_f;

  v_sql := 'SELECT COUNT(*) FROM ' || v_quarantine_tbl || ' WHERE REPROCESSED_RUN_ID = ''' || v_run_id || ''' AND QUARANTINE_STATUS = ''REJECTED''';
  v_rs := (EXECUTE IMMEDIATE :v_sql);
  LET cr_x CURSOR FOR v_rs; OPEN cr_x; FETCH cr_x INTO v_rejected; CLOSE cr_x;

  -- ── 9. Remove successfully reprocessed rows from quarantine ──
  v_sql := 'DELETE FROM ' || v_quarantine_tbl || ' WHERE QUARANTINE_STATUS = ''REPROCESSED'' AND REPROCESSED_RUN_ID = ''' || v_run_id || '''';
  EXECUTE IMMEDIATE :v_sql;

  CALL NEW_TEST.AUDIT.LOG_PIPELINE_SUCCESS(
    :v_run_id, :P_PIPELINE_CODE, :P_ENVIRONMENT,
    :v_candidate_count, :v_reprocessed, NULL, NULL, NULL, NULL, NULL, NULL,
    CASE WHEN :v_still_failed > 0 OR :v_rejected > 0 THEN 'WARNING' ELSE 'PASSED' END,
    NULL, LAST_QUERY_ID());

  RETURN OBJECT_CONSTRUCT(
    'status','COMPLETED',
    'pipeline_code', :P_PIPELINE_CODE,
    'candidates',    :v_candidate_count,
    'reprocessed',   :v_reprocessed,
    'still_failed',  :v_still_failed,
    'rejected',      :v_rejected,
    'max_attempts',  :v_max_attempts,
    'run_id',        :v_run_id,
    'execution_secs', DATEDIFF('second', :v_start_ts, CURRENT_TIMESTAMP())
  );
EXCEPTION
  WHEN OTHER THEN
    RETURN OBJECT_CONSTRUCT('status','ERROR','pipeline_code', :P_PIPELINE_CODE, 'error', SQLERRM);
END;
$$;