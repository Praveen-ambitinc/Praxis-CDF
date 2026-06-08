-- ORSINI_DISPENSE_STATUS_INBOUND: 80 columns all 2gether from the file dated: 1/6/26
-- Clear first (idempotent re-run)
UPDATE NEW_TEST.REFERENCE.PIPELINE_MASTER
SET COLUMN_MAPPING = NULL
WHERE PIPELINE_CODE LIKE 'ORSINI%';
 
-- ORSINI_DISPENSE_STATUS_INBOUND
UPDATE NEW_TEST.REFERENCE.PIPELINE_MASTER pm
SET COLUMN_MAPPING = (
    SELECT ARRAY_AGG(
        OBJECT_CONSTRUCT(
            'src',       COLUMN_NAME,
            'tgt',       COLUMN_NAME,
            'data_type', DATA_TYPE,
            'nullable', IFF(IS_NULLABLE = 'YES', TRUE, FALSE)
        )
    ) WITHIN GROUP (ORDER BY ORDINAL_POSITION)
    FROM NEW_TEST.INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'BRONZE'
      AND TABLE_NAME   = 'RAW_ORSINI_DISPENSE_STATUS'
      AND COLUMN_NAME NOT LIKE '\\_AUDIT\\_%' ESCAPE '\\'
)
WHERE pm.PIPELINE_CODE = 'ORSINI_DISPENSE_STATUS_INBOUND';
 
-- ORSINI_INVENTORY_INBOUND
UPDATE NEW_TEST.REFERENCE.PIPELINE_MASTER pm
SET COLUMN_MAPPING = (
    SELECT ARRAY_AGG(
        OBJECT_CONSTRUCT(
            'src',       COLUMN_NAME,
            'tgt',       COLUMN_NAME,
            'data_type', DATA_TYPE,
            'nullable', IFF(IS_NULLABLE = 'YES', TRUE, FALSE)
        )
    ) WITHIN GROUP (ORDER BY ORDINAL_POSITION)
    FROM NEW_TEST.INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'BRONZE'
      AND TABLE_NAME   = 'RAW_ORSINI_INVENTORY'
      AND COLUMN_NAME NOT LIKE '\\_AUDIT\\_%' ESCAPE '\\'
)
WHERE pm.PIPELINE_CODE = 'ORSINI_INVENTORY_INBOUND';
 // THE ABOVE QUERY IS FOR POPULATING THE COLUMN_MAPPING FROM INFORMATION_SCHEMA 
------------------------------------------------------------------------------------------------------
UPDATE NEW_TEST.REFERENCE.PIPELINE_MASTER SET COLUMN_MAPPING = PARSE_JSON($$[
  {
    "src": "SPTRANSACTIONID",
    "tgt": "SPTRANSACTIONID",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "TRANSACTIONTYPE",
    "tgt": "TRANSACTIONTYPE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "RECORDDATE",
    "tgt": "RECORDDATE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "SPNPI",
    "tgt": "SPNPI",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "SPPATIENTID",
    "tgt": "SPPATIENTID",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "HUBPATIENTID",
    "tgt": "HUBPATIENTID",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "PATIENTFIRSTNAME",
    "tgt": "PATIENTFIRSTNAME",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PATIENTMIDDLENAME",
    "tgt": "PATIENTMIDDLENAME",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "PATIENTLASTNAME",
    "tgt": "PATIENTLASTNAME",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PATIENTDOB",
    "tgt": "PATIENTDOB",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PATIENTGENDER",
    "tgt": "PATIENTGENDER",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PATIENTADDRESS1",
    "tgt": "PATIENTADDRESS1",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PATIENTADDRESS2",
    "tgt": "PATIENTADDRESS2",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "PATIENTCITY",
    "tgt": "PATIENTCITY",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PATIENTSTATE",
    "tgt": "PATIENTSTATE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PATIENTZIP",
    "tgt": "PATIENTZIP",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PATIENTPHONE1",
    "tgt": "PATIENTPHONE1",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PATIENTPHONE1TYPE",
    "tgt": "PATIENTPHONE1TYPE",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "PATIENTPHONE2",
    "tgt": "PATIENTPHONE2",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "PATIENTPHONE2TYPE",
    "tgt": "PATIENTPHONE2TYPE",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "PATIENTEMAIL",
    "tgt": "PATIENTEMAIL",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "NPINUMBER",
    "tgt": "NPINUMBER",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PRESCRIBERFIRSTNAME",
    "tgt": "PRESCRIBERFIRSTNAME",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PRESCRIBERLASTNAME",
    "tgt": "PRESCRIBERLASTNAME",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PRESCRIBERADDRESS1",
    "tgt": "PRESCRIBERADDRESS1",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PRESCRIBERADDRESS2",
    "tgt": "PRESCRIBERADDRESS2",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "PRESCRIBERCITY",
    "tgt": "PRESCRIBERCITY",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PRESCRIBERSTATE",
    "tgt": "PRESCRIBERSTATE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PRESCRIBERZIP",
    "tgt": "PRESCRIBERZIP",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PRESCRIBERPHONE",
    "tgt": "PRESCRIBERPHONE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PRESCRIBERFAX",
    "tgt": "PRESCRIBERFAX",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "PRIMARYPAYERTYPE",
    "tgt": "PRIMARYPAYERTYPE",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "PRIMARYMEDICALNAME",
    "tgt": "PRIMARYMEDICALNAME",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "PRIMARYMEDICALMEMBERID",
    "tgt": "PRIMARYMEDICALMEMBERID",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "PRIMARYPBMNAME",
    "tgt": "PRIMARYPBMNAME",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "PRIMARYPBMBIN",
    "tgt": "PRIMARYPBMBIN",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "PRIMARYPBMPCN",
    "tgt": "PRIMARYPBMPCN",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "PRIMARYPBMGROUP",
    "tgt": "PRIMARYPBMGROUP",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "SECONDARYPAYERTYPE",
    "tgt": "SECONDARYPAYERTYPE",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "SECONDARYMEDICALNAME",
    "tgt": "SECONDARYMEDICALNAME",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "SECONDARYMEDICALMEMBERID",
    "tgt": "SECONDARYMEDICALMEMBERID",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "SECONDARYPBMNAME",
    "tgt": "SECONDARYPBMNAME",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "SECONDARYPBMBIN",
    "tgt": "SECONDARYPBMBIN",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "SECONDARYPBMPCN",
    "tgt": "SECONDARYPBMPCN",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "SECONDARYPBMGROUP",
    "tgt": "SECONDARYPBMGROUP",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "TERTIARYPAYERTYPE",
    "tgt": "TERTIARYPAYERTYPE",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "TERTIARYMEDICALNAME",
    "tgt": "TERTIARYMEDICALNAME",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "TERTIARYMEDICALMEMBERID",
    "tgt": "TERTIARYMEDICALMEMBERID",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "TERTIARYPBMNAME",
    "tgt": "TERTIARYPBMNAME",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "TERTIARYPBMBIN",
    "tgt": "TERTIARYPBMBIN",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "TERTIARYPBMPCN",
    "tgt": "TERTIARYPBMPCN",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "TERTIARYPBMGROUP",
    "tgt": "TERTIARYPBMGROUP",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "CLAIMTYPE",
    "tgt": "CLAIMTYPE",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "COPAY",
    "tgt": "COPAY",
    "data_type": "NUMBER(15,2)",
    "nullable": true
  },
  {
    "src": "COINSURANCE",
    "tgt": "COINSURANCE",
    "data_type": "NUMBER(15,2)",
    "nullable": true
  },
  {
    "src": "PANUMBER",
    "tgt": "PANUMBER",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "PASTARTDATE",
    "tgt": "PASTARTDATE",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "PAENDDATE",
    "tgt": "PAENDDATE",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "DX1CODE",
    "tgt": "DX1CODE",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "DX2CODE",
    "tgt": "DX2CODE",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "RXNUMBER",
    "tgt": "RXNUMBER",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "RXFILL",
    "tgt": "RXFILL",
    "data_type": "NUMBER",
    "nullable": true
  },
  {
    "src": "RXREFILLS",
    "tgt": "RXREFILLS",
    "data_type": "NUMBER",
    "nullable": true
  },
  {
    "src": "NDCNUMBER",
    "tgt": "NDCNUMBER",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PRODUCTNAME",
    "tgt": "PRODUCTNAME",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "QUANTITY",
    "tgt": "QUANTITY",
    "data_type": "NUMBER",
    "nullable": true
  },
  {
    "src": "UOM",
    "tgt": "UOM",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "DAYSUPPLY",
    "tgt": "DAYSUPPLY",
    "data_type": "NUMBER",
    "nullable": true
  },
  {
    "src": "SHIPDATE",
    "tgt": "SHIPDATE",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "SHIPCARRIER",
    "tgt": "SHIPCARRIER",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "REFERRALDATE",
    "tgt": "REFERRALDATE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "STATUS",
    "tgt": "STATUS",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "SUB_STATUS",
    "tgt": "SUB_STATUS",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "SOCNAME",
    "tgt": "SOCNAME",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "SOCADDRESS1",
    "tgt": "SOCADDRESS1",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "SOCADDRESS2",
    "tgt": "SOCADDRESS2",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "SOCCITY",
    "tgt": "SOCCITY",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "SOCSTATE",
    "tgt": "SOCSTATE",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "SOCZIP",
    "tgt": "SOCZIP",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "SOCPHONE",
    "tgt": "SOCPHONE",
    "data_type": "VARCHAR",
    "nullable": true
  }
]$$) WHERE PIPELINE_CODE = 'ORSINI_DISPENSE_STATUS_INBOUND';
 
-- ORSINI_INVENTORY_INBOUND: 17 columns
UPDATE NEW_TEST.REFERENCE.PIPELINE_MASTER SET COLUMN_MAPPING = PARSE_JSON($$[
  {
    "src": "STARTDATE",
    "tgt": "STARTDATE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "ENDDATE",
    "tgt": "ENDDATE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "VENDORNAME",
    "tgt": "VENDORNAME",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "FULFILLMENTCENTERNAME",
    "tgt": "FULFILLMENTCENTERNAME",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "FULFILLMENTCENTERNUMBER",
    "tgt": "FULFILLMENTCENTERNUMBER",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "FULFILLMENTCENTERIDENTIFIER",
    "tgt": "FULFILLMENTCENTERIDENTIFIER",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PHARMACYITEMNUMBER",
    "tgt": "PHARMACYITEMNUMBER",
    "data_type": "VARCHAR",
    "nullable": true
  },
  {
    "src": "PRODUCTIDENTIFIERNDC",
    "tgt": "PRODUCTIDENTIFIERNDC",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "PRODUCTUNITOFMEASURE",
    "tgt": "PRODUCTUNITOFMEASURE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "QUANTITYONHAND",
    "tgt": "QUANTITYONHAND",
    "data_type": "NUMBER",
    "nullable": false
  },
  {
    "src": "BEGINNINGQUANTITYONHAND",
    "tgt": "BEGINNINGQUANTITYONHAND",
    "data_type": "NUMBER",
    "nullable": false
  },
  {
    "src": "QUANTITYRECEIVED",
    "tgt": "QUANTITYRECEIVED",
    "data_type": "NUMBER",
    "nullable": false
  },
  {
    "src": "QUANTITYSOLD",
    "tgt": "QUANTITYSOLD",
    "data_type": "NUMBER",
    "nullable": false
  },
  {
    "src": "QUANTITYONORDER",
    "tgt": "QUANTITYONORDER",
    "data_type": "NUMBER",
    "nullable": false
  },
  {
    "src": "QUANTITYADJUSTED",
    "tgt": "QUANTITYADJUSTED",
    "data_type": "NUMBER",
    "nullable": false
  },
  {
    "src": "QUANTITYTRANSFERRED",
    "tgt": "QUANTITYTRANSFERRED",
    "data_type": "NUMBER",
    "nullable": false
  },
  {
    "src": "QUANTITYRETURNED",
    "tgt": "QUANTITYRETURNED",
    "data_type": "NUMBER",
    "nullable": false
  }
]$$) WHERE PIPELINE_CODE = 'ORSINI_INVENTORY_INBOUND';
 
SELECT PIPELINE_CODE, PK_COLUMN, WATERMARK_COLUMN, COLUMN_MAPPING AS col_count FROM NEW_TEST.REFERENCE.PIPELINE_MASTER
WHERE PIPELINE_CODE LIKE 'ORSINI%'; -- CAN USE ARRAY_SIZE FUNCTION

----------------------------------------------------------------------------------------------------
//HCP Column mapping 
UPDATE NEW_TEST.REFERENCE.PIPELINE_MASTER SET COLUMN_MAPPING = NULL WHERE PIPELINE_CODE LIKE 'VEEVA_NETWORK%';
 
-- VEEVA_NETWORK_HCP_INBOUND: 20 mappings
UPDATE NEW_TEST.REFERENCE.PIPELINE_MASTER
SET COLUMN_MAPPING = PARSE_JSON($$[
  {
    "src": "vid__v",
    "tgt": "NETWORK_VID",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "first_name_cda__v",
    "tgt": "FIRST_NAME",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "last_name_cda__v",
    "tgt": "LAST_NAME",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "middle_name_cda__v",
    "tgt": "MIDDLE_NAME",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "prefix_cda__v",
    "tgt": "PREFIX",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "hcp_type_cda__v",
    "tgt": "HCP_TYPE_CDA",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "prescriber_cda__v",
    "tgt": "IS_PRESCRIBER",
    "data_type": "BOOLEAN",
    "nullable": false
  },
  {
    "src": "degree_1_cda__v",
    "tgt": "DEGREE_PRIMARY",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "spec_1_cda__v",
    "tgt": "SPECIALTY_PRIMARY",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "spec_group_1_cda__v",
    "tgt": "SPECIALTY_GROUP",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "npi_num__v",
    "tgt": "NPI",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "nhid_cda__v",
    "tgt": "NPI",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "in_current_pecos__v",
    "tgt": "IN_CURRENT_PECOS",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "email_cda__v",
    "tgt": "EMAIL_PRIMARY",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "office_phone_cda__v",
    "tgt": "PHONE_PRIMARY",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "gender__v",
    "tgt": "GENDER",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "data_privacy_opt_out__v",
    "tgt": "DATA_PRIVACY_OPT_OUT",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "record_state__v",
    "tgt": "RECORD_STATE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "created_date__v",
    "tgt": "NETWORK_CREATED_DATE",
    "data_type": "TIMESTAMP",
    "nullable": false
  },
  {
    "src": "modified_date__v",
    "tgt": "NETWORK_MODIFIED_DATE",
    "data_type": "TIMESTAMP",
    "nullable": false
  }
]$$)
WHERE PIPELINE_CODE = 'VEEVA_NETWORK_HCP_INBOUND';
 
-- VEEVA_NETWORK_HCO_INBOUND: 31 mappings
UPDATE NEW_TEST.REFERENCE.PIPELINE_MASTER
SET COLUMN_MAPPING = PARSE_JSON($$[
  {
    "src": "vid__v",
    "tgt": "NETWORK_VID",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "hco_name_cda__v",
    "tgt": "HCO_NAME",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "hco_name_short__v",
    "tgt": "HCO_NAME_SHORT",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "hco_type_cda__v",
    "tgt": "HCO_TYPE_CDA",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "hco_type_local__v",
    "tgt": "HCO_TYPE_LOCAL",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "status_cda__v",
    "tgt": "HCO_STATUS",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "npi_num__v",
    "tgt": "NPI",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "nhid_cda__v",
    "tgt": "NPI",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "key_hco_network__v",
    "tgt": "IS_IDN",
    "data_type": "BOOLEAN",
    "nullable": false
  },
  {
    "src": "key_hco_network_alias__v",
    "tgt": "IDN_ALIAS",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "main_org_veevaid__v",
    "tgt": "MAIN_ORG_VID",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "main_org_name__v",
    "tgt": "MAIN_ORG_NAME",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "top_org_veevaid__v",
    "tgt": "TOP_ORG_VID",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "top_org_name__v",
    "tgt": "TOP_ORG_NAME",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "academic_status__v",
    "tgt": "ACADEMIC_STATUS",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "ownership__v",
    "tgt": "OWNERSHIP",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "count_beds__v",
    "tgt": "COUNT_BEDS",
    "data_type": "NUMBER",
    "nullable": false
  },
  {
    "src": "count_hcp__v",
    "tgt": "COUNT_HCP_RANGE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "count_prescriber__v",
    "tgt": "COUNT_PRESCRIBER_RANGE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "infusions_performed__v",
    "tgt": "INFUSIONS_PERFORMED",
    "data_type": "BOOLEAN",
    "nullable": false
  },
  {
    "src": "infusion_chairs__v",
    "tgt": "INFUSION_CHAIRS",
    "data_type": "NUMBER",
    "nullable": false
  },
  {
    "src": "340B_eligible__v",
    "tgt": "IS_340B_ELIGIBLE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "340B_id_1__v",
    "tgt": "B340_ID",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "ncpdp_num__v",
    "tgt": "NCPDP_NUM",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "office_phone_cda__v",
    "tgt": "PHONE_PRIMARY",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "city_cda__v",
    "tgt": "CITY",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "state_cda__v",
    "tgt": "STATE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "postal_code_cda__v",
    "tgt": "POSTAL_CODE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "record_state__v",
    "tgt": "RECORD_STATE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "created_date__v",
    "tgt": "NETWORK_CREATED_DATE",
    "data_type": "TIMESTAMP",
    "nullable": false
  },
  {
    "src": "modified_date__v",
    "tgt": "NETWORK_MODIFIED_DATE",
    "data_type": "TIMESTAMP",
    "nullable": false
  }
]$$)
WHERE PIPELINE_CODE = 'VEEVA_NETWORK_HCO_INBOUND';
 
-- VEEVA_NETWORK_ADDRSS_INBOUND: 16 mappings
UPDATE NEW_TEST.REFERENCE.PIPELINE_MASTER
SET COLUMN_MAPPING = PARSE_JSON($$[
  {
    "src": "vid__v",
    "tgt": "NETWORK_VID",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "entity_vid__v",
    "tgt": "ENTITY_VID",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "entity_type__v",
    "tgt": "ENTITY_TYPE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "street_address_1_cda__v",
    "tgt": "STREET_ADDRESS_1",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "street_address_2_cda__v",
    "tgt": "STREET_ADDRESS_2",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "city_cda__v",
    "tgt": "CITY",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "state_cda__v",
    "tgt": "STATE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "postal_code_cda__v",
    "tgt": "POSTAL_CODE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "country_cda__v",
    "tgt": "COUNTRY",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "phone_cda__v",
    "tgt": "PHONE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "primary_cda__v",
    "tgt": "IS_PRIMARY",
    "data_type": "BOOLEAN",
    "nullable": false
  },
  {
    "src": "address_verification_status__v",
    "tgt": "VERIFICATION_STATUS",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "latitude_cda__v",
    "tgt": "LATITUDE",
    "data_type": "NUMBER",
    "nullable": false
  },
  {
    "src": "longitude_cda__v",
    "tgt": "LONGITUDE",
    "data_type": "NUMBER",
    "nullable": false
  },
  {
    "src": "status_cda__v",
    "tgt": "ADDRESS_STATUS",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "modified_date__v",
    "tgt": "NETWORK_MODIFIED_DATE",
    "data_type": "TIMESTAMP",
    "nullable": false
  }
]$$)
WHERE PIPELINE_CODE = 'VEEVA_NETWORK_ADDRSS_INBOUND';
 
-- VEEVA_NETWORK_LICENSE_INBOUND: 15 mappings
UPDATE NEW_TEST.REFERENCE.PIPELINE_MASTER
SET COLUMN_MAPPING = PARSE_JSON($$[
  {
    "src": "vid__v",
    "tgt": "NETWORK_VID",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "entity_vid__v",
    "tgt": "ENTITY_VID",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "entity_type__v",
    "tgt": "ENTITY_TYPE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "address_vid__v",
    "tgt": "ADDRESS_VID",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "license_number__v",
    "tgt": "LICENSE_NUMBER",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "type__v",
    "tgt": "LICENSE_TYPE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "type_value__v",
    "tgt": "LICENSING_AUTHORITY",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "license_degree__v",
    "tgt": "LICENSE_DEGREE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "expiration_date__v",
    "tgt": "EXPIRATION_DATE",
    "data_type": "DATE",
    "nullable": false
  },
  {
    "src": "license_status__v",
    "tgt": "LICENSE_STATUS",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "license_status_condition__v",
    "tgt": "LICENSE_STATUS_CONDITION",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "rxa_eligible__v",
    "tgt": "SAMPLE_ELIGIBLE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "license_eligibility__v",
    "tgt": "PRESCRIPTIVE_AUTH",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "best_state_license__v",
    "tgt": "IS_BEST_STATE_LICENSE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "modified_date__v",
    "tgt": "NETWORK_MODIFIED_DATE",
    "data_type": "TIMESTAMP",
    "nullable": false
  }
]$$)
WHERE PIPELINE_CODE = 'VEEVA_NETWORK_LICENSE_INBOUND';
 
-- VEEVA_NETWORK_PARENTHCO_INBOUND: 8 mappings
UPDATE NEW_TEST.REFERENCE.PIPELINE_MASTER
SET COLUMN_MAPPING = PARSE_JSON($$[
  {
    "src": "vid__v",
    "tgt": "NETWORK_VID",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "entity_vid__v",
    "tgt": "ENTITY_VID",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "entity_type__v",
    "tgt": "ENTITY_TYPE",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "parent_hco_vid__v",
    "tgt": "PARENT_HCO_VID",
    "data_type": "VARCHAR",
    "nullable": false
  },
  {
    "src": "is_primary_relationship__v",
    "tgt": "IS_PRIMARY",
    "data_type": "BOOLEAN",
    "nullable": false
  },
  {
    "src": "start_date__v",
    "tgt": "START_DATE",
    "data_type": "DATE",
    "nullable": false
  },
  {
    "src": "end_date__v",
    "tgt": "END_DATE",
    "data_type": "DATE",
    "nullable": false
  },
  {
    "src": "modified_date__v",
    "tgt": "NETWORK_MODIFIED_DATE",
    "data_type": "TIMESTAMP",
    "nullable": false
  }
]$$)
WHERE PIPELINE_CODE = 'VEEVA_NETWORK_PARENTHCO_INBOUND';

-- INVENTORY_MOVEMENTS_INBOUND: 13 columns | PK=['TRANSACTION_NUMBER']
UPDATE NEW_TEST.REFERENCE.PIPELINE_MASTER
SET COLUMN_MAPPING = PARSE_JSON($$[
  {
    "src": "Item",
    "tgt": "ITEM"
  },
  {
    "src": "Type",
    "tgt": "TYPE"
  },
  {
    "src": "Date",
    "tgt": "DATE"
  },
  {
    "src": "Transaction Number",
    "tgt": "TRANSACTION_NUMBER"
  },
  {
    "src": "Vendor Name",
    "tgt": "VENDOR_NAME"
  },
  {
    "src": "Lot Number",
    "tgt": "LOT_NUMBER"
  },
  {
    "src": "Expiration Date",
    "tgt": "EXPIRATION_DATE"
  },
  {
    "src": "Item Count",
    "tgt": "ITEM_COUNT"
  },
  {
    "src": "Bin Number",
    "tgt": "BIN_NUMBER"
  },
  {
    "src": "Is Inventory-Affecting",
    "tgt": "IS_INVENTORY_AFFECTING"
  },
  {
    "src": "Status",
    "tgt": "STATUS"
  },
  {
    "src": "Location",
    "tgt": "LOCATION"
  },
  {
    "src": "Quantity",
    "tgt": "QUANTITY"
  }
]$$)
WHERE PIPELINE_CODE = 'INVENTORY_MOVEMENTS_INBOUND';

 select pipeline_code from new_test.reference.pipeline_master

 ---------------
 -- ORDER_REPORTS_INBOUND: 18 columns | PK=['TRANSACTION_DOCUMENT_NUMBER_ID']
UPDATE NEW_TEST.REFERENCE.PIPELINE_MASTER
SET COLUMN_MAPPING = PARSE_JSON($$[
  {
    "src": "Date",
    "tgt": "DATE"
  },
  {
    "src": "Transaction Type",
    "tgt": "TRANSACTION_TYPE"
  },
  {
    "src": "Transaction: Document Number/ID",
    "tgt": "TRANSACTION_DOCUMENT_NUMBER_ID"
  },
  {
    "src": "Line ID",
    "tgt": "LINE_ID"
  },
  {
    "src": "Customer: Entity ID",
    "tgt": "CUSTOMER_ENTITY_ID"
  },
  {
    "src": "Customer: Customer",
    "tgt": "CUSTOMER_CUSTOMER"
  },
  {
    "src": "Default Shipping Address: Address1",
    "tgt": "DEFAULT_SHIPPING_ADDRESS1"
  },
  {
    "src": "Default Shipping Address: City",
    "tgt": "DEFAULT_SHIPPING_CITY"
  },
  {
    "src": "Default Shipping Address: State",
    "tgt": "DEFAULT_SHIPPING_STATE"
  },
  {
    "src": "Default Shipping Address: Zip",
    "tgt": "DEFAULT_SHIPPING_ZIP"
  },
  {
    "src": "Item",
    "tgt": "ITEM"
  },
  {
    "src": "Amount",
    "tgt": "AMOUNT"
  },
  {
    "src": "Amount (NET)",
    "tgt": "AMOUNT_NET"
  },
  {
    "src": "Quantity",
    "tgt": "QUANTITY"
  },
  {
    "src": "Serial/Lot Numbers",
    "tgt": "SERIAL_LOT_NUMBERS"
  },
  {
    "src": "Coupon Code",
    "tgt": "COUPON_CODE"
  },
  {
    "src": "Ship Date",
    "tgt": "SHIP_DATE"
  },
  {
    "src": "Invoice Date",
    "tgt": "INVOICE_DATE"
  }
]$$)
WHERE PIPELINE_CODE = 'ORSINI3PL_ORDER_REPORTS_INBOUND';

desc table   new_test.reference.pipeline_master

-- INVENTORY_MOVEMENTS_INBOUND: 13 columns | PK=['TRANSACTION_NUMBER']
UPDATE NEW_TEST.REFERENCE.PIPELINE_MASTER
SET COLUMN_MAPPING = PARSE_JSON($$[
  {
    "src": "Item",
    "tgt": "ITEM"
  },
  {
    "src": "Type",
    "tgt": "TYPE"
  },
  {
    "src": "Date",
    "tgt": "DATE"
  },
  {
    "src": "Transaction Number",
    "tgt": "TRANSACTION_NUMBER"
  },
  {
    "src": "Vendor Name",
    "tgt": "VENDOR_NAME"
  },
  {
    "src": "Lot Number",
    "tgt": "LOT_NUMBER"
  },
  {
    "src": "Expiration Date",
    "tgt": "EXPIRATION_DATE"
  },
  {
    "src": "Item Count",
    "tgt": "ITEM_COUNT"
  },
  {
    "src": "Bin Number",
    "tgt": "BIN_NUMBER"
  },
  {
    "src": "Is Inventory-Affecting",
    "tgt": "IS_INVENTORY_AFFECTING"
  },
  {
    "src": "Status",
    "tgt": "STATUS"
  },
  {
    "src": "Location",
    "tgt": "LOCATION"
  },
  {
    "src": "Quantity",
    "tgt": "QUANTITY"
  }
]$$)
WHERE PIPELINE_CODE = 'ORSINI3PL_INVENTORY_MOVEMENTS_INBOUND';

select pipeline_code, pk_column from new_test.reference.pipeline_master
where pipeline_code like 'ORSINI%'

select read_filter from new_test.reference.pipeline_master
where pipeline_code like 'ORSINI%'

- 1. Add config columns (non-secret)
ALTER TABLE NEW_TEST.REFERENCE.PIPELINE_MASTER ADD COLUMN SOURCE_ENDPOINT VARCHAR(1000);
ALTER TABLE NEW_TEST.REFERENCE.PIPELINE_MASTER ADD COLUMN AUTH_TYPE VARCHAR(20) DEFAULT 'NONE';
ALTER TABLE NEW_TEST.REFERENCE.PIPELINE_MASTER ADD COLUMN SECRET_REF VARCHAR(200);
 
-- 2. ORDER_REPORTS — jsonblob test endpoint, no auth
UPDATE NEW_TEST.REFERENCE.PIPELINE_MASTER
SET SOURCE_ENDPOINT = 'https://jsonblob.com/api/jsonBlob/019e91e8-f9bb-7c6a-8996-7f53153817ec',
    AUTH_TYPE       = 'NONE',
    SECRET_REF      = NULL,
    UPDATED_AT      = CURRENT_TIMESTAMP()
WHERE PIPELINE_CODE = 'ORSINI3PL_ORDER_REPORTS_INBOUND';
 
-- 3. INVENTORY_MOVEMENTS — jsonblob test endpoint, no auth
UPDATE NEW_TEST.REFERENCE.PIPELINE_MASTER
SET SOURCE_ENDPOINT = 'https://jsonblob.com/api/jsonBlob/019e91e8-4019-75e0-8c51-7f2c178bff0a',
    AUTH_TYPE       = 'NONE',
    SECRET_REF      = NULL,
    UPDATED_AT      = CURRENT_TIMESTAMP()
WHERE PIPELINE_CODE = 'ORSINI3PL_INVENTORY_MOVEMENTS_INBOUND';
 
-- 4. Verify
SELECT PIPELINE_CODE, SOURCE_ENDPOINT, AUTH_TYPE, SECRET_REF
FROM NEW_TEST.REFERENCE.PIPELINE_MASTER
WHERE PIPELINE_CODE LIKE 'ORSINI3PL%';

UPDATE NEW_TEST.REFERENCE.PIPELINE_MASTER
SET COLUMN_MAPPING = PARSE_JSON($$[
  {"src":"Item","tgt":"ITEM"},
  {"src":"Type","tgt":"TYPE"},
  {"src":"Date","tgt":"DATE"},
  {"src":"Transaction Number","tgt":"TRANSACTION_NUMBER"},
  {"src":"Vendor Name","tgt":"VENDOR_NAME"},
  {"src":" Lot Number","tgt":"LOT_NUMBER"},
  {"src":"Expiration Date","tgt":"EXPIRATION_DATE"},
  {"src":"Item Count","tgt":"ITEM_COUNT"},
  {"src":"Bin Number","tgt":"BIN_NUMBER"},
  {"src":"Is Inventory-Affecting","tgt":"IS_INVENTORY_AFFECTING"},
  {"src":"Status","tgt":"STATUS"},
  {"src":"Location","tgt":"LOCATION"},
  {"src":"Quantity","tgt":"QUANTITY"}
]$$)
WHERE PIPELINE_CODE = 'ORSINI3PL_INVENTORY_MOVEMENTS_INBOUND';

CREATE OR REPLACE TABLE NEW_TEST.BRONZE.STG_ORSINI3PL_ORDER_REPORTS
  LIKE NEW_TEST.BRONZE.RAW_ORSINI3PL_ORDER_REPORTS;
 
CREATE OR REPLACE TABLE NEW_TEST.BRONZE.STG_ORSINI3PL_INVENTORY_MOVEMENTS
  LIKE NEW_TEST.BRONZE.RAW_ORSINI3PL_INVENTORY_MOVEMENTS;

