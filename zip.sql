DELIMITER ;
select 'zip.sql' as 'file';

-- Module:location

SELECT 'Loading Zipcode data WITHOUT spatial attributes';

create table if not exists `location`.`zip` (
    `country2`  VARCHAR(3) NOT NULL,
    `post`      VARCHAR(20) NOT NULL,
    `place`     VARCHAR(180) NOT NULL,
    `name1`     VARCHAR(100) NOT NULL,
    `code1`     VARCHAR(20) NOT NULL,
    `name2`     VARCHAR(100) NOT NULL,
    `code2`     VARCHAR(20) NOT NULL,
    `name3`     VARCHAR(100) NOT NULL,
    `code3`     VARCHAR(20) NOT NULL
) ENGINE=MyISAM;


TRUNCATE `location`.`zip`;

-- Load zip data WITHOUT spatial attributes
LOAD DATA LOCAL INFILE 'data/US/zip.txt'
REPLACE INTO TABLE `location`.`zip`
fields terminated by "\t"
ignore 1 lines
 (@a,@b,@c,@d,@e,@f,@g,@h,@i)
SET
    `country2` = @a,
    `post` = @b,
    `place` = @c,
    `name1` = @d,
    `code1` = @e,
    `name2` = @f,
    `code2` = @g,
    `name3` = @h,
    `code3` = @i;

-- Use this one for spatial data
-- 
-- create table if not exists `zip` (
--     `country2`  VARCHAR(3) NOT NULL,
--     `post`      VARCHAR(20) NOT NULL,
--     `place`     VARCHAR(180) NOT NULL,
--     `name1`     VARCHAR(100) NOT NULL,
--     `code1`     VARCHAR(20) NOT NULL,
--     `name2`     VARCHAR(100) NOT NULL,
--     `code2`     VARCHAR(20) NOT NULL,
--     `name3`     VARCHAR(100) NOT NULL,
--     `code3`     VARCHAR(20) NOT NULL,
--     `lat`       FLOAT(7,4) NOT NULL,
--     `lon`       FLOAT(7,4) NOT NULL,
--     `acc`       TINYINT NOT NULL,
--     `g`         GEOMETRY NOT NULL,
--     SPATIAL INDEX (g)
-- ) ENGINE=MyISAM;


-- Load Zip data WITH spatial attributes
-- LOAD DATA LOCAL INFILE 'data/US/zip.txt'
-- REPLACE INTO TABLE `location`.`zip`
-- fields terminated by "\t"
-- ignore 1 lines
--  (@a,@b,@c,@d,@e,@f,@g,@h,@i,@j,@k,@l)
-- SET
--     `country2` = @a,
--     `post` = @b,
--     `place` = @c,
--     `name1` = @d,
--     `code1` = @e,
--     `name2` = @f,
--     `code2` = @g,
--     `name3` = @h,
--     `code3` = @i,
--     `lat` = @j,
--     `lon` = @k,
--     `acc` = @l,
--     `g` = ST_PointFromGeoHash( ST_GeoHash(@k+0.0, @j+0.0 ,10 ),4326);



-- ===================================================================================
-- Look for a matching zip/post code in the database of US postal info
--
-- Returns an ordered, delimiter-separated record of associated info:
--
--  CountryCode(3-letter),Postcode,City,State,State-Abbreviation
--
-- -----------------------------------------------------------------------------------

DELIMITER //
DROP FUNCTION IF EXISTS lookup_zip //
CREATE FUNCTION         lookup_zip(zip VARCHAR(20), delim VARCHAR(1))
  RETURNS VARCHAR(255)
  BEGIN
    DECLARE o           VARCHAR(1)      DEFAULT delim;
    DECLARE country2_r  VARCHAR(2)      DEFAULT NULL; -- Country-2 code
    DECLARE zip_r       VARCHAR(20)     DEFAULT NULL; -- Zip
    DECLARE city_r      VARCHAR(180)    DEFAULT NULL; -- City
    DECLARE state_r     VARCHAR(100)    DEFAULT NULL; -- State
    DECLARE state_ra    VARCHAR(20)     DEFAULT NULL; -- State abbr.

    IF ( zip IS NULL OR zip ='' ) THEN
        RETURN NULL;
    END IF;

    BEGIN
      SELECT
        `country2`,
        `post`,
        `place`,
        `name1`,
        `code1`
      INTO country2_r, zip_r, city_r, state_r, state_ra
      FROM `location`.`zip`
      WHERE `post` LIKE LEFT(zip,5) limit 1;
    END;

    RETURN CONCAT(country2_r, o, zip_r, o, city_r, o, state_r, o, state_ra);

  END
//
DELIMITER ;
SHOW WARNINGS;


-- ===================================================================================
-- Lookup state 2-letter shortcode, using state name
-- NULL, if not state found
-- -----------------------------------------------------------------------------------

DELIMITER //
DROP FUNCTION IF EXISTS lookup_state_state_a //
CREATE FUNCTION         lookup_state_state_a( state_s VARCHAR(127) )
  RETURNS VARCHAR(2)
  BEGIN
    DECLARE state_ra VARCHAR(2) DEFAULT NULL; -- State abbr.

    BEGIN
      SELECT
        `code1`
      INTO state_ra
      FROM `location`.`zip`
      WHERE `name1` LIKE state_s limit 1;
    END;

    RETURN state_ra;
  END
//
DELIMITER ;
SHOW WARNINGS;


-- ===================================================================================
-- Lookup state 2-letter shortcode, using zipcode
-- NULL, if not state found
-- -----------------------------------------------------------------------------------

DELIMITER //
DROP FUNCTION IF EXISTS lookup_zip_state_a //
CREATE FUNCTION         lookup_zip_state_a( zip_s VARCHAR(15) )
  RETURNS VARCHAR(2)
  BEGIN
    DECLARE state_ra VARCHAR(2) DEFAULT NULL; -- State abbr.

    BEGIN
      SELECT
        `code1`
      INTO state_ra
      FROM `location`.`zip`
      WHERE `post` LIKE zip_s limit 1;
    END;

    RETURN state_ra;
  END
//
DELIMITER ;
SHOW WARNINGS;



-- ===================================================================================
-- Lookup state name shortcode, using zipcode
-- NULL, if not state found
-- -----------------------------------------------------------------------------------

DELIMITER //
DROP FUNCTION IF EXISTS lookup_zip_state //
CREATE FUNCTION         lookup_zip_state( zip_s VARCHAR(15) )
  RETURNS VARCHAR(31)
  BEGIN
    DECLARE state_r VARCHAR(31) DEFAULT NULL; -- State abbr.

    BEGIN
      SELECT
        `name1`
      INTO state_r
      FROM `location`.`zip`
      WHERE `post` LIKE LEFT(zip_s,5)
      limit 1;
    END;

    RETURN state_r;
  END
//
DELIMITER ;
SHOW WARNINGS;


SELECT CONCAT( 'Your default postal code is: ',
                lookup_zip( IFNULL(@DEFAULT_POSTCODE,'99676'), ' '))
                as 'locale';