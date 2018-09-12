DELIMITER ;
select 'areacode.sql' as 'file';

-- Module:location

SELECT 'Loading US Area Code data';

create table if not exists `areacode` (
    `code`       VARCHAR(3)     NOT NULL,
    `state`      VARCHAR(31)    NOT NULL,
    `state_a`    VARCHAR(2)     NOT NULL
) ENGINE=MyISAM;


-- ===================================================================================
-- Look for a matching zip/post code in the database of US postal info
--
-- Returns an ordered, delimiter-separated record of associated info:
--
--  CountryCode(3-letter),Postcode,City,State,State-Abbreviation
--
-- -----------------------------------------------------------------------------------

DELIMITER //
DROP FUNCTION IF EXISTS lookup_areacode //
CREATE FUNCTION         lookup_areacode( code_s VARCHAR(6), delim VARCHAR(1))
  RETURNS VARCHAR(31)
  BEGIN
    DECLARE o        VARCHAR(1) DEFAULT delim;
    DECLARE code_r   VARCHAR(3);    -- 3-digit area code
    DECLARE state_r  VARCHAR(100);  -- State
    DECLARE state_ra VARCHAR(20);   -- State abbr.

    BEGIN
      SELECT
        `code`,
        `state`,
        `state_a`
      INTO code_r, state_r, state_ra
      FROM `location`.`areacode`
      WHERE `code`=code_s limit 1;
    END;

    RETURN CONCAT(code_r, o,state_r, o, state_ra);

  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS lookup_areacode_state //
CREATE FUNCTION         lookup_areacode_state( code_s VARCHAR(5) )
  RETURNS VARCHAR(31)
  BEGIN
    DECLARE state_r  VARCHAR(31) DEFAULT NULL;  -- State

    BEGIN
      SELECT
        `state`
      INTO state_r
      FROM `location`.`areacode`
      WHERE `code` LIKE LEFT(code_s,4)
      limit 1;
    END;

    RETURN state_r;

  END
//
DELIMITER ;
SHOW WARNINGS;

DELIMITER //
DROP FUNCTION IF EXISTS lookup_areacode_state_name //
CREATE FUNCTION         lookup_areacode_state_name( code_s VARCHAR(31) )
  RETURNS VARCHAR(15)
  BEGIN
    DECLARE state_r  VARCHAR(15) DEFAULT NULL;   -- State

    BEGIN
      SELECT
        `state`
      INTO state_r
      FROM `location`.`areacode`
      WHERE (`state_a` LIKE concat('%',code_s,'%')) OR (`state` LIKE concat('%',code_s,'%'))
      limit 1;
    END;

    RETURN state_r;

  END
//
DELIMITER ;
SHOW WARNINGS;

DELIMITER //
DROP FUNCTION IF EXISTS lookup_areacode_state_name2 //
CREATE FUNCTION         lookup_areacode_state_name2( state_s VARCHAR(31) )
  RETURNS VARCHAR(2)
  BEGIN
    DECLARE state_r  VARCHAR(2) DEFAULT NULL;   -- State

    BEGIN
      SELECT
        `state_a`
      INTO state_r
      FROM `location`.`areacode`
      WHERE (`state_a` LIKE concat('%',state_s,'%')) OR (`state` LIKE concat('%',state_s,'%'))
      limit 1;
    END;

    RETURN state_r;

  END
//
DELIMITER ;
SHOW WARNINGS;

TRUNCATE `location`.`areacode`;

LOAD DATA LOCAL INFILE 'data/US/areacode.csv'
REPLACE INTO TABLE `location`.`areacode`
fields terminated by ","
optionally enclosed by '"'
(@a,@b,@c)
SET
`code` = LEFT(@a,3),
`state` = REPLACE(@b,'"',''),
`state_a` = LEFT(@c,2);



SELECT CONCAT( 'Your default area code is: ',
                IF(@DEFAULT_AREACODE IS NULL, 'Not set!',lookup_areacode(IFNULL(@DEFAULT_AREACODE,'907'),' ')))
                as locale;
