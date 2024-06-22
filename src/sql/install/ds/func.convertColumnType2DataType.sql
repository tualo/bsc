DELIMITER //
CREATE FUNCTION IF NOT EXISTS `convertColumnType2DataType`(in_type varchar(128)) RETURNS varchar(64) CHARSET utf8mb4 COLLATE utf8mb4_general_ci
    DETERMINISTIC
    COMMENT 'fix view column type'
BEGIN 
    IF (INSTR(in_type,'varchar')=1) THEN
        RETURN 'varchar';
    END IF;
    IF (INSTR(in_type,'bigint')=1) THEN
        RETURN 'bigint';
    END IF;
    IF (INSTR(in_type,'datetime')=1) THEN
        RETURN 'datetime';
    END IF;
    IF (INSTR(in_type,'time')=1) THEN
        RETURN 'time';
    END IF;
    IF (INSTR(in_type,'date')=1) THEN
        RETURN 'date';
    END IF;
    IF (INSTR(in_type,'timestamp')=1) THEN
        RETURN 'timestamp';
    END IF;

    
    
    IF (INSTR(in_type,'tinyint')=1) THEN
        RETURN 'tinyint';
    END IF;

    IF (INSTR(in_type,'smallint')=1) THEN
        RETURN 'smallint';
    END IF;

    IF (INSTR(in_type,'binary')=1) THEN
        RETURN 'binary';
    END IF;
    
    
    IF (INSTR(in_type,'decimal')=1) THEN
        RETURN 'decimal';
    END IF;
    IF (INSTR(in_type,'double')=1) THEN
        RETURN 'double';
    END IF;
    IF (INSTR(in_type,'float')=1) THEN
        RETURN 'float';
    END IF;
    

    IF (INSTR(in_type,'char')=1) THEN
        RETURN 'char';
    END IF;
    IF (INSTR(in_type,'text')=1) THEN
        RETURN 'text';
    END IF;
    
    IF (INSTR(in_type,'longtext')=1) THEN
        RETURN 'longtext';
    END IF;
    
    IF (INSTR(in_type,'int')=1) THEN
        IF in_type='int(1)' THEN
            RETURN 'tinyint';
        ELSEIF in_type='int(4)' THEN
            RETURN 'tinyint';
        ELSE
            RETURN 'int';
        END IF;
    END IF;

    RETURN in_type;
END //