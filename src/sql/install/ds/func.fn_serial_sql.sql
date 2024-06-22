DELIMITER //
CREATE FUNCTION IF NOT EXISTS `fn_serial_sql`(in_table_name varchar(128),in_column_name varchar(128)) RETURNS longtext CHARSET utf8mb4 COLLATE utf8mb4_general_ci
    DETERMINISTIC
BEGIN 
    DECLARE res LONGTEXT;
    select 
        concat( 'set @serial = (select ifnull(max(',column_name,'),',default_min_value-1,')+1 i from ',table_name,' where ',column_name,' between ',default_min_value,'-1 and ',default_max_value , ' having i <= ',default_max_value,');') x
    INTO res
    from ds_column where table_name=in_table_name and column_name=in_column_name;
    RETURN res;
END //