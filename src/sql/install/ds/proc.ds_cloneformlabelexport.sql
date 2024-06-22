DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `ds_cloneformlabelexport`( 
    in in_table_name varchar(64), 
    out result tinyint,
    out msg varchar(255)
)
    MODIFIES SQL DATA
BEGIN

    insert into ds_column_list_export (table_name,column_name,language,label,position)
    select table_name,column_name,language,label,position from ds_column_form_label where ds_column_form_label.table_name = in_table_name
    on duplicate key update label=values(label),position=values(position);

    SET msg = 'Done';
    SET result = 1;

END //