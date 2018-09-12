-- Module:utility
DELIMITER ;
source global.sql;
select 'utility.sql' as 'file';
create database if not exists `utility`;
use `utility`;


DELIMITER //
DROP PROCEDURE IF EXISTS strlist_numsort //
CREATE PROCEDURE         strlist_numsort(  INOUT list TEXT, dir VARCHAR(4), delim VARCHAR(1) )
  BEGIN
    DECLARE o   VARCHAR(1) DEFAULT delim;                    -- output delimeter
    DECLARE val INT;
    DECLARE l   INT;
    DECLARE i   INT DEFAULT 0;

    
    CREATE TEMPORARY TABLE IF NOT EXISTS strlist_numsort_temp (
        `num`           INT(4) NOT NULL
    ) ENGINE = MEMORY;

    TRUNCATE `strlist_numsort_temp`;

    SET l = listlen(list,o);

    WHILE ( i < l )  DO
        SET i = i + 1;
        SET val = SUBSTRING_INDEX(SUBSTRING_INDEX(list,o,i),o,-1)+0;
        INSERT INTO `strlist_numsort_temp` (`num`) VALUE (val);
    END WHILE;

    IF ( dir like 'asc' ) THEN
        SELECT group_concat(`num` order by `num` asc separator ',') INTO list FROM `strlist_numsort_temp`;
    ELSE
        SELECT group_concat(`num` order by `num` desc separator ',') INTO list FROM `strlist_numsort_temp`;
    END IF;
  END;
//
DELIMITER ;
-- SHOW WARNINGS;

DELIMITER //
DROP PROCEDURE IF EXISTS strlist_setify //
CREATE PROCEDURE         strlist_setify(  INOUT list TEXT, OUT elements SMALLINT, delim VARCHAR(1) )
  BEGIN
    DECLARE o   VARCHAR(1) DEFAULT delim;                    -- output delimeter
    DECLARE acc,alt VARCHAR(255) DEFAULT '';
    DECLARE val VARCHAR(63);
    DECLARE l   SMALLINT;
    DECLARE i,n SMALLINT DEFAULT 0;

    SET l = listlen(list,o);

    WHILE ( i < l )  DO
        SET i = i + 1;
        SET val = SUBSTRING_INDEX(SUBSTRING_INDEX(list,o,i),o,-1);
        IF ( NOT FIND_IN_SET(val,acc)) THEN
            SET acc = CONCAT(acc,val,',');
            IF ( delim != ',') THEN
                SET alt = CONCAT(alt,val,'o');
            END IF;
            SET n = n + 1;
        END IF;
    END WHILE;

    SET elements=n;

    IF ( delim = ',') THEN
        SET list = chop_last(',',acc);
    ELSE
        SET list = chop_last(o,alt);
    END IF;
        
  END;
//
DELIMITER ;
-- SHOW WARNINGS;




-- Length of a character-delimited list
-- Does not count spurious leading/trailing values
--
DELIMITER //
DROP FUNCTION IF EXISTS listlen //
CREATE FUNCTION listlen(list TEXT, delim VARCHAR(1) )
  RETURNS INT
  BEGIN
    DECLARE o   VARCHAR(1)  DEFAULT delim;
    DECLARE l   INT         DEFAULT countdelim(o,list);

    RETURN IFNULL(l+1,0);

  END;
//
DELIMITER ;
-- SHOW WARNINGS;



-- Length of a character-delimited list
-- counting non-blank (word-like) values
--
DELIMITER //
DROP FUNCTION IF EXISTS listlenw //
CREATE FUNCTION listlenw(list TEXT, delim VARCHAR(1) )
  RETURNS INT
  BEGIN
    DECLARE o   VARCHAR(1)  DEFAULT delim;
    DECLARE n   INT         DEFAULT listlen(list,o);
    DECLARE i   INT         DEFAULT 0;
    DECLARE results INT     DEFAULT 0;
    DECLARE val TEXT;

    WHILE ( i < n )  DO
        SET i = i + 1;
        SET val = SUBSTRING_INDEX(SUBSTRING_INDEX(list,o,i),o,-1);
        IF ( val NOT RLIKE '^[[:blank:]]$' AND LENGTH(val) > 0 ) THEN
            SET results = results + 1;
        END IF;
    END WHILE;

    RETURN results;

  END;
//
DELIMITER ;
-- SHOW WARNINGS;



-- Longest (last) value in a character-delimited list
-- Does not count spurious leading/trailing values
--
DELIMITER //
DROP FUNCTION IF EXISTS longest //
CREATE FUNCTION longest(list TEXT, delim VARCHAR(1) )
  RETURNS TEXT
  BEGIN
    DECLARE o       VARCHAR(1)  DEFAULT delim;
    DECLARE i       INT         DEFAULT 0;
    DECLARE n       INT         DEFAULT listlen(list,o);
    DECLARE val,
            longer  TEXT        DEFAULT '';
    DECLARE len     INT         DEFAULT -1;
    DECLARE l       INT;

      WHILE ( i < n ) DO
        SET i = i + 1;
        SET val = SUBSTRING_INDEX(SUBSTRING_INDEX(list,o,i),o,-1);
        SET l = LENGTH(val);
        IF ( l>len ) THEN
            SET longer = val;
            SET len = l;
        END IF;
      END WHILE;

    RETURN longer;

  END;
//
DELIMITER ;
-- SHOW WARNINGS;


-- Shortest (last) value in a character-delimited list
-- Does not count spurious leading/trailing values
--
DELIMITER //
DROP FUNCTION IF EXISTS shortest //
CREATE FUNCTION shortest(list TEXT, delim VARCHAR(1) )
RETURNS TEXT
BEGIN
    DECLARE o       VARCHAR(1)  DEFAULT delim;
    DECLARE i       INT         DEFAULT 0;
    DECLARE n       INT         DEFAULT listlen(list,o);
    DECLARE val,
            shorter  TEXT       DEFAULT '';
    DECLARE len     INT         DEFAULT 2147483647;
    DECLARE l       INT;

      WHILE ( i < n ) DO
        SET i = i + 1;
        SET val = SUBSTRING_INDEX(SUBSTRING_INDEX(list,o,i),o,-1);
        SET l = LENGTH(val);
        IF ( l<len ) THEN
            SET shorter = val;
            SET len = l;
        END IF;
      END WHILE;

    RETURN shorter;

END;
//
DELIMITER ;
-- SHOW WARNINGS;



-- ======================================================
--   Return a value - longest, non-null, non-blank
--   value from string source, if old value is blank,
--   null or shorter.
-- ------------------------------------------------------
DELIMITER //
DROP FUNCTION IF EXISTS merge_value_str_longest //
CREATE FUNCTION merge_value_str_longest( old_v TEXT, new_v TEXT, default_value VARCHAR(255) )
RETURNS TEXT
BEGIN
    IF ( old_v IS NULL OR old_v ='' ) THEN
        IF ( new_v IS NULL OR new_v = '') THEN
            RETURN default_value;
        ELSE
            RETURN new_v;
        END IF;
    ELSE
        IF ( new_v IS NULL OR new_v = '' ) THEN  -- both values are set...
                RETURN old_v;
        ELSE
            IF ( LENGTH(new_v) > LENGTH( old_v )) THEN
                RETURN new_v;
            ELSE
                RETURN old_v;
            END IF;
        END IF;
    END IF;

    RETURN old_v;

END; //
DELIMITER ;
-- SHOW WARNINGS;


-- ======================================================
--   Return a value - longest, non-null, non-blank
--   value from string source, if old value is blank,
--   null or shorter.
-- ------------------------------------------------------
DELIMITER //
DROP FUNCTION IF EXISTS merge_value_str_shortest //
CREATE FUNCTION merge_value_str_shortest( old_v TEXT, new_v TEXT, default_value VARCHAR(255) )
RETURNS TEXT
BEGIN
    IF ( old_v IS NULL OR old_v ='' ) THEN
        IF ( new_v IS NULL OR new_v = '') THEN
            RETURN default_value;
        ELSE
            RETURN new_v;
        END IF;
    ELSE
        IF ( new_v IS NULL OR new_v = '' ) THEN  -- both values are set...
                RETURN old_v;
        ELSE
            IF ( LENGTH(new_v) < LENGTH( old_v )) THEN
                RETURN new_v;
            ELSE
                RETURN old_v;
            END IF;
        END IF;
    END IF;

END; //
DELIMITER ;
-- SHOW WARNINGS;



-- ======================================================
--   Return a value - longest, non-null, non-blank
--   value from string source, if old value is blank,
--   null. If both are blank or null, return default.
-- ------------------------------------------------------
DELIMITER //
DROP FUNCTION IF EXISTS merge_value_str //
CREATE FUNCTION merge_value_str( old_v TEXT, new_v TEXT, default_value TEXT )
RETURNS TEXT
BEGIN
    IF ( old_v IS NULL OR old_v ='' ) THEN
        IF ( new_v IS NULL OR new_v = '') THEN
            RETURN default_value;
        ELSE
            RETURN new_v;
        END IF;
    ELSE
        RETURN old_v;
    END IF;

END; //
DELIMITER ;
-- SHOW WARNINGS;


-- ======================================================
--   Return a value - non-null, non-blank
--   value from string source - if old value is blank,
--   null. If both are blank or null, return default.
-- ------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS merge_value_str //
CREATE PROCEDURE merge_value_str( INOUT old_v TEXT, IN new_v TEXT, IN default_value TEXT )
BEGIN

    SET old_v = utility.merge_value_str(old_v, new_v, default_value );

END; //
DELIMITER ;
-- SHOW WARNINGS;


-- ======================================================
--   Return a value - longest (last), non-null, non-blank
--   value from "list" source, if old value is blank,
--   null or shorter.
-- ------------------------------------------------------
DELIMITER //
DROP FUNCTION IF EXISTS merge_value_strlist //
CREATE FUNCTION merge_value_strlist( old_v TEXT, new_values TEXT, default_value VARCHAR(255), delim VARCHAR(1) )
RETURNS TEXT
BEGIN
    DECLARE o       VARCHAR(1)      DEFAULT delim;

    RETURN merge_value_str_longest( old_v, longest(new_values,o), default_value );

END; //
DELIMITER ;
-- SHOW WARNINGS;


-- ======================================================
--   Return a concatenated lists of elements.
-- ------------------------------------------------------
DELIMITER //
DROP FUNCTION IF EXISTS merge_strlist //
CREATE FUNCTION merge_strlist( list TEXT, elements TEXT, delim VARCHAR(1) )
RETURNS TEXT
BEGIN
    DECLARE o       VARCHAR(1)  DEFAULT delim;
    DECLARE i       INT         DEFAULT 0;
    DECLARE n       INT         DEFAULT listlen(elements,o);

    WHILE ( i<n ) DO
        SET i = i + 1;
        SET list = CONCAT(list,o, SUBSTRING_INDEX(SUBSTRING_INDEX(elements,o,i),o,-1));
    END WHILE;

    RETURN list;

END; //
DELIMITER ;
-- SHOW WARNINGS;




-- ======================================================
--   Capitaize words -
--
--   (lifted from net search)
-- ------------------------------------------------------

DELIMITER //
DROP FUNCTION IF EXISTS cap1 //
CREATE FUNCTION         cap1(input_s TEXT)
  RETURNS TEXT
  BEGIN
    DECLARE len INT DEFAULT CHAR_LENGTH(input_s);
    DECLARE i INT DEFAULT 0;
    DECLARE cap_after CHAR(4) DEFAULT " -";

    SET input_s = LOWER(input_s);

    WHILE (i < len) DO
      IF ( i=0 OR LOCATE( MID(input_s, i, 1), cap_after) )
      THEN
        IF (i < len)
        THEN
          SET input_s = CONCAT(
              LEFT(input_s, i),
              UPPER(MID(input_s, i + 1, 1)),
              RIGHT(input_s, len - i - 1)
          );
        END IF;
      END IF;
      SET i = i + 1;
    END WHILE;

    RETURN input_s;

  END;
//
DELIMITER ;
-- SHOW WARNINGS;


-- ======================================================
--   Capitaize words -
--   Modified to capitalize after "'", as in O'Brien
--
--   (lifted from net search)
-- ------------------------------------------------------

DELIMITER //
DROP FUNCTION IF EXISTS cap1name //
CREATE FUNCTION         cap1name(input_s TEXT)
  RETURNS TEXT
  BEGIN
    DECLARE len INT DEFAULT CHAR_LENGTH(input_s);
    DECLARE i INT DEFAULT 0;
    DECLARE cap_after CHAR(4) DEFAULT " -'";

    SET input_s = LOWER(input_s);

    WHILE (i < len) DO
      IF ( i=0 OR LOCATE( MID(input_s, i, 1), cap_after) )
      THEN
        IF (i < len)
        THEN
          SET input_s = CONCAT(
              LEFT(input_s, i),
              UPPER(MID(input_s, i + 1, 1)),
              RIGHT(input_s, len - i - 1)
          );
        END IF;
      END IF;
      SET i = i + 1;
    END WHILE;

    RETURN input_s;

  END;
//
DELIMITER ;
-- SHOW WARNINGS;



-- Filters punctuations EXCEPT "skip's"
DELIMITER //
DROP FUNCTION IF EXISTS strippunc //
CREATE FUNCTION strippunc(skip VARCHAR(31), str TEXT)
  RETURNS TEXT
  BEGIN
    IF (NOT LOCATE(' ', skip))
    THEN SET str = REPLACE(str, ' ', ''); END IF;
    IF (NOT LOCATE('-', skip))
    THEN SET str = REPLACE(str, '-', ''); END IF;
    IF (NOT LOCATE('_', skip))
    THEN SET str = REPLACE(str, '_', ''); END IF;
    IF (NOT LOCATE('+', skip))
    THEN SET str = REPLACE(str, '+', ''); END IF;
    IF (NOT LOCATE('!', skip))
    THEN SET str = REPLACE(str, '!', ''); END IF;
    IF (NOT LOCATE('#', skip))
    THEN SET str = REPLACE(str, '#', ''); END IF;
    IF (NOT LOCATE('$', skip))
    THEN SET str = REPLACE(str, '$', ''); END IF;
    IF (NOT LOCATE('&', skip))
    THEN SET str = REPLACE(str, '&', ''); END IF;
    IF (NOT LOCATE("'", skip))
    THEN SET str = REPLACE(str, "'", ''); END IF;
    IF (NOT LOCATE('`', skip))
    THEN SET str = REPLACE(str, '`', ''); END IF;
    IF (NOT LOCATE('.', skip))
    THEN SET str = REPLACE(str, '.', ''); END IF;
    IF (NOT LOCATE('/', skip))
    THEN SET str = REPLACE(str, '/', ''); END IF;
    IF (NOT LOCATE('=', skip))
    THEN SET str = REPLACE(str, '=', ''); END IF;
    IF (NOT LOCATE('?', skip))
    THEN SET str = REPLACE(str, '?', ''); END IF;
    IF (NOT LOCATE('{', skip))
    THEN SET str = REPLACE(str, '}', ''); END IF;
    IF (NOT LOCATE('}', skip))
    THEN SET str = REPLACE(str, '}', ''); END IF;
    IF (NOT LOCATE(',', skip))
    THEN SET str = REPLACE(str, ',', ''); END IF;
    IF (NOT LOCATE('|', skip))
    THEN SET str = REPLACE(str, '|', ''); END IF;
    IF (NOT LOCATE('~', skip))
    THEN SET str = REPLACE(str, '~', ''); END IF;
    IF (NOT LOCATE('@', skip))
    THEN SET str = REPLACE(str, '@', ''); END IF;
    IF (NOT LOCATE('(', skip))
    THEN SET str = REPLACE(str, '(', ''); END IF;
    IF (NOT LOCATE(')', skip))
    THEN SET str = REPLACE(str, ')', ''); END IF;
    IF (NOT LOCATE('*', skip))
    THEN SET str = REPLACE(str, '*', ''); END IF;
    IF (NOT LOCATE('%', skip))
    THEN SET str = REPLACE(str, '%', ''); END IF;
    IF (NOT LOCATE('[', skip))
    THEN SET str = REPLACE(str, '[', ''); END IF;
    IF (NOT LOCATE(']', skip))
    THEN SET str = REPLACE(str, ']', ''); END IF;
    IF (NOT LOCATE(':', skip))
    THEN SET str = REPLACE(str, ':', ''); END IF;
    IF (NOT LOCATE(';', skip))
    THEN SET str = REPLACE(str, ';', ''); END IF;
    IF (NOT LOCATE('"', skip))
    THEN SET str = REPLACE(str, '"', ''); END IF;
    IF (NOT LOCATE('<', skip))
    THEN SET str = REPLACE(str, '<', ''); END IF;
    IF (NOT LOCATE('>', skip))
    THEN SET str = REPLACE(str, '>', ''); END IF;
    IF (NOT LOCATE('\\', skip))
    THEN SET str = REPLACE(str, '\\', ''); END IF;

    RETURN str;
  END;
//
DELIMITER ;
-- SHOW WARNINGS;

-- Filters numerals EXCEPT "skip's"
DELIMITER //
DROP FUNCTION IF EXISTS stripnum //
CREATE FUNCTION stripnum(skip VARCHAR(15), str TEXT)
  RETURNS TEXT
  BEGIN

    IF (NOT LOCATE('0', skip))
    THEN SET str = REPLACE(str, '0', ''); END IF;
    IF (NOT LOCATE('1', skip))
    THEN SET str = REPLACE(str, '1', ''); END IF;
    IF (NOT LOCATE('2', skip))
    THEN SET str = REPLACE(str, '2', ''); END IF;
    IF (NOT LOCATE('3', skip))
    THEN SET str = REPLACE(str, '3', ''); END IF;
    IF (NOT LOCATE('4', skip))
    THEN SET str = REPLACE(str, '4', ''); END IF;
    IF (NOT LOCATE('5', skip))
    THEN SET str = REPLACE(str, '5', ''); END IF;
    IF (NOT LOCATE('6', skip))
    THEN SET str = REPLACE(str, '6', ''); END IF;
    IF (NOT LOCATE('7', skip))
    THEN SET str = REPLACE(str, '7', ''); END IF;
    IF (NOT LOCATE('8', skip))
    THEN SET str = REPLACE(str, '8', ''); END IF;
    IF (NOT LOCATE('9', skip))
    THEN SET str = REPLACE(str, '9', ''); END IF;

    RETURN str;
  END;
//
DELIMITER ;
-- SHOW WARNINGS;

-- Filters alpha + punctuation EXCEPT allowed "skip's"
DELIMITER //
DROP FUNCTION IF EXISTS stripalpha //
CREATE FUNCTION stripalpha(skip VARCHAR(31), str TEXT)
  RETURNS TEXT
  BEGIN
    SET str = strippunc(skip, str);

    SET str = REPLACE(str, 'a', '');
    SET str = REPLACE(str, 'b', '');
    SET str = REPLACE(str, 'c', '');
    SET str = REPLACE(str, 'd', '');
    SET str = REPLACE(str, 'e', '');
    SET str = REPLACE(str, 'f', '');
    SET str = REPLACE(str, 'g', '');
    SET str = REPLACE(str, 'h', '');
    SET str = REPLACE(str, 'i', '');
    SET str = REPLACE(str, 'j', '');
    SET str = REPLACE(str, 'k', '');
    SET str = REPLACE(str, 'l', '');
    SET str = REPLACE(str, 'm', '');
    SET str = REPLACE(str, 'n', '');
    SET str = REPLACE(str, 'o', '');
    SET str = REPLACE(str, 'p', '');
    SET str = REPLACE(str, 'q', '');
    SET str = REPLACE(str, 'r', '');
    SET str = REPLACE(str, 's', '');
    SET str = REPLACE(str, 't', '');
    SET str = REPLACE(str, 'u', '');
    SET str = REPLACE(str, 'v', '');
    SET str = REPLACE(str, 'w', '');
    SET str = REPLACE(str, 'x', '');
    SET str = REPLACE(str, 'y', '');
    SET str = REPLACE(str, 'z', '');

    SET str = REPLACE(str, 'A', '');
    SET str = REPLACE(str, 'B', '');
    SET str = REPLACE(str, 'C', '');
    SET str = REPLACE(str, 'D', '');
    SET str = REPLACE(str, 'E', '');
    SET str = REPLACE(str, 'F', '');
    SET str = REPLACE(str, 'G', '');
    SET str = REPLACE(str, 'H', '');
    SET str = REPLACE(str, 'I', '');
    SET str = REPLACE(str, 'J', '');
    SET str = REPLACE(str, 'K', '');
    SET str = REPLACE(str, 'L', '');
    SET str = REPLACE(str, 'M', '');
    SET str = REPLACE(str, 'N', '');
    SET str = REPLACE(str, 'O', '');
    SET str = REPLACE(str, 'P', '');
    SET str = REPLACE(str, 'Q', '');
    SET str = REPLACE(str, 'R', '');
    SET str = REPLACE(str, 'S', '');
    SET str = REPLACE(str, 'T', '');
    SET str = REPLACE(str, 'U', '');
    SET str = REPLACE(str, 'V', '');
    SET str = REPLACE(str, 'W', '');
    SET str = REPLACE(str, 'X', '');
    SET str = REPLACE(str, 'Y', '');
    SET str = REPLACE(str, 'Z', '');

    RETURN str;
  END;
//
DELIMITER ;
-- SHOW WARNINGS;

-- ===================================================================================
--   Count occurrences of delimiter(s) (or any char) in your string
--
--   Returns:
--          * NULL if any of the arguments are NULL or if subject string is empty
--
--          * Count of the occurences of any characters in the delimiter string
-- -----------------------------------------------------------------------------------
DELIMITER //
DROP FUNCTION IF EXISTS countdelim1 //
CREATE FUNCTION countdelim1(delim VARCHAR(1), str TEXT)
  RETURNS INT
  BEGIN
    DECLARE pos INT DEFAULT 1;
    DECLARE c INT DEFAULT 0;

    IF ( delim IS NULL OR str IS NULL )
    THEN
        RETURN NULL;
    END IF;

    REPEAT
      SET pos = LOCATE(delim,str,pos);
      IF (pos)
      THEN
        SET c = c + 1;      -- found
        SET pos = pos + 1;  -- try some more...
      END IF;
    UNTIL (pos=0)
    END REPEAT;

    RETURN c;

  END;
//
DELIMITER ;
-- SHOW WARNINGS;


-- ===================================================================================
--   Count occurrences of delimiter(s) (or any char) in your string
--
--   Returns:
--          * NULL if any of the arguments are NULL or if subject string is empty
--
--          * Count of the occurences of any characters in the delimiter string
-- -----------------------------------------------------------------------------------
DELIMITER //
DROP FUNCTION IF EXISTS countdelim //
CREATE FUNCTION countdelim(delim VARCHAR(10), str TEXT)
  RETURNS INT
  BEGIN
    DECLARE d, l, pos INT DEFAULT 1;
    DECLARE c INT DEFAULT 0;

    IF ( delim IS NULL OR str IS NULL OR str = '' )
    THEN
        RETURN NULL;
    END IF;

    SET l = LENGTH(delim);

    REPEAT
      SET pos = LOCATE(SUBSTR(delim, d, 1), str, pos);
      IF (pos)
      THEN
        SET c = c + 1;      -- found
        SET pos = pos + 1;  -- try some more...
      ELSE                  -- none of this delim exists, try next delim
        SET d = d + 1;
        SET pos = 1;
      END IF;
    UNTIL (d > l)
    END REPEAT;

    RETURN c;

  END;
//
DELIMITER ;
-- SHOW WARNINGS;


-- ===================================================================================
-- Normalize AreaCodes

DELIMITER //
DROP FUNCTION IF EXISTS normarea //
CREATE FUNCTION normarea(code VARCHAR(15))
  RETURNS VARCHAR(5)
  BEGIN

    SET code = strippunc('', stripalpha('',code));

    IF (LENGTH(code) AND code RLIKE "^[[:digit:]]{3}$" ) THEN
      RETURN TRIM(code);
    END IF;

    RETURN NULL;

  END
//
DELIMITER ;
SHOW WARNINGS;


-- ===================================================================================
-- Normalize ZipCodes

DELIMITER //
DROP FUNCTION IF EXISTS normzip //
CREATE FUNCTION normzip(zip VARCHAR(31), country_code VARCHAR(80) )
  RETURNS VARCHAR(31)
  BEGIN

    SET zip = REPLACE(zip, '--', '-');
    SET zip = REPLACE(zip, '  ', ' ');
    SET zip = strippunc('- ', zip); -- Preserve dash, space

    IF (LENGTH(zip))
    THEN
      IF (zip RLIKE "^[[:digit:]]{9,9}$")
      THEN -- zip+4 format (missing "-")
        SET zip = CONCAT(SUBSTR(zip, 1, 5), '-', SUBSTR(zip, 6, 4));
      END IF;
    ELSE
      SET zip=NULL;
    END IF;

    RETURN TRIM(zip);

  END
//
DELIMITER ;
SHOW WARNINGS;


-- ===================================================================================
--   Clean and format a phone number, attempting to differentiate nation numbers.
--    And, specifically, numbers in the local area code
--
--
-- -----------------------------------------------------------------------------------
DELIMITER //
DROP FUNCTION IF EXISTS normphone //
CREATE FUNCTION normphone(phone VARCHAR(255), area VARCHAR(5), country_sa2 VARCHAR(2))
  RETURNS VARCHAR(31)
  BEGIN
    DECLARE a VARCHAR(5) DEFAULT @DEFAULT_AREACODE;
    DECLARE T1 VARCHAR(255);
    DECLARE L INT;
    DECLARE hint VARCHAR(1) DEFAULT '+';

    SET country_sa2 = chop_both('"', country_sa2 );

    IF ( area IS NULL OR area = '' )  THEN
        SET area='[2-9][0-8][0-9]';
    END IF;

    IF ( area != a )  THEN
        SET a = area;
    END IF;

    IF (  country_sa2 IS NOT NULL AND country_sa2 = @DEFAULT_COUNTRY_A ) THEN
        SET hint='';
    END IF;

    SET T1 = TRIM(stripalpha('', strippunc('+',phone)));
    SET L = LENGTH(T1);

    IF (T1 RLIKE CONCAT('^[+]?1*', a, '[[:digit:]]{7}$'))
    THEN -- default area - remove hint from default area
      RETURN substring(T1,-10);
    END IF;

    IF (T1 RLIKE '^[[:digit:]]{7}$')
    THEN -- If no area code, assume "default"
      RETURN CONCAT(area, T1);
    END IF;

    IF (T1 RLIKE '^[2-9][0-8][[:digit:]]{8}$')
    THEN -- Simple 10-digit number
      RETURN T1;
    END IF;

    IF (T1 RLIKE '^00[2-9][[:digit:]]{9,12}$')
    THEN -- International, without hint "+"
      RETURN CONCAT(hint, RIGHT(T1,L-2));
    END IF;
    
    IF (T1 RLIKE '^[0-1]{1,2}[2-9][[:digit:]]{7,9}$')
    THEN -- International, without hint "+"
      RETURN CONCAT(hint, T1);
    END IF;

    IF (T1 RLIKE '^[2-9][[:digit:]]{10,13}$')
    THEN -- International, without hint "+"
      RETURN CONCAT(hint, T1);
    END IF;

    RETURN T1; -- give up DEFAULT, if nothing matched
  END
//
DELIMITER ;
-- SHOW WARNINGS;



-- Normalize a name
-- If lastn, evals to TRUE, Assume name has a optional "last name" component
-- (Not used at this point)

DELIMITER //
DROP FUNCTION IF EXISTS normname //
CREATE FUNCTION normname(str TEXT, lastn BOOLEAN)
  RETURNS TEXT
  BEGIN
    DECLARE name_s TEXT;

    SET name_s = REPLACE(REPLACE(REPLACE(str, '\r', ''), '\n', ''), '\t', '');
    SET name_s = chop_both(' &+-:;,', name_s);
    SET name_s = REPLACE(REPLACE(REPLACE(name_s,'++','+'),'--','-'),'+','-');
    SET name_s = TRIM(REPLACE(cap1name(name_s), ' And ', ' and '));

    IF ( name_s IS NOT NULL )
    THEN
      RETURN name_s;
    ELSE
      RETURN '';
    END IF;

  END;
//
DELIMITER ;
-- SHOW WARNINGS;


-- ===================================================================================
-- Parse a name...
--
-- Given a name string containing first,last,initials and suffixes,
-- return a delimited string of "normalized" name tokens.
--
-- The first token will always be the extracted "first" name ( one name = first name )
--
-- The last token will alway be the extracted "last" name
--   ( or null, if only one "name" token was found )
-- 
-- The other/middle tokens will contain other name parts:
--    prefixes,first-initial,mid-initial,suffixes,
--    if any were found.
--
-- To get first/lastnames:
--
--  SET pname=parsename("Mr. this is a name, jr.",':' );   -> = "This:Mr.:Is:A:Jr.:Name"
--  SET firstname = SUBSTRING_INDEX(pname,  1);       -> = "This"
--  SET lastname  = SUBSTRING_INDEX(pname, -1);       -> = "Name"
--
--  Given delimiter should NOT contain punct. used in name strings:
--  ',.`~&<space>/
--
-- Who knew it could be so complicated?
-- ----------------------------------------------------------------------------------
DELIMITER //
DROP FUNCTION IF EXISTS parsename //
CREATE FUNCTION parsename(str TEXT, delim VARCHAR(1))
  RETURNS VARCHAR(127)
  BEGIN
    DECLARE o VARCHAR(1) DEFAULT delim;
    DECLARE tmp_s, name_s VARCHAR(255);
    DECLARE first_s, last_s, fi_s, mi_s, pre_s, suf_s VARCHAR(63) DEFAULT '';
    DECLARE len, tok, lndx, rndx, first_c, last_c, fi_c, mi_c, pre_c, suf_c INT DEFAULT 0;
    SET @PRE_S = '', @PRE_C = NULL, @SUF_S = '', @SUF_C = NULL, @FN_S = '', @FN_C = NULL, @LN_S = '', @LN_C = NULL, @FI_S = '', @FI_C = NULL, @MI_S = '', @MI_C = NULL;

    IF ( str IS NULL ) THEN RETURN NULL; END IF;

    SET name_s = TRIM(str);
    SET name_s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(name_s, '  ', ' '), '..', '.'), '--', '-'), '++', '+'),'&&','&'),'//','/');
    SET name_s = REPLACE(name_s,'+', '-');
    SET name_s = REPLACE(name_s,'&',' and ');
    SET name_s = REPLACE(name_s,'/',' and ');
    SET name_s = TRIM(REPLACE(name_s,'  ',' '));
    SET len = LENGTH(name_s);

    IF ( name_s IS NULL OR NOT LENGTH(name_s))
    THEN
      RETURN NULL;
    END IF;

    SET tok = 1;
    REPEAT
      SET lndx = LOCATE(' ', name_s, lndx + 1); -- count tokens
      IF (lndx)
      THEN
        SET tok = tok + 1;
      END IF;
    UNTIL (lndx = 0)
    END REPEAT;
    SET @TOK = tok;
    IF (tok = 1)
    THEN -- special case - one token
      RETURN CONCAT(normname(name_s, 0), o); -- Make it a "first" name
    END IF;

    SET rndx = -1;
    SET lndx = 1;

    -- Seek from right, noting suffixes

    SET tmp_s = SUBSTRING_INDEX(name_s, ' ', -1);

    WHILE (tmp_s RLIKE '^[,.]?[JjSsI][RrIV][.,]?$' AND ABS(rndx) < tok) DO -- Just deal with Jr/Sr/IV for now
      SET rndx = rndx - 1;
      SET tmp_s = SUBSTRING_INDEX(SUBSTRING_INDEX(name_s, ' ', rndx), ' ', 1);
      SET suf_c = suf_c + 1;
    END WHILE;
    IF (suf_c)
    THEN
      SET suf_s = SUBSTRING_INDEX(name_s, ' ', rndx + 1);
    END IF;

    SET @SUF_S = CONCAT(o, suf_s, o);
    SET @SUF_C = suf_c;

    -- Continue from right for last name (one)

    IF (tmp_s RLIKE "^[[:alpha:]'`~-]{2,}[,.]?$" AND ABS(rndx) < tok)
    THEN
      SET tmp_s = SUBSTRING_INDEX(SUBSTRING_INDEX(name_s, ' ', rndx), ' ', 1);
      SET last_c = 1;
      SET rndx = rndx - 1;
    END IF;
    IF (last_c)
    THEN
      SET last_s = SUBSTRING_INDEX(SUBSTRING_INDEX(name_s, ' ', rndx + 1), ' ', 1);
    --            SET last_s = chop_last('.,', last_s );                  -- del trailng punct.
    END IF;

    SET @LN_S = CONCAT(o, last_s, o);
    SET @LN_C = last_c;

    -- Seek from left, noting prefixes

    SET tmp_s = SUBSTRING_INDEX(name_s, ' ', 1); -- Rebase on left

    WHILE (tmp_s RLIKE '^[[:alpha:]]{2,3}[.]$' AND lndx < tok) DO
      SET lndx = lndx + 1;
      SET tmp_s = SUBSTRING_INDEX(SUBSTRING_INDEX(name_s, ' ', lndx), ' ', -1);
      SET pre_c = pre_c + 1;
    END WHILE;

    IF (pre_c)
    THEN
      SET pre_s = SUBSTRING_INDEX(name_s, ' ', pre_c);
    END IF;

    SET @PRE_S = CONCAT(o, pre_s, o);
    -- Continue from left checking for first-initials

    WHILE (tmp_s RLIKE '^[[:alpha:]][.]?$' AND lndx < tok) DO
      SET lndx = lndx + 1;
      SET tmp_s = SUBSTRING_INDEX(SUBSTRING_INDEX(name_s, ' ', lndx), ' ', -1);
      SET fi_c = fi_c + 1;
    END WHILE;

    IF (fi_c)
    THEN
      SET fi_s = SUBSTRING_INDEX(SUBSTRING_INDEX(name_s, ' ', lndx - fi_c), ' ', -fi_c);
    END IF;

    SET @FI_S = CONCAT(o, fi_s, o);
    SET @FI_C = fi_c;

    -- Continue from left again for first name tokens

    SET @TMP1 = tmp_s;
    WHILE ( (tmp_s RLIKE "^[[:alpha:]'`~-]{2,}[,.]?$") AND lndx < tok AND tmp_s != last_s) DO
      SET lndx = lndx + 1;
      SET tmp_s = SUBSTRING_INDEX(SUBSTRING_INDEX(utility.strippunc('',name_s), ' ', lndx), ' ', -1);
      SET first_c = first_c + 1;
    END WHILE;
    SET @TMP2 = tmp_s;

    IF (first_c)
    THEN
      SET first_s = SUBSTRING_INDEX(SUBSTRING_INDEX(name_s, ' ', lndx - first_c), ' ', -first_c);
    END IF;

    SET @FN_S = CONCAT(o, first_s, o);
    SET @FN_C = first_c;

    -- Continue from left checking for mid-initials or &, "and"

    WHILE (tmp_s RLIKE '^[[:alpha:]][.]?$|^[&]$|^[Aa][Nn][Dd]$' AND lndx <= tok) DO
      SET lndx = lndx + 1;
      SET tmp_s = SUBSTRING_INDEX(name_s, ' ', lndx);
      SET mi_c = mi_c + 1;
    END WHILE;

    IF (mi_c)
    THEN
      SET mi_s = SUBSTRING_INDEX(SUBSTRING_INDEX(name_s, ' ', lndx - mi_c), ' ', -mi_c);
    END IF;

    SET @MI_S = CONCAT(o, mi_s, o);
    SET @RNDX = rndx;
    SET @LNDX = lndx;

    IF ( first_s LIKE 'And' ) THEN
        RETURN CONCAT(
        normname(fi_s, 0), ' and ',
        normname(mi_s, 0), o,o,o,o,
        normname(suf_s, 0), o,
        normname(last_s, 1));
    ELSE
    RETURN CONCAT(
        normname(first_s, 0), o,
        normname(pre_s, 0), o,
        normname(fi_s, 0), o,
        normname(mi_s, 0), o,
        normname(suf_s, 0), o,
        normname(last_s, 1));
    END IF;

  END
//
DELIMITER ;
-- SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS normaddr //
CREATE FUNCTION normaddr(addr TEXT)
  RETURNS TEXT
  BEGIN
    RETURN TRIM(cap1(strippunc("-./ ", REPLACE(addr, '  ', ' '))));
  END
//
DELIMITER ;
-- SHOW WARNINGS;


-- ===================================================================================
-- Normalize email address

DELIMITER //
DROP FUNCTION IF EXISTS normemail //
CREATE FUNCTION normemail(email TEXT)
  RETURNS VARCHAR(255)
  BEGIN
    DECLARE local_part VARCHAR(127);
    DECLARE domain_part VARCHAR(255);

    IF (LOCATE('@', email))
    THEN
        SET email = REPLACE(email, '..','.');
        SET local_part = strippunc(".!#$%&'*+-/=?^_`{|}~", SUBSTRING_INDEX(email, '@', 1));
        SET domain_part = strippunc("-.", SUBSTRING_INDEX(email, '@', -1));
        RETURN CONCAT(chop_last('".', chop_first('".', local_part)), '@',
                  chop_last('-.', chop_first('-.', domain_part)));
    END IF;

    RETURN email; -- punt!

  END
//
DELIMITER ;
-- SHOW WARNINGS;



-- ===================================================================================
-- Chop First Chars, if exists

DELIMITER //
DROP FUNCTION IF EXISTS chop_leading //
CREATE FUNCTION chop_leading(characters VARCHAR(10), str TEXT)
  RETURNS TEXT
  BEGIN
    DECLARE l, ns INT DEFAULT 0;
    DECLARE c CHAR(1) DEFAULT '';

    IF (NOT LENGTH(characters))
    THEN -- shortcut done
      RETURN str;
    END IF;

    SET l = LENGTH(str);
    SET ns = 1;

    SET c = SUBSTRING(str, ns, 1);
    WHILE (LOCATE(c, characters) AND ns < l) DO
      SET ns = ns + 1;
      SET c = SUBSTRING(str, ns, 1);
    END WHILE;

    IF (ns > 1)
    THEN
      RETURN SUBSTRING(str, ns);
    ELSE
      RETURN str;
    END IF;

  END
//
DELIMITER ;
-- SHOW WARNINGS;

-- ===================================================================================
-- Chop Last Chars, if exists

DELIMITER //
DROP FUNCTION IF EXISTS chop_trailing //
CREATE FUNCTION chop_trailing(characters VARCHAR(10), str TEXT)
  RETURNS TEXT
  BEGIN
    DECLARE l, nl INT DEFAULT 0;
    DECLARE c CHAR(1) DEFAULT '';

    IF (NOT LENGTH(characters))
    THEN -- shortcut done
      RETURN str;
    END IF;

    SET l = LENGTH(str);
    SET nl = l;

    SET c = SUBSTRING(str, l);
    WHILE (LOCATE(c, characters) AND nl > 2) DO
      SET nl = nl - 1;
      SET c = SUBSTRING(str, nl, 1);
    END WHILE;

    IF (nl < l)
    THEN
      RETURN SUBSTRING(str, 1, nl);
    ELSE
      RETURN str;
    END IF;

  END
//
DELIMITER ;
-- SHOW WARNINGS;

-- ===================================================================================
-- Chop First and Last Chars, if they are in the "characters" arg.

DELIMITER //
DROP FUNCTION IF EXISTS chop_bothing //
CREATE FUNCTION chop_bothing(characters VARCHAR(10), str TEXT)
  RETURNS TEXT
  BEGIN

    RETURN chop_leading(characters, chop_trailing(characters, str));

  END
//
DELIMITER ;
-- SHOW WARNINGS;



-- ===================================================================================
-- Chop Leading characters, if they are in the "characters" arg.

DELIMITER //
DROP FUNCTION IF EXISTS chop_first //
CREATE FUNCTION chop_first(characters VARCHAR(10), str TEXT)
  RETURNS TEXT
  BEGIN
    DECLARE fresult TEXT DEFAULT str;

      IF( LOCATE(SUBSTRING(str,1,1),characters) ) THEN
        RETURN SUBSTRING(str,2);
      END IF;
      
      RETURN str;

  END
//
DELIMITER ;
-- SHOW WARNINGS;


-- ===================================================================================
-- Chop Tailing characters, if they are in the "characters" arg.

DELIMITER //
DROP FUNCTION IF EXISTS chop_last //
CREATE FUNCTION chop_last(characters VARCHAR(10), str TEXT)
  RETURNS TEXT
  BEGIN
    DECLARE len INT;
    
      SET len=LENGTH(str);

      IF( LOCATE(SUBSTRING(str,len,1),characters) ) THEN
        RETURN SUBSTRING(str,1,len-1);
      END IF;

      return str;
  END
//
DELIMITER ;
-- SHOW WARNINGS;


-- ===================================================================================
-- Chop Tailing characters, if they are in the "characters" arg.

DELIMITER //
DROP FUNCTION IF EXISTS chop_both //
CREATE FUNCTION chop_both(characters VARCHAR(10), str TEXT)
  RETURNS TEXT
  BEGIN
        RETURN chop_first(characters,(chop_last(characters,str)));
  END
//
DELIMITER ;
-- SHOW WARNINGS;


-- ===================================================================================
-- Normalize ZipCodes

DELIMITER //
DROP FUNCTION IF EXISTS normzip //
CREATE FUNCTION normzip(zip VARCHAR(31))
  RETURNS VARCHAR(31)
  BEGIN

    SET zip = REPLACE(zip, '--', '-');
    SET zip = REPLACE(zip, '  ', ' ');
    SET zip = strippunc('- ', zip); -- Preserve dash, space

    IF (LENGTH(zip))
    THEN
      IF (zip RLIKE "^[[:digit:]]{9,9}$")
      THEN -- zip+4 format (missing "-")
        SET zip = CONCAT(SUBSTR(zip, 1, 5), '-', SUBSTR(zip, 6, 4));
      END IF;
     END IF;

    RETURN TRIM(zip);

  END
//
DELIMITER ;
-- SHOW WARNINGS;


-- ===================================================================================
-- Look for a matching zip/post code in the database of US postal info
--
-- Returns an ordered, delimiter-separated record of associated info:
--
--  CountryCode(2-letter),Postcode,City,State,State-Abbreviation
--
-- -----------------------------------------------------------------------------------

DELIMITER //
DROP FUNCTION IF EXISTS lookup_zip //
CREATE FUNCTION lookup_zip(zip VARCHAR(20), o VARCHAR(1))
  RETURNS VARCHAR(255)
  BEGIN
    DECLARE country_r VARCHAR(3); -- Country-2 code
    DECLARE zip_r VARCHAR(20); -- Zip
    DECLARE city_r VARCHAR(180); -- City
    DECLARE state_r VARCHAR(100); -- State
    DECLARE state_ra VARCHAR(20); -- State abbr.

    BEGIN
      SELECT
        `country2`,
        `post`,
        `place`,
        `name1`,
        `code1`
      INTO country_r, zip_r, city_r, state_r, state_ra
      FROM `location`.`zip`
      WHERE `post` LIKE CONCAT(zip, '%') limit 1;
    END;

    RETURN CONCAT(country_r, o, zip_r, o, city_r, o, state_r, o, state_ra);

  END
//
DELIMITER ;
-- SHOW WARNINGS;

-- Normalize City name
DELIMITER //
DROP FUNCTION IF EXISTS normcity //
CREATE FUNCTION normcity(city TEXT)
  RETURNS VARCHAR(255)
  BEGIN
    DECLARE fresult VARCHAR(255);

    SET fresult = city;
    IF (city LIKE "eagle%river")
    THEN
      SET fresult = 'Eagle River';
    END IF;

    RETURN nomrname(fresult,0);
  END
//
DELIMITER ;
-- SHOW WARNINGS;

