select 'vb_merge_cfields.sql' as 'file';
use `montanac_joom899`;


-- "Special"  JSON Object merge
--
-- Outputs combined values of 2 input operands by:
--
-- Inserting: missing top-level Scalar and ARRAY members from "new" object
-- Replacing: top-level scalar members under certain conditions with values from "new" object
--            including change of destination type.
-- Appending: *missing* top-level ARRAY member elements with ARRAY elements from "new" object -
--            avoids adding existsing values to destination array ( set-like behavior, but
--            does not de-dupplicate existing ARRAY elements )
--
-- Only recursive for OBJECT members
-- In general, "new" values wil replace "old" values
--
DELIMITER //
 DROP PROCEDURE IF EXISTS   vb_merge_cfields //
 CREATE PROCEDURE           vb_merge_cfields(
                                INOUT m INT UNSIGNED,
                                OUT merged JSON,
                                IN  oldcf JSON,
                                IN  newcf JSON
                                )
start1:
 BEGIN
    DECLARE i,j,k,fid INT DEFAULT 0;
    DECLARE n INT DEFAULT @CFIELDS_MAX;
    DECLARE old_v,new_v,new_v_el,a_new JSON;
    DECLARE t,_key VARCHAR(31);
    DECLARE new_s TEXT;
    DECLARE keys_new_j,keys_old_j JSON;

    SET merged=JSON_OBJECT();

    IF ( oldcf IS NULL OR NOT JSON_VALID(oldcf) ) THEN
        SET oldcf = JSON_OBJECT();
    END IF;

    IF ( newcf IS NULL OR NOT JSON_VALID(newcf) ) THEN
        SET merged = oldcf;
        leave start1;
    END IF;

    SET n = JSON_LENGTH(newcf);
    SET keys_new_j = json_keys(newcf);
    SET keys_old_j = json_keys(oldcf);
start2:
        WHILE ( i < n ) DO
            SET fid = json_unquote(json_extract(keys_new_j,CONCAT('$[',i,']') ));
            SET _key = CONCAT('$."',fid,'"');
            SET new_v = json_extract(newcf, _key );
            IF ( new_v IS NULL OR NOT JSON_VALID(new_v) ) THEN
                SET i = i + 1;
                ITERATE start2;
            END IF;
            SET old_v = json_extract(oldcf, _key );
            IF ( old_v IS NULL ) THEN
                SET merged = JSON_SET( merged, _key, new_v );
                SET m = m + 1, i = i + 1;
                ITERATE start2;
            END IF;
            SET t = JSON_TYPE( new_v );
            CASE t
                WHEN 'ARRAY' THEN
                        SET j = JSON_LENGTH(new_v);
                        SET k = 0;
                        SET a_new = old_v;
                        WHILE ( k < j ) DO
                            SET new_v_el = JSON_EXTRACT( new_v, CONCAT('$[',k,']') );
                            IF ( JSON_TYPE(new_v_el) != 'STRING' ) THEN 
                                SET new_v_el = JSON_UNQUOTE( new_v_el );
                            END IF;
                            IF ( NOT JSON_CONTAINS(old_v, new_v_el )) THEN
                                SET a_new = JSON_ARRAY_APPEND(a_new,'$',new_v_el);
                                SET m = m + 1;
                            END IF;
                            SET k = k + 1;
                        END WHILE;
                        SET merged = JSON_SET( merged, _key ,a_new);
                WHEN 'OBJECT' THEN
                        call vb_merge_cfields(new_v,old_v,new_v);
                        SET merged = JSON_SET( merged, _key, new_v  );
                WHEN 'STRING' THEN
                        if ( (old_v != new_v) AND ( json_unquote(new_v) not rlike '^[[:blank:]]*$') )  then
                            set m = m + 1;
                        else
                            SET new_v = old_v;
                        end if;
                        SET merged = JSON_SET( merged, _key, new_v);
                ELSE    -- other *unquoted* Scalar/NULL value
                    IF (old_v != new_v) THEN
                        SET merged = JSON_SET( merged, _key, new_v );
                        SET m = m + 1;
                    END IF;
            END CASE; 
            SET i = i + 1;
        END WHILE;

-- Copy keys from original that were not in new values

        SET n = JSON_LENGTH(oldcf);
        SET i = 0;
        WHILE ( i < n ) DO
            SET fid = json_extract(keys_old_j,CONCAT('$[',i,']'));
            SET _key = CONCAT('$."',fid,'"');
            IF ( NOT JSON_CONTAINS(keys_new_j, CONCAT('"',fid,'"') ) ) THEN
                SET merged = JSON_SET( merged, _key , json_extract(oldcf, _key ));
            END IF;
            SET i = i + 1;
        END WHILE;

  END; //
DELIMITER ;
show warnings;


-- Functional version...
--
DELIMITER //
 DROP FUNCTION IF EXISTS   vb_merge_cfields //
 CREATE FUNCTION           vb_merge_cfields(
                                oldcf JSON,
                                newcf JSON
                                )
RETURNS JSON
 BEGIN
    DECLARE merged JSON DEFAULT JSON_OBJECT();
    DECLARE m INT UNSIGNED;

    call vb_merge_cfields(m,merged,newcf,oldcf);

    RETURN merged;

 END; //
DELIMITER ;
show warnings;
