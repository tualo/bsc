DELIMITER //
CREATE FUNCTION IF NOT EXISTS `getColumnSearchJoin`(in_queryid varchar(36)
) RETURNS longtext CHARSET utf8mb4 COLLATE utf8mb4_general_ci
    DETERMINISTIC
BEGIN
    DECLARE result longtext;
    
    DECLARE in_table_name varchar(64);
    DECLARE in_read_table_name varchar(64);
    DECLARE primarykey_txt longtext;
    DECLARE primarykey_txt_prefixed longtext;
    DECLARE primarykey_txt_prefixed2 longtext;

    IF @searchquery is not null THEN 
        SELECT ds_query.table_name,if(ds.read_table is null or ds.read_table='',ds.table_name,ds.read_table) rt INTO in_table_name,in_read_table_name 
        FROM ds_query join ds on ds_query.table_name = ds.table_name
        WHERE queryid = in_queryid;
        IF in_table_name is null THEN
            SET in_table_name = in_queryid;
        END IF;

        select 
            group_concat(
                FIELDQUOTE(ds_column.column_name) order by ds_column.column_name
                SEPARATOR  ', '
            ),
            group_concat(
                concat('`',ds_column.table_name,'`.`',ds_column.column_name,'`') order by ds_column.column_name
                SEPARATOR  ', '
            ),
            group_concat(
                concat('`_searchjoin`.`',ds_column.column_name,'`') order by ds_column.column_name
                SEPARATOR  ', '
            )
        into 
            primarykey_txt,
            primarykey_txt_prefixed,
            primarykey_txt_prefixed2
        from 
            ds_column
        where 
            ds_column.table_name = in_table_name
            and ds_column.existsreal = 1
            and ds_column.is_primary = 1
        ;
        
        select
            concat(' LEFT JOIN  (select ',primarykey_txt,',sum(__searchscore) __searchscore from ( ',s,' ) c group by  ',primarykey_txt,' order by __searchscore desc) _searchjoin on  (',primarykey_txt_prefixed ,') = (',primarykey_txt_prefixed2 ,')  ')
        INTO result

        FROM 
        (
            

            SELECT 

                group_concat( sx  separator ' union ' ) S

            FROM (
                SELECT

                    
                        concat( 

                            concat('select ',primarykey_txt,', MATCH(',FIELDQUOTE(column_name),') against (',QUOTE(@searchquery),' in boolean mode) __searchscore from ',
                            FIELDQUOTE(in_table_name),
                            ' WHERE MATCH(',FIELDQUOTE(column_name),') against (',QUOTE(@searchquery),' in boolean mode)  '),' union ',
                            concat( 'select ',primarykey_txt,', 0.01 __searchscore from ', FIELDQUOTE(in_table_name) ,' where ',FIELDQUOTE(column_name),' like ',QUOTE(concat('%',@searchquery,'%') ),'' )
                        ) sx
                    
                FROM 
                    ds_searchfields
                WHERE ds_searchfields.active = 1 and ds_searchfields.table_name = in_table_name

                UNION

                select 
                concat( 'select ',primarykey_txt,', 0.02 __searchscore from ', FIELDQUOTE(in_read_table_name) ,' where ',FIELDQUOTE(ds.searchfield),' like ',QUOTE(concat('%',@searchquery,'%') ),'' ) sx
                FROM ds
                WHERE 
                    ds.table_name = in_table_name
            ) UX 
        ) x
    ;
    END IF;
    IF result is null THEN
        SET result = ' ';
    END IF;
	return result;
END //