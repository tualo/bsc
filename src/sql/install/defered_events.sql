CREATE OR REPLACE PROCEDURE `proc_deferred_sql_tasks`()
    MODIFIES SQL DATA
BEGIN
    SET @sql=concat("set @rem_sessionuser=@sessionuser");
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    FOR rec in (
    	select * from deferred_sql_tasks WHERE state=0 
		-- and hostname=@@hostname
		order by createtime asc
    ) DO
    	update deferred_sql_tasks set state=-1 where taskid=rec.taskid;
        
        SET @sql=concat("set @sessionuser='",rec.sessionuser,"'");
		PREPARE stmt FROM @sql;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;

		SET @sql = rec.sqlstatement;
		PREPARE stmt FROM @sql;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
    
        update deferred_sql_tasks set state=1 where taskid=rec.taskid;
        
    END FOR;


    SET @sql=concat("set @sessionuser=@rem_sessionuser");
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END //

CREATE TABLE IF NOT EXISTS `deferred_sql_tasks` (
  `taskid` varchar(36) NOT NULL,
  `sessionuser` varchar(255) NOT NULL,
  `state` tinyint(4) DEFAULT 0,
  `createtime` datetime DEFAULT current_timestamp(),
  `sqlstatement` longtext DEFAULT NULL,
  `hostname` varchar(255) NOT NULL,
  PRIMARY KEY (`taskid`)
) //

CREATE TABLE `deferred_sql_tasks_log` (
  `taskid` varchar(36) NOT NULL,
  `startime` datetime DEFAULT NULL,
  `endtime` datetime DEFAULT NULL,
  PRIMARY KEY (`taskid`),
  CONSTRAINT `fk_deferred_sql_tasks_id` FOREIGN KEY (`taskid`) REFERENCES `deferred_sql_tasks` (`taskid`)
) //

CREATE OR REPLACE EVENT `event_deferred_sql_tasks` ON SCHEDULE EVERY 1 SECOND STARTS '2023-01-01 00:00:00' ON COMPLETION NOT PRESERVE DISABLE ON SLAVE DO BEGIN
	FOR rec in (
    	select * from deferred_sql_tasks WHERE state=0 
		-- and hostname=@@hostname
		order by createtime asc
    ) DO
    	update deferred_sql_tasks set state=-1 where taskid=rec.taskid;
        
        SET @sql=concat("set @sessionuser='",rec.sessionuser,"'");
		PREPARE stmt FROM @sql;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;

		SET @sql = rec.sqlstatement;
		PREPARE stmt FROM @sql;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
    
        update deferred_sql_tasks set state=1 where taskid=rec.taskid;
        
    END FOR;
END //