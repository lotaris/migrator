
-- Migrate the database Sample on environment Prod 1
-- From version 1.4-RC to 1.4-RC3, versioning range 1 to 16
-- Generated at: Tue May 10 14:18:11 +0200 2011
-- Script included:
--           APPLICATIONS         Contextual
--      1.   1.sql                         
--      2.                        1-FreeText.sql
--      3.                        2-FreeText.sql
--      4.   7.sql                         
--      5.                        3-FreeText.sql
--      6.   8-1.sql                         
--      7.                        4-FreeText.sql
--      8.   8.2.sql                         

-- #### Start: storing migration metrics. ####
SET @DB_METRICS_START_TIME = NOW();
SET @DB_METRICS_QUERIES = (SELECT `VARIABLE_VALUE` FROM `INFORMATION_SCHEMA`.`SESSION_STATUS` WHERE `VARIABLE_NAME` = 'QUERIES');
SET @DB_METRICS_COM_DELETE = (SELECT `VARIABLE_VALUE` FROM `INFORMATION_SCHEMA`.`SESSION_STATUS` WHERE `VARIABLE_NAME` = 'COM_DELETE');
...
-- #### End: storing migration metrics. ####

-- #### Start: migration 1 ####
SET @`DB_METRICS_DURATION_OF_1.sql` = (NOW());

... -- Migration queries

SET @`DB_METRICS_DURATION_OF_1.sql` = (TIMESTAMPDIFF(SECOND, @`DB_METRICS_DURATION_OF_1.sql`, NOW()));
-- #### End: migration 1 ####

... -- Other migration parts

-- #### Start: storing migration metrics. ####
SET @DB_METRICS_END_TIME = (NOW());
SET @DB_METRICS_QUERIES = ((SELECT `VARIABLE_VALUE` FROM `INFORMATION_SCHEMA`.`SESSION_STATUS` WHERE `VARIABLE_NAME` = 'QUERIES') - @DB_METRICS_QUERIES);
SET @DB_METRICS_COM_DELETE = ((SELECT `VARIABLE_VALUE` FROM `INFORMATION_SCHEMA`.`SESSION_STATUS` WHERE `VARIABLE_NAME` = 'COM_DELETE') - @DB_METRICS_COM_DELETE);

-- Metrics: store information about the started migration.
INSERT INTO `LotarisLicenseServer`.`LIB_MIG_INFO` (`VERSIONFROM`, `MANIFEST`, `VERSIONTO`, `DURATION`, `REVISIONFROM`, `BYTESRECEIVED`, `REVISIONTO`, `BYTESSENT`, `DATESTART`, `QUERIES`, `DATEEND`) VALUES ('1.4-RC', '<THISFILEHEADER>', '1.4-RC3', TIMESTAMPDIFF(SECOND, @DB_METRICS_START_TIME, @DB_METRICS_END_TIME), 1, @DB_METRICS_BYTES_RECEIVED, 16, @DB_METRICS_BYTES_SENT, @DB_METRICS_START_TIME, @DB_METRICS_QUERIES, @DB_METRICS_END_TIME);

SET @DB_METRICS_LIB_MIG_INFO_ID = (SELECT max(`ID`) FROM `LotarisLicenseServer`.`LIB_MIG_INFO`);

-- Metrics: store metrics.
INSERT INTO `LotarisLicenseServer`.`LIB_MIG_METRIC` (`NAME`, `METRICVALUE`, `MIGRATIONINFO_ID`) 
	VALUES('COM_DELETE', @DB_METRICS_COM_DELETE, @DB_METRICS_LIB_MIG_INFO_ID);
...

-- Metrics: store duration of each script.
INSERT INTO `LotarisLicenseServer`.`LIB_MIG_PART` (`NAME`, `DURATION`, `MIGRATIONINFO_ID`) 
	VALUES ('1.sql', @`DB_METRICS_DURATION_OF_1.sql`, @DB_METRICS_LIB_MIG_INFO_ID);
...
-- #### End: storing migration metrics. ####
