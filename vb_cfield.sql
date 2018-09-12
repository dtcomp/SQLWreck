DELIMITER ;
select 'vb_cfield.sql' as 'file';
use `montanac_joom899`;


DELIMITER //
 DROP PROCEDURE IF EXISTS vb_cfield_init //
 CREATE PROCEDURE         vb_cfield_init(delim VARCHAR(1))
 BEGIN
    DECLARE o VARCHAR(1) DEFAULT delim;
    DECLARE i,done INT DEFAULT 0;
    DECLARE id_r INT;
    DECLARE name_r,fn,last_fn VARCHAR(127);
    
-- Select records...
    DECLARE cur1 CURSOR FOR SELECT `id`,`name` 
                            from `6rw_vikbooking_custfields`
                            order by id ASC;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

-- Globals for VB "Custom Fields" manipulation

    SET @CFIELD_DELIM=o;
    SET @CFIELD_NAMES='';
    SET @CFIELD_IDS='';
    SET @CFIELD_MAX=0;
    SET @CFIELD_XTRA=CONCAT('ORDER_NAME',o,'FIRST_NAMES',o,'LAST_NAMES',o,'EMAILS',o,'PHONES',o,'COUNTRY',o,'TOTAL',o,'ORDERS',o,'VFIRST',o,'VLAST',o,'SQUARE_ID');

    BEGIN

    SET i=0;
    SET last_fn = SUBSTRING_INDEX(@CFIELD_XTRA,o,-1);
    REPEAT
        SET i = i + 1;
        SET fn = SUBSTRING_INDEX(SUBSTRING_INDEX(@CFIELD_XTRA,o,i),o,-1);
        SET name_r=NULL;
        SELECT `name` INTO name_r from `montanac_joom899`.`6rw_vikbooking_custfields` WHERE `name`=fn;

        IF ( name_r IS NULL )  THEN         -- add extra record
            INSERT INTO `6rw_vikbooking_custfields` (
                `name`,
                `type`,
                `choose`,
                `required`,
                `ordering`,
                `isemail`,
                `poplink`,
                `isnominative`,
                `isphone` ) 
            VALUES( fn, 'hidden', 0, 0, 0, 0, NULL, 0, 0);

        END IF;
    UNTIL ( fn = last_fn )
    END REPEAT;
    END;

    OPEN cur1;

read_loop:
    LOOP

        FETCH cur1 INTO id_r,name_r;
        IF (done) THEN
            LEAVE read_loop;
        END IF;

        SET @CFIELD_MAX   = @CFIELD_MAX + 1;
        SET @CFIELD_NAMES = CONCAT( @CFIELD_NAMES, name_r, o );
        SET @CFIELD_IDS   = CONCAT( @CFIELD_IDS,   id_r,   o );
        
    END LOOP;

    close cur1;    
  END; //
DELIMITER ;
show warnings;



-- Before using items below, call procedure "create_cfields_map()"



DELIMITER //
DROP PROCEDURE IF EXISTS cfield_dump //
CREATE PROCEDURE         cfield_dump( data_j JSON )
  BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE o VARCHAR(1) default @CFIELD_DELIM;
    DECLARE fid int;
    declare fname varchar(31);
    declare val TEXT;
start1:
    WHILE ( i< @CFIELD_MAX ) DO
        set i = i + 1;
        set fid=substring_index(substring_index(@CFIELD_IDS,o,i),o,-1)+0;
        set fname=substring_index(substring_index(@CFIELD_NAMES,o,i),o,-1);
        set val = JSON_UNQUOTE(JSON_EXTRACT( data_j, CONCAT('$."',fid,'"' )));
        if ( val is null ) then
            iterate start1;
        end if;
        select fid as 'field id', fname as 'field name', val as 'field value';
    END WHILE;

  END
//
DELIMITER ;
SHOW WARNINGS;




DELIMITER //
DROP FUNCTION IF EXISTS cfield_map_name_raw //
CREATE FUNCTION cfield_map_name_raw(field_name VARCHAR(31))
  RETURNS INT
  BEGIN
    DECLARE fresult INT;

    BEGIN
      SELECT `id`
      INTO fresult
      FROM `montanac_joom899`.`6rw_vikbooking_custfields`
      WHERE `name` LIKE field_name
      LIMIT 1;
    END;

    RETURN fresult;
  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS cfield_map_id_raw //
CREATE FUNCTION cfield_map_id_raw(rid INT)
  RETURNS VARCHAR(31)
  BEGIN
    DECLARE fresult VARCHAR(31);

    BEGIN
      SELECT `name`
      INTO fresult
      FROM `montanac_joom899`.`6rw_vikbooking_custfields`
      WHERE `id` = rid
      LIMIT 1;
    END;

    RETURN fresult;
  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS cfield_map_id //
CREATE FUNCTION cfield_map_id(id INT)
  RETURNS VARCHAR(31)
  BEGIN
    DECLARE d VARCHAR(1) DEFAULT @CFIELD_DELIM;
    DECLARE i INT DEFAULT 0;
    DECLARE fresult, x VARCHAR(118) DEFAULT NULL;

start1:
    WHILE ( i < @CFIELD_MAX ) DO
      SET i = i + 1;
      SET x = SUBSTRING_INDEX(SUBSTRING_INDEX(@CFIELD_IDS, d, i), d, -1);
      IF ( x+0 = id )  THEN
        SET fresult = SUBSTRING_INDEX(SUBSTRING_INDEX(@CFIELD_NAMES, d, i), d, -1);
        LEAVE start1;
      END IF;
    END WHILE;

    RETURN fresult;
  END
//
DELIMITER ;
SHOW WARNINGS;

DELIMITER //
DROP FUNCTION IF EXISTS cfield_map_name_bare //
CREATE FUNCTION cfield_map_name_bare( fname VARCHAR(31) )
  RETURNS INT
  BEGIN
    DECLARE d VARCHAR(1) DEFAULT @CFIELD_DELIM;
    DECLARE i INT DEFAULT 0;
    DECLARE x VARCHAR(31);
    DECLARE fresult INT DEFAULT NULL;

start1:
    WHILE ( i < @CFIELD_MAX ) DO

      SET i = i + 1;
      SET x = SUBSTRING_INDEX(SUBSTRING_INDEX(@CFIELD_NAMES, d, i), d, -1);

      IF ( x = fname )  THEN
        SET fresult = SUBSTRING_INDEX(SUBSTRING_INDEX(@CFIELD_IDS, d, i), d, -1);
        LEAVE start1;
      END IF;

    END WHILE;

    RETURN fresult;
  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS cfield_map_name //
CREATE FUNCTION cfield_map_name( fname VARCHAR(31) )
  RETURNS VARCHAR(31)
  BEGIN
    DECLARE d VARCHAR(1) DEFAULT @CFIELD_DELIM;
    DECLARE i INT DEFAULT 0;
    DECLARE x VARCHAR(31);
    DECLARE fresult INT DEFAULT NULL;

start1:
    WHILE ( i < @CFIELD_MAX ) DO

      SET i = i + 1;
      SET x = SUBSTRING_INDEX(SUBSTRING_INDEX(@CFIELD_NAMES, d, i), d, -1);

      IF ( x = fname )  THEN
        SET fresult = SUBSTRING_INDEX(SUBSTRING_INDEX(@CFIELD_IDS, d, i), d, -1);
        LEAVE start1;
      END IF;

    END WHILE;

    RETURN CONCAT('$."',fresult,'"');
  END
//
DELIMITER ;
SHOW WARNINGS;



DELIMITER //
DROP FUNCTION IF EXISTS cfield_map_index_name //
CREATE FUNCTION cfield_map_index_name(i INT)
  RETURNS VARCHAR(31)
  BEGIN
    DECLARE d VARCHAR(1) DEFAULT @CFIELD_DELIM;
    DECLARE fresult VARCHAR(31) DEFAULT NULL;

    IF (i <= @CFIELD_MAX AND i > 0)
    THEN
      SET fresult = SUBSTRING_INDEX(SUBSTRING_INDEX(@CFIELD_NAMES, d, i), d, -1);
    END IF;

    RETURN fresult;
  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS cfield_map_index_id //
CREATE FUNCTION cfield_map_index_id(i INT)
  RETURNS INT
  BEGIN
    DECLARE d VARCHAR(1) DEFAULT @CFIELD_DELIM;
    DECLARE fresult INT DEFAULT NULL;

    IF (i <= @CFIELD_MAX AND i > 0)
    THEN
      SET fresult = SUBSTRING_INDEX(SUBSTRING_INDEX(@CFIELD_IDS, d, i), d, -1);
    END IF;

    RETURN fresult;
  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS cfield_get //
CREATE FUNCTION cfield_get( field VARCHAR(31), data_j JSON )
  RETURNS TEXT
  BEGIN
      RETURN JSON_UNQUOTE(JSON_EXTRACT( data_j, cfield_map_name(field) ));
  END
//
DELIMITER ;
SHOW WARNINGS;

DELIMITER //
DROP FUNCTION IF EXISTS cfield_get_int //
CREATE FUNCTION         cfield_get_int( field VARCHAR(31), data_j JSON )
  RETURNS INT
  BEGIN
      RETURN JSON_EXTRACT( data_j, cfield_map_name(field) )+0;
  END
//
DELIMITER ;
SHOW WARNINGS;

DELIMITER //
DROP FUNCTION IF EXISTS cfield_get_dec //
CREATE FUNCTION         cfield_get_dec( field VARCHAR(31), data_j JSON )
  RETURNS DECIMAL(12,2)
  BEGIN
      RETURN JSON_EXTRACT( data_j, cfield_map_name(field) )+0.00;
  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS cfield_get_date //
CREATE FUNCTION         cfield_get_date( field VARCHAR(31), data_j JSON )
  RETURNS DATE
  BEGIN
      RETURN DATE(JSON_UNQUOTE(JSON_EXTRACT( data_j, cfield_map_name(field) )));
  END
//
DELIMITER ;
SHOW WARNINGS;

DELIMITER //
DROP FUNCTION IF EXISTS cfield_get_id //
CREATE FUNCTION         cfield_get_id( id INT, data_j JSON )
  RETURNS JSON
  BEGIN
    RETURN JSON_UNQUOTE(JSON_EXTRACT( data_j, CONCAT('$."', id, '"' ) ));
  END
//
DELIMITER ;
SHOW WARNINGS;

DELIMITER //
DROP FUNCTION IF EXISTS cfield_get_k //
CREATE FUNCTION         cfield_get_k( key_j VARCHAR(31), data_j JSON )
  RETURNS JSON
  BEGIN
        IF ( key_j NOT RLIKE '^[[:digit:]]$' ) THEN
          SET key_j = cfield_map_id(key_j);
        END IF;

        IF ( JSON_CONTAINS_PATH( data_j , 'one', CONCAT( '$."', key_j,'"' ) )) THEN
            RETURN JSON_EXTRACT( data_j, CONCAT('$."', key_j,'"' ) );
        ELSE
            RETURN NULL;
        END IF;

  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS cfield_set //
CREATE FUNCTION         cfield_set( field VARCHAR(31), val VARCHAR(63), data_j JSON )
  RETURNS JSON
  BEGIN
      RETURN JSON_SET( data_j, cfield_map_name(field), val );
  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP PROCEDURE IF EXISTS cfield_set //
CREATE PROCEDURE         cfield_set( field VARCHAR(31), val VARCHAR(63), INOUT data_j JSON )
  BEGIN
    SET data_j = cfield_set( field, val, data_j );
  END
//
DELIMITER ;
SHOW WARNINGS;

DELIMITER //
DROP FUNCTION IF EXISTS cfield_set_date //
CREATE FUNCTION         cfield_set_date( field VARCHAR(31), val DATE, data_j JSON )
  RETURNS JSON
  BEGIN
      RETURN JSON_SET( data_j, cfield_map_name(field), val );
  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP PROCEDURE IF EXISTS cfield_set_date //
CREATE PROCEDURE         cfield_set_date( field VARCHAR(31), val DATE, INOUT data_j JSON )
  BEGIN
    SET data_j = cfield_set_date( field, val, data_j );
  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS cfield_set_array //
CREATE FUNCTION         cfield_set_array( field VARCHAR(31), vals TEXT, data_j JSON, delim VARCHAR(1) )
  RETURNS JSON
  BEGIN
    DECLARE o VARCHAR(1) DEFAULT delim;
    DECLARE i INT       DEFAULT 0;
    DECLARE n INT       DEFAULT utility.listlen(vals,o);
    DECLARE a JSON; --      DEFAULT JSON_ARRAY();                        -- Default to empty array

    SET a = JSON_ARRAY();

        WHILE ( i<n ) DO
            SET i = i + 1;
            SET a = JSON_ARRAY_APPEND(a,'$',SUBSTRING_INDEX(SUBSTRING_INDEX(vals,o,i),o,-1));
        END WHILE;

    RETURN JSON_SET( data_j, cfield_map_name(field), a );

  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP PROCEDURE IF EXISTS cfield_set_array //
CREATE PROCEDURE         cfield_set_array( field VARCHAR(31), vals TEXT, INOUT data_j JSON , delim VARCHAR(1))
  BEGIN
      SET data_j = cfield_set_array( field, vals, data_j, delim);
  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS cfield_set_array_append //
CREATE FUNCTION         cfield_set_array_append( field VARCHAR(31), vals TEXT, data_j JSON , delim VARCHAR(1))
  RETURNS JSON
  BEGIN
    DECLARE o VARCHAR(1)    DEFAULT delim;
    DECLARE i INT           DEFAULT 0;
    DECLARE a_orig JSON     DEFAULT cfield_get_array_json(field,data_j);
    DECLARE a JSON          DEFAULT JSON_ARRAY();
    DECLARE n INT           DEFAULT utility.listlen(vals,o);

      IF ( data_j IS NULL OR NOT JSON_VALID( data_j ) ) THEN
        RETURN data_j;
      END IF;

      IF ( NOT JSON_TYPE(a_orig) = 'ARRAY' ) THEN
        SET a_orig=JSON_ARRAY();
      END IF;

      WHILE ( i<n ) DO
            SET i = i + 1;
            SET a = JSON_ARRAY_APPEND(a,'$',SUBSTRING_INDEX(SUBSTRING_INDEX(vals,o,i),o,-1));
      END WHILE;

      RETURN JSON_SET( data_j, cfield_map_name(field), JSON_MERGE(a_orig,a) );

  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP PROCEDURE IF EXISTS cfield_set_array_append //
CREATE PROCEDURE         cfield_set_array_append( field VARCHAR(31), vals TEXT, INOUT data_j JSON , delim VARCHAR(1))
  BEGIN
    SET data_j = cfield_set_array_append( field, vals, data_j, delim );
  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS cfield_get_array_json //
CREATE FUNCTION         cfield_get_array_json( field VARCHAR(31), data_j JSON )
  RETURNS JSON
  BEGIN
    DECLARE a JSON;

        IF ( NOT JSON_VALID( data_j ) ) THEN
            RETURN JSON_ARRAY();
        END IF;

        SET a = JSON_EXTRACT( data_j, cfield_map_name(field));

        IF ( NOT JSON_VALID(a)  OR JSON_TYPE(a) != 'ARRAY' ) THEN
            RETURN JSON_ARRAY();
        END IF;

        RETURN a;

  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS cfield_get_array_length //
CREATE FUNCTION         cfield_get_array_length( field VARCHAR(31), data_j JSON )
  RETURNS INT
  BEGIN
      RETURN JSON_LENGTH(JSON_EXTRACT( data_j, cfield_map_name(field)));
  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS cfield_get_array //
CREATE FUNCTION         cfield_get_array( field VARCHAR(31), data_j JSON, delim VARCHAR(1) )
  RETURNS TEXT
  BEGIN
    DECLARE o       VARCHAR(1) DEFAULT delim;
    DECLARE a       JSON DEFAULT cfield_get_array_json( field, data_j );
    DECLARE i       INT DEFAULT 0;
    DECLARE n       INT DEFAULT JSON_LENGTH(a);
    DECLARE fresult TEXT DEFAULT '';

    WHILE ( i < n ) DO
        SET i = i + 1;
        IF ( i=n ) THEN SET o=''; END IF;               -- skip trailing delimiter
        SET fresult = CONCAT( fresult, JSON_UNQUOTE(JSON_EXTRACT( a, CONCAT('$[',i-1,']'))), o);
    END WHILE;

    RETURN fresult;

  END //
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS cfield_get_array_element //
CREATE FUNCTION         cfield_get_array_element( field VARCHAR(31), _at INT, data_j JSON )
  RETURNS TEXT
  BEGIN
      RETURN JSON_EXTRACT( data_j, CONCAT('$."', cfield_map_name_bare(field), '"[',_at,']' ));
  END
//
DELIMITER ;
SHOW WARNINGS;

DELIMITER //
DROP FUNCTION IF EXISTS cfield_set_int //
CREATE FUNCTION         cfield_set_int( field VARCHAR(31), val INT, data_j JSON )
  RETURNS JSON
  BEGIN
      RETURN JSON_SET( data_j, cfield_map_name(field), val );
  END
//
DELIMITER ;
SHOW WARNINGS;

DELIMITER //
DROP PROCEDURE IF EXISTS cfield_set_int //
CREATE PROCEDURE         cfield_set_int( field VARCHAR(31), val INT, INOUT data_j JSON )
  BEGIN
    SET data_j = cfield_set_int( field, val, data_j );
  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS cfield_set_dec //
CREATE FUNCTION         cfield_set_dec( field VARCHAR(31), val DECIMAL(12,2), data_j JSON )
  RETURNS JSON
  BEGIN
      RETURN JSON_SET( data_j, cfield_map_name(field), val );
  END
//
DELIMITER ;
SHOW WARNINGS;

DELIMITER //
DROP PROCEDURE IF EXISTS cfield_set_dec //
CREATE PROCEDURE         cfield_set_dec( field VARCHAR(31), val DECIMAL(12,2), INOUT data_j JSON )
  BEGIN
    SET data_j = cfield_set_dec( field, val, data_j );
  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS cfield_set_id //
CREATE FUNCTION         cfield_set_id( field_id INT, val VARCHAR(63), data_j JSON )
  RETURNS JSON
  BEGIN
      RETURN JSON_SET( data_j, CONCAT('$."', field_id , '"' ), val );
  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP PROCEDURE IF EXISTS cfield_set_id //
CREATE PROCEDURE         cfield_set_id( field_id INT, val VARCHAR(63), INOUT data_j JSON )
  BEGIN
    SET data_j = cfield_set_id( field_id, val, data_j );
  END
//
DELIMITER ;
SHOW WARNINGS;


call vb_cfield_init('|');