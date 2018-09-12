

-- Simple debugging
DELIMITER // 

DROP TABLE IF EXISTS _debug; //

DROP PROCEDURE IF EXISTS DebugTable; //
CREATE PROCEDURE DebugTable() 
BEGIN
    CREATE TABLE IF NOT EXISTS _debug (
	`id` int(10) unsigned NOT NULL auto_increment,
	`msg1` TEXT DEFAULT NULL,
        `msg2` TEXT DEFAULT NULL,
	`row` int(10),
--	`created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
	PRIMARY KEY (`id`)
    ) STORAGE MEMORY;
END; //

DROP PROCEDURE IF EXISTS Debug; //
CREATE PROCEDURE Debug(Message1 TEXT, Message2 TEXT, Row INT)  
BEGIN
	CALL DebugTable();
	INSERT INTO _debug(`msg1`,`msg2`,`row`) VALUES(Message1,Message2,Row);
END; //

DROP PROCEDURE IF EXISTS ClearDebugMessages; //
CREATE PROCEDURE ClearDebugMessages() 
BEGIN
	CALL DebugTable();
	TRUNCATE TABLE _debug;
END; //
DELIMITER ;

