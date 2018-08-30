How to Gather Optimizer Statistics on 11g (Doc ID 749227.1)

Default Settings

Note that the defaults for statistics gathering on different versions of Oracle are not necessarily the same, for example:
ESTIMATE_PERCENT: defaults:
     9i : 100%
    10g : DBMS_STATS.AUTO_SAMPLE_SIZE (using very small estimate percentage)
    11g : DBMS_STATS.AUTO_SAMPLE_SIZE (using larger estimate percentage - 100%)
METHOD_OPT: defaults:
    9i : "FOR ALL COLUMNS SIZE 1" effectively no detailed column statistics.
    10g and 11g : "FOR ALL COLUMNS SIZE AUTO" - This setting means that DBMS_STATS decides which columns to add histogram to where it believes that they may help to produce a better plan.

In 11g, using auto size for ESTIMATE_PERCENT defaults to 100% and therefore is as accurate as possible for the table itself.  In prior versions a 100% sample may have been impossible due to time collection constraints, however 11g implements a new hashing algorithm to compute the statistics rather than sorting (in 9i and 10g the "slow" part was typically the sorting) which significantly improves collection time and resource usage. Note that the column statistics are automatically decided and so a more variable sample may apply here.

How do DBMS_STATS.GATHER_DICTIONARY_STATS and DBMS_STATS.GATHER_DATABASE_STATS Gather 'SYS' and 'SYSTEM' Statistics? (Doc ID 2100050.1)

Does executing DBMS_STATS.GATHER_DICTIONARY_STATS gather statistics on schemas other than the "SYS" schema?
Yes. From dbmsstat.sql in $ORACLE_HOME/rdbms/admin, the GATHER_DICTIONARY_STATS procedure gathers statistics for dictionary schemas 'SYS', 'SYSTEM' and schema (internal) of RDBMS components.:
...
procedure gather_dictionary_stats
...
-- Gather statistics for dictionary schemas 'SYS', 'SYSTEM' and schemas of
-- RDBMS components.
...
What is the difference between DBMS_STATS.GATHER_DICTIONARY_STATS and DBMS_STATS.GATHER_SCHEMA_STATS ('SYS')?

    GATHER_DICTIONARY_STATS gathers statistics for dictionary schemas 'SYS', 'SYSTEM' and schema (internal) of RDBMS components (as above)
    GATHER_SCHEMA_STATS ('SYS') gathers statistics on objects owned by 'SYS' schema only.

Does "DBMS_STATS.GATHER_DATABASE_STATS" gather statistics on both the 'SYS' and 'SYSTEM' schemas? Do I need to specify "GATHER_SYS=>TRUE" to achieve this?
The GATHER_DATABASE_STATS procedure gathers statistics for all objects in the database. Since "GATHER_SYS" is true for "GATHER_DATABASE_STATS" by default, it is not required to specify this parameter to gather statistics on both the 'SYS' and 'SYSTEM' schemas.

--Compile schema
----------------
EXEC DBMS_UTILITY.COMPILE_SCHEMA(SCHEMA => 'SCOTT');

--Stale Objects
ALTER SESSION SET NLS_DATE_FORMAT='DD-Mon-RR HH24:MI:SS';
COL OWNER FOR A30;
COL TABLE_NAME FOR A35;
COL PARTITION_NAME FOR A35;
SELECT OWNER,TABLE_NAME,PARTITION_NAME,OBJECT_TYPE,LAST_ANALYZED,STALE_STATS
FROM DBA_TAB_STATISTICS WHERE OWNER NOT IN ('SYS','SYSTEM','MDSYS') AND (STALE_STATS='YES' OR STALE_STATS IS NULL) ORDER BY LAST_ANALYZED DESC;

--Analyze Tables
----------------
SET LINES 150 PAGES 5000 TIMING ON ECHO ON;
COL OWNER FOR A30;
SELECT OWNER, SUM(DECODE(NVL(NUM_ROWS,9999), 9999,0,1)) ANALYZED, SUM(DECODE(NVL(NUM_ROWS,9999), 9999,1,0)) NOT_ANALYZED, COUNT(TABLE_NAME) TOTAL_TABLE
FROM DBA_TABLES WHERE OWNER NOT IN ('SYS', 'SYSTEM') GROUP BY OWNER ORDER BY 3 DESC;

--Generate script analyze
-------------------------
SELECT 'ANALYZE TABLE MANDIRIMAIN.'||TABLE_NAME||' ESTIMATE STATISTICS SAMPLE 50 PERCENT;' PERINTAH FROM DBA_TABLES WHERE OWNER='MANDIRIMAIN' ORDER BY 1;
SELECT  'ANALYZE INDEX '||OWNER||'.'||INDEX_NAME||' ESTIMATE STATISTICS SAMPLE 50 PERCENT;' PERINTAH FROM DBA_INDEXES WHERE TABLE_OWNER='MANDIRIMAIN' ORDER BY 1 DESC;

--DBMS_STATS.GATHER examples
----------------------------
EXEC DBMS_STATS.GATHER_DATABASE_STATS;
EXEC DBMS_STATS.GATHER_DATABASE_STATS(ESTIMATE_PERCENT=>DBMS_STATS.AUTO_SAMPLE_SIZE, CASCADE=>TRUE, METHOD_OPT=>'FOR ALL COLUMNS SIZE AUTO', DEGREE=>4);
EXEC DBMS_STATS.GATHER_DICTIONARY_STATS;
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('SCOTT', ESTIMATE_PERCENT=>DBMS_STATS.AUTO_SAMPLE_SIZE, CASCADE=>TRUE, METHOD_OPT=>'FOR ALL COLUMNS SIZE AUTO', DEGREE=>4);
EXEC DBMS_STATS.GATHER_TABLE_STATS(NULL, 'BIGT', ESTIMATE_PERCENT=>DBMS_STATS.AUTO_SAMPLE_SIZE, CASCADE=>TRUE, METHOD_OPT=>'FOR ALL COLUMNS SIZE AUTO', DEGREE=>4);
EXEC DBMS_STATS.GATHER_INDEX_STATS('SCOTT', 'EMPLOYEES_PK', ESTIMATE_PERCENT => 15);
EXEC DBMS_STATS.SET_SCHEMA_PREFS('SCOTT','DEGREE', '5');
EXEC DBMS_STATS.GATHER_TABLE_STATS('OWNER','TABLE_NAME','PARTITION_NAME', GRANULARITY=>'APPROX_GLOBAL AND PARTITION');

--Generate script gather
------------------------
SET TIME ON LINES 150 PAGES 5000;
SELECT
'EXEC DBMS_STATS.GATHER_TABLE_STATS('''||OWNER||''', '''||TABLE_NAME||''', ESTIMATE_PERCENT=>DBMS_STATS.AUTO_SAMPLE_SIZE, METHOD_OPT=>''FOR ALL COLUMNS SIZE AUTO'', CASCADE=>TRUE, DEGREE=>4);' GATH_TABLE
FROM DBA_TAB_STATISTICS WHERE OWNER NOT IN ('SYS','SYSTEM','MDSYS') AND (STALE_STATS='YES' OR STALE_STATS IS NULL) ORDER BY LAST_ANALYZED DESC;

FROM DBA_TABLES WHERE OWNER IN (SELECT USERNAME FROM DBA_USERS) ORDER BY 1;

SET TIME ON LINES 150 PAGES 5000;
SELECT 'EXEC DBMS_STATS.GATHER_SCHEMA_STATS('''||USERNAME||''', ESTIMATE_PERCENT => DBMS_STATS.AUTO_SAMPLE_SIZE, CASCADE => TRUE);'
GATH_SCHEMA FROM DBA_USERS WHERE USERNAME='&SKEMA' ORDER BY 1;

SET TIME ON LINES 150 PAGES 5000;
SELECT
'EXEC DBMS_STATS.GATHER_TABLE_STATS('''||OWNER||''', '''||TABLE_NAME||''', ESTIMATE_PERCENT => DBMS_STATS.AUTO_SAMPLE_SIZE, CASCADE => TRUE);'
GATH_TABLE FROM DBA_TABLES WHERE OWNER='&SKEMA' ORDER BY 1;

SET TIME ON LINES 150 PAGES 5000;
SELECT 'EXEC DBMS_STATS.GATHER_INDEX_STATS('''||OWNER||''', '''||INDEX_NAME||''', ESTIMATE_PERCENT => DBMS_STATS.AUTO_SAMPLE_SIZE);'
GATH_INDEX FROM DBA_INDEXES WHERE TABLE_OWNER='&TBLOWNER' ORDER BY 1;

SET TIME ON LINES 150 PAGES 5000;
SELECT 'EXEC DBMS_STATS.GATHER_SCHEMA_STATS('''||USERNAME||''', ESTIMATE_PERCENT => DBMS_STATS.AUTO_SAMPLE_SIZE, CASCADE => TRUE);'
GATH_SCHEMA FROM DBA_USERS WHERE USERNAME='&SKEMA'
UNION ALL
SELECT
'EXEC DBMS_STATS.GATHER_TABLE_STATS('''||OWNER||''', '''||TABLE_NAME||''', ESTIMATE_PERCENT => DBMS_STATS.AUTO_SAMPLE_SIZE, CASCADE => TRUE);'
GATH_TABLE FROM DBA_TABLES WHERE OWNER='&SKEMA'
UNION ALL
SELECT 'EXEC DBMS_STATS.GATHER_INDEX_STATS('''||OWNER||''', '''||INDEX_NAME||''', ESTIMATE_PERCENT => DBMS_STATS.AUTO_SAMPLE_SIZE);'
GATH_INDEX FROM DBA_INDEXES WHERE TABLE_OWNER='&TBLOWNER';