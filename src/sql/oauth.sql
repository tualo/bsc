delimiter ;

alter table SESSIONDB.oauth add column if not exists singleuse tinyint default 0;
alter table SESSIONDB.oauth add column if not exists name varchar(255) default uuid();
alter table SESSIONDB.oauth add column if not exists device varchar(255) default uuid();