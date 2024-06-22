DELIMITER //
CREATE FUNCTION IF NOT EXISTS `getTableKeys`(in_database varchar(64), in_table_name varchar(64) ) RETURNS longtext CHARSET utf8mb4 COLLATE utf8mb4_general_ci
    READS SQL DATA
BEGIN
    DECLARE strDEF longtext;

    SELECT 
        group_concat(
            A.x
            SEPARATOR ',
            '
        )
        INTO strDEF
    FROM (
    SELECT
        
concat(
IF (NON_UNIQUE = 1,'' ,' UNIQUE '),
' KEY ',
' `',INDEX_NAME,'`',
' (',
group_concat(
    concat('`',COLUMN_NAME,'`')
    ORDER BY SEQ_IN_INDEX
    SEPARATOR ','
),
') '

) x
        

    FROM
        INFORMATION_SCHEMA.STATISTICS
    WHERE
        TABLE_SCHEMA = in_database
        and TABLE_NAME = in_table_name
        and INDEX_NAME <> 'PRIMARY'

    GROUP BY INDEX_NAME
    ) A;


    RETURN strDEF;
END //