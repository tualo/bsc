
DELIMITER //
CREATE FUNCTION IF NOT EXISTS `getBulkInsertSQL`(in_table_name varchar(128)
) RETURNS longtext CHARSET utf8mb4 COLLATE utf8mb4_general_ci
    DETERMINISTIC
BEGIN
    DECLARE write_table_name varchar(128);
    DECLARE fldd longtext;
    DECLARE flds longtext;
    DECLARE prim longtext;
    DECLARE result longtext;
    DECLARE in_onduplicatekeyupdate boolean default true;

    SELECT if(writetable is null or writetable = '',table_name,writetable) INTO write_table_name FROM ds WHERE table_name = in_table_name;

    SELECT 
        group_concat(
            concat(
                '', ds_column.column_name,''
            )
            SEPARATOR ', '
        )
        FLD_F,

        group_concat(
            concat(
                '{',in_table_name,'__',ds_column.column_name,'}'
            )
            SEPARATOR ', '
        )
        FLD_D
    INTO 
        fldd,
        flds
    FROM 
        ds_column
    WHERE 
        table_name = write_table_name;


    SELECT 
        group_concat(
            concat(
                ds_column.column_name,'=','(',ds_column.column_name,')'
            )
            SEPARATOR ', '
        )
        FLD_D
    INTO 
        prim
    FROM 
        ds_column
    WHERE 
        table_name = write_table_name
        and is_primary=1;




    SET result =concat( 
        'INSERT INTO `',write_table_name,'` ( ',fldd,' ) VALUES <bulk>(',flds,')</bulk>',
        if(in_onduplicatekeyupdate,concat('  ON DUPLICATE KEY UPDATE ',prim,''),'')
    );
    RETURN result;
END //