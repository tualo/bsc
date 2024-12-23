delimiter ;
-- set foreign_key_checks=0;
-- alter table oauth modify id varchar(36);
-- alter table oauth add singleuse tinyint default 0;
-- alter table oauth_path modify id varchar(36);
-- alter table oauth_resources modify id varchar(36);
-- alter table oauth_resources_property modify id varchar(36);
-- set foreign_key_checks=1;
alter table oauth add if not exists singleuse tinyint default 0;
