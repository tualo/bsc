
DELIMITER //
CREATE FUNCTION IF NOT EXISTS `getTableForeignKeys`(in_database varchar(64), in_table_name varchar(64) ) RETURNS longtext CHARSET utf8mb4 COLLATE utf8mb4_general_ci
    READS SQL DATA
BEGIN
    DECLARE strDEF longtext;
SELECT
group_concat(
      concat(' 
        CONSTRAINT `',lower(CONSTRAINT_NAME),'`
        FOREIGN KEY (',COLUMN_NAMES,')
        REFERENCES `',REFERENCED_TABLE_NAME,'` (',REFERENCED_COLUMN_NAMES,')
        ON DELETE ',DELETE_RULE,'
        ON UPDATE ',UPDATE_RULE,'
      ')
      SEPARATOR ',
      '
) 
INTO strDEF
FROM (
SELECT
	C.CONSTRAINT_NAME,
    C.TABLE_NAME,
    C.REFERENCED_TABLE_NAME,
    C.COLUMN_NAMES,
    C.REFERENCED_COLUMN_NAMES,
    
    R.DELETE_RULE,
    R.UPDATE_RULE
FROM (
select 
	col.CONSTRAINT_NAME,
    col.TABLE_NAME,
    col.REFERENCED_TABLE_NAME,
    
    group_concat(
      concat('`',lower(COLUMN_NAME),'`')
      ORDER BY col.ORDINAL_POSITION
      SEPARATOR ','
    ) COLUMN_NAMES,
    group_concat(
      concat('`',lower(REFERENCED_COLUMN_NAME),'`')
      ORDER BY col.ORDINAL_POSITION
      SEPARATOR ','
    ) REFERENCED_COLUMN_NAMES
    FROM
    information_schema.key_column_usage col
    WHERE
        col.table_name=in_table_name
        and col.table_schema=in_database
        and col.CONSTRAINT_NAME <> 'PRIMARY'
    GROUP BY col.TABLE_NAME,col.CONSTRAINT_NAME
) C
JOIN
information_schema.REFERENTIAL_CONSTRAINTS R
ON c.CONSTRAINT_NAME = R.CONSTRAINT_NAME
AND c.TABLE_NAME = R.TABLE_NAME
AND  R.CONSTRAINT_SCHEMA = in_database
) X
;


    RETURN strDEF;
END //