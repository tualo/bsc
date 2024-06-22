
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `ds_cloneformlabel`( 
    in in_table_name varchar(64), 
    out result tinyint,
    out msg varchar(255)
)
    MODIFIES SQL DATA
BEGIN

    insert into ds_column_list_label (table_name,column_name,language,label,position,xtype)
    select table_name,column_name,language,label,position,if(substring(xtype,1,9)='combobox_',concat('column_',substring(xtype,10,128)),'gridcolumn') xtype from ds_column_form_label where ds_column_form_label.table_name = in_table_name
    on duplicate key update label=values(label),position=values(position),xtype=values(xtype);

    SET msg = 'Done';
    SET result = 1;

END //