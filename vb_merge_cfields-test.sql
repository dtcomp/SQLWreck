source vb_merge_cfields.sql;
source vb_cfield.sql;
select 'vb_merge_cfields-test.sql' as 'file';


DELIMITER //
 DROP PROCEDURE IF EXISTS   vb_merge_cfields_test1 //
 CREATE PROCEDURE           vb_merge_cfields_test1()
 BEGIN
    DECLARE done            BOOLEAN DEFAULT 0;
    DECLARE o VARCHAR(1) DEFAULT ',';
    DECLARE cfields_r,
            cfields_n     JSON DEFAULT JSON_OBJECT();
    DECLARE info_cnt,i,vb_cid_r,id,mods   INT;
    DECLARE info_ids    VARCHAR(255);
    DECLARE cur2 CURSOR FOR
                SELECT t1.id
                FROM `6rw_vikbooking_customers` as t1;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN cur2;

read_loop:
    LOOP
        FETCH cur2 INTO vb_cid_r;
        IF (done) THEN LEAVE read_loop; END IF;
        SELECT  group_concat(distinct `t2`.`id`),
                count(distinct `t2`.`id`) as ocnt
                into info_ids,info_cnt
                from `vb_order_info` as t2
                where `t2`.`idcust`=vb_cid_r
                having ocnt>1;
       SET cfields_r=json_object();
        SET i = 0;
        WHILE ( i < info_cnt ) DO
            SET i = i + 1,  mods = 0;
            SET id = SUBSTRING_INDEX(SUBSTRING_INDEX(info_ids,o, i),o,-1)+0;
            SELECT t1.cfields into cfields_n from `vb_order_info` as t1 where t1.id=id;
            select 'before:',mods, cfields_r as 'output' ,cfields_n as 'input';
            call vb_merge_cfields(mods,cfields_r,cfields_r,cfields_n);
            select 'after :',mods, cfields_r as 'output',cfields_n as 'input';
        END WHILE;
    END LOOP;

    CLOSE cur2;

 END; //
DELIMITER ;
show warnings;


DELIMITER //
 DROP PROCEDURE IF EXISTS   vb_merge_cfields_test2 //
 CREATE PROCEDURE           vb_merge_cfields_test2()
 BEGIN
    DECLARE done            BOOLEAN DEFAULT 0;
    DECLARE o VARCHAR(1) DEFAULT ',';
    DECLARE cfields_r,
            cfields_n     JSON DEFAULT JSON_OBJECT();
    DECLARE info_cnt,i,vb_cid_r,id, mods   INT;
    DECLARE info_ids    VARCHAR(255);
    DECLARE cur2 CURSOR FOR
                SELECT `t1`.`cfields`
                FROM `vb_order_info` as t1;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN cur2;
    SET mods=0;
read_loop:
    LOOP
        FETCH cur2 INTO cfields_n;
        IF (done) THEN LEAVE read_loop; END IF;
        call vb_merge_cfields(cfields_r,cfields_r,cfields_n);
    END LOOP;

    CLOSE cur2;
    select mods as modifications, cfields_r as 'output' ,cfields_n as 'input';
 END; //
DELIMITER ;
show warnings;


DELIMITER //
 DROP PROCEDURE IF EXISTS   vb_merge_cfields_test3 //
 CREATE PROCEDURE           vb_merge_cfields_test3()
 BEGIN
SET @cf1='{"6": "703 Mount Elbert Road, Nw", "7": "US", "8": "24149", "9": "Virginia","111": [1,2, 3, 5], "113": "USA"}';
SET @cf2='{"6": "114 Cupola Chase Way", "7": "US", "8": "27519", "9": "North Carolina", "111": [2,4], "113": "USA", "333": ["one","two","3"] }';
SET @cf3='{}';
        call vb_merge_cfields(@cf3,@cf1,@cf2);
        select @cf1;
        select @cf2;
        select @cf3;
 END; //
DELIMITER ;
show warnings;

DELIMITER //
 DROP PROCEDURE IF EXISTS   vb_merge_cfields_test4 //
 CREATE PROCEDURE           vb_merge_cfields_test4()
 BEGIN
    DECLARE mods1,mods2 INT DEFAULT 0;
SET @cf1='{"6": "703 Mount Elbert Road, Nw", "7": "US", "8": "24149", "9": "Virginia", "10": "          ",  "11": "not blank either",   "111": [1,2,3,5], "333": [ "one", "two", "3", 4, "six"], "113": "USA"}';
SET @cf2='{"6": "114 Cupola Chase Way", "7": "US", "8": "27519", "9": "North Carolina", "10": "not blank", "11": "              ", "111": [2,4], "113": "USA", "333": [ "one", "two", 3, "4" ], "777": {"6": "", "7": "US", "8": "94703", "9": "California", "113": "USA"} }';
SET @cf3='{}', @cf4='{}';
SET @expected='{"6": "703 Mount Elbert Road, Nw", "7": "US", "8": "27519", "9": "North Carolina",   "111": [2, 4, 1, 3, 5], "113": "USA", "333": ["one", "two", 3, "4", "3", 4, "six"], "777": {"6": "", "7": "US", "8": "94703", "9": "California", "113": "USA"}}';

        call vb_merge_cfields(mods1,@cf3,@cf1,@cf2);
    if (@cf3=@expected) then
        select "passed" as 'result', '3a' as test;
    else
        select "failed" as 'result', '3a' as test;
        select @cf1;
        select @cf2;
        select @cf3;
        select @expected;
    end if;
        call vb_merge_cfields(mods2,@cf4,@cf2,@cf1);
    if (@cf3=@f4) then
        select "passed" as 'result', '3b' as test;
    else
        select "failed" as 'result', '3b' as test;
        select @cf1;
        select @cf3;
        select @cf4;
    end if;

    call cfield_dump(@cf4);

 END; //
DELIMITER ;
show warnings;


-- Merge all 
DELIMITER //
 DROP PROCEDURE IF EXISTS   vb_merge_cfields_test5 //
 CREATE PROCEDURE           vb_merge_cfields_test5()
 BEGIN
    DECLARE done            BOOLEAN DEFAULT 0;
    DECLARE o VARCHAR(1) DEFAULT ',';
    DECLARE cfields_r,
            cfields_n     JSON DEFAULT JSON_OBJECT();
    DECLARE info_cnt,i,vb_cid_r,id,mods   INT;
    DECLARE info_ids,temp_r    VARCHAR(255);
    DECLARE cur2 CURSOR FOR
                SELECT t1.id
                FROM `6rw_vikbooking_customers` as t1; -- limit 1;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    set mods=0;
    OPEN cur2;

read_loop:
    LOOP
        FETCH cur2 INTO vb_cid_r;
        IF (done) THEN LEAVE read_loop; END IF;
        SELECT  group_concat(distinct `t2`.`id`),
                count(distinct `t2`.`id`) as ocnt
                into info_ids,info_cnt
                from `vb_order_info` as t2
                where `t2`.`idcust`=vb_cid_r
                having ocnt>1;
       SET @cfields_r=json_object();
       SET i = 0;
        select vb_cid_r, info_ids;
        SELECT @cfields_r:=vb_merge_cfields(@cfields_r,`t1`.`cfields`)
            FROM `vb_order_info` as `t1`
            WHERE FIND_IN_SET(`t1`.`id`,info_ids);
    END LOOP;
    CLOSE cur2;
select @cfields_r;
 END; //
DELIMITER ;
show warnings;
-- call vb_merge_cfields_test5();
