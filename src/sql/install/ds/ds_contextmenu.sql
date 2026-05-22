DELIMITER ;

CREATE TABLE IF NOT EXISTS `ds_contextmenu` (
  `table_name` varchar(128) NOT NULL,
  `name` varchar(100) NOT NULL DEFAULT '',
  `component` varchar(255) NOT NULL,
  `paramfield` varchar(255) NOT NULL,
  `position` int(11) DEFAULT 0,
  PRIMARY KEY (`table_name`,`name`),
  CONSTRAINT `fk_ds_ctx_ds` FOREIGN KEY (`table_name`) REFERENCES `ds` (`table_name`) ON DELETE CASCADE ON UPDATE CASCADE
);

alter table ds_contextmenu add column if not exists `icon` varchar(255) default null;
alter table ds_contextmenu add column if not exists `route` varchar(255) default null;
alter table ds_contextmenu add column if not exists `target` varchar(20) default null;


create or replace view `view_ds_contextmenu` as

select
 ds.table_name,
 ds_contextmenu.position,
  ifnull(
    JSON_ARRAYAGG(
      JSON_OBJECT(
      'name', ds_contextmenu.name,
      'route', ds_contextmenu.route,
      'icon', ds_contextmenu.icon,
      'target', ds_contextmenu.target
    )
    ORDER BY ds_contextmenu.position
    ), 
  JSON_ARRAY()) contextmenu
from
  ds 
  left join
    ds_contextmenu
    on ds.table_name=ds_contextmenu.table_name
    and ds_contextmenu.route<>''
    and ds_contextmenu.route is not null
where 
    ds_contextmenu.position is not null 
group by
 ds_contextmenu.position,
 ds.table_name;