DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `fill_ds`( in use_table_name varchar(128) )
    MODIFIES SQL DATA
BEGIN


update ds set existsreal = 0 where (use_table_name=''  or table_name = use_table_name);

FOR record IN (select * from view_config_ds where (use_table_name=''  or table_name = use_table_name)  ) DO
    if @debug=1 then select record.table_name; end if;
    insert into ds (
        table_name,
        title,
        reorderfield,
        use_history,
        searchfield,
        displayfield,
        sortfield,
        searchany,
        hint,
        overview_tpl,
        sync_table,
        writetable,
        globalsearch,
        listselectionmodel,
        sync_view,
        syncable,
        cssstyle,
        alternativeformxtype,
        read_table,
        class_name,
        special_add_panel,
        existsreal,
        character_set_name,
        read_filter,
        listxtypeprefix,
        phpexporter,
        phpexporterfilename,
        combined,
        default_pagesize,
        allowForm,
        listviewbaseclass,
        showactionbtn
    )
    values
    (
        record.table_name,
        record.title,
        record.reorderfield,
        record.use_history,
        record.searchfield,
        record.displayfield,
        record.sortfield,
        record.searchany,
        record.hint,
        record.overview_tpl,
        record.sync_table,
        record.writetable,
        record.globalsearch,
        record.listselectionmodel,
        record.sync_view,
        record.syncable,
        record.cssstyle,
        record.alternativeformxtype,
        record.read_table,
        record.class_name,
        record.special_add_panel,
        1 ,
        record.character_set_name,
        record.read_filter,
        record.listxtypeprefix,
        record.phpexporter,
        record.phpexporterfilename,
        record.combined,
        record.default_pagesize,
        record.allowForm,
        record.listviewbaseclass,
        record.showactionbtn
    ) on duplicate key update table_name=values(table_name),existsreal=values(existsreal)
    ;

END FOR;

END //