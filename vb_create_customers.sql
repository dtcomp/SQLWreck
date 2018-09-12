DELIMITER ;
source global.sql;
source debug.sql;
source utility.sql;
source location.sql;
source vb_merge_cfields.sql;
source vb_total_customers_orders.sql;
select 'vb_create_customers.sql' as 'file';

-- Global debug variables
SET @LAST_ID=-1,@NO_INFO=0,@ITER=0,@NEW_CUST=0;



DELIMITER // 
 DROP PROCEDURE IF EXISTS vb_create_customer_with_orders //
 CREATE PROCEDURE         vb_create_customer_with_orders(order_ids VARCHAR(255), id_cnt SMALLINT, OUT vb_cid SMALLINT )
start1: 
 BEGIN
    DECLARE o                       VARCHAR(1) DEFAULT ',';         -- General delimiter
    DECLARE i,n,id,last_id          SMALLINT UNSIGNED;
    DECLARE cfields_r,cfields_n     JSON DEFAULT JSON_OBJECT();
    DECLARE country_r               VARCHAR(63);
    DECLARE ts1_r,ts2_r             DATE;
    DECLARE name1,name1_ids,
            name2,name2_ids,
            phones,phone_ids,
            emails,email_ids        VARCHAR (255) DEFAULT '';
    
    DECLARE temp_r TEXT;

    IF ( id_cnt > 1 ) THEN
        CALL utility.strlist_numsort( order_ids, 'asc', ',' );
    END IF;

    -- first order date
    SELECT FROM_UNIXTIME(`ts`) INTO  ts1_r FROM  `vb_order_info` WHERE `idorder` = order_ids limit 1;

    -- Resolve names,phones,emails for customer's orders
    SELECT GROUP_CONCAT(distinct `vb_orders_name1`.`name_id`)
        INTO name1_ids
        FROM `vb_orders_name1`
        WHERE FIND_IN_SET(`vb_orders_name1`.`idorder`,order_ids);

    SELECT GROUP_CONCAT(`vb_name1`.`name`)
        INTO name1
        FROM `vb_name1`
        WHERE FIND_IN_SET(`vb_name1`.`id`,name1_ids);

    SELECT GROUP_CONCAT(distinct `vb_orders_name2`.`name_id`)
        INTO name2_ids
        FROM `vb_orders_name2`
        WHERE FIND_IN_SET(`vb_orders_name2`.`idorder`,order_ids);

    SELECT GROUP_CONCAT(`vb_name2`.`name`)
        INTO name2
        FROM `vb_name2`
        WHERE FIND_IN_SET(`vb_name2`.`id`,name2_ids);

    SELECT GROUP_CONCAT(distinct `vb_orders_phones`.`phone_id`)
        INTO phone_ids
        FROM `vb_orders_phones`
        WHERE FIND_IN_SET(`vb_orders_phones`.`idorder`,order_ids);

    SELECT GROUP_CONCAT(`vb_phones`.`phone`)
        INTO phones
        FROM `vb_phones`
        WHERE FIND_IN_SET(`vb_phones`.`id`,phone_ids);

    SELECT GROUP_CONCAT(distinct `vb_orders_emails`.`email_id`)
        INTO email_ids
        FROM `vb_orders_emails`
        WHERE FIND_IN_SET(`vb_orders_emails`.`idorder`,order_ids);

    SELECT GROUP_CONCAT(`vb_emails`.`email`)
        INTO emails
        FROM `vb_emails`
        WHERE FIND_IN_SET(`vb_emails`.`id`,email_ids);

    -- Merge cfields from all orders
    SET @vb_create_customer_with_orders_cfields=json_object();
    SELECT GROUP_CONCAT(@vb_create_customer_with_orders_cfields:=vb_merge_cfields(@vb_create_customer_with_orders_cfields,`t1`.`cfields`))
        FROM `vb_order_info` as `t1`
        WHERE FIND_IN_SET(`t1`.`idorder`,order_ids);
    SET cfields_r=@vb_create_customer_with_orders_cfields;

    -- Extract id of last *chronological* order
    SET last_id = SUBSTRING_INDEX(SUBSTRING_INDEX(order_ids,o, -1),o,1)+0;

   -- Get country and order date from last order
    SELECT FROM_UNIXTIME(`ts`) INTO  ts2_r FROM  `vb_order_info` WHERE `idorder` = last_id limit 1;

    IF( cfields_r IS NULL OR NOT JSON_VALID(cfields_r) ) THEN        -- This should not happen
        SET cfields_r = JSON_OBJECT();
    END IF;

    call cfield_dump( cfields_r);

--              cfield_set('ORDER_NAME',`t2`.`cfields`),
--              cfield_set('ORDER_EMAIL',`t2`.`cfields`),
--              cfield_set('ORDER_PHONE',`t2`.`cfields`),
--              cfield_set('ORDER_ADDRESS',`t2`.`cfields`),
--              cfield_set('ORDER_CITY',`t2`.`cfields`),
--              cfield_set('ORDER_STATE',`t2`.`cfields`),
--              cfield_set('ORDER_ZIPCODE',`t2`.`cfields`),            
--              cfield_get('COUNTRY',`t2`.`cfields`),
--              cfield_get('TOTAL',`t2`.`cfields`),
--              cfield_get('ORDERS',`t2`.`cfields`),
--              cfield_get('SQUARE_ID',`t2`.`cfields`),
 
    -- And store  custom fields
--    call cfield_set(      'COUNTRY',     country_r, cfields_r);
    SET country_r = location.lookup_areacode_state_name2(LEFT(cfield_get('COUNTRY',cfields_r),31));
    call cfield_set_date( 'VFIRST',      ts1_r,      cfields_r);
    call cfield_set_date( 'VLAST',       ts2_r,      cfields_r);
    call cfield_set_array('PHONES',      phones,    cfields_r,o);
    call cfield_set_array('FIRST_NAMES', name1,     cfields_r,o);
    call cfield_set_array('LAST_NAMES',  name2,     cfields_r,o);
    call cfield_set_array('EMAILS',      emails,    cfields_r,o);

    INSERT INTO `6rw_vikbooking_customers`
                (
                `first_name`,
                `last_name`,
                `email`,
                `phone`,
                `country`,
                `cfields`
                )
        VALUES  (
                IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(name1,  o, 1),o,-1),''),
                IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(name2,  o, 1),o,-1),''),
                SUBSTRING_INDEX(SUBSTRING_INDEX(emails, o, 1),o,-1),
                SUBSTRING_INDEX(SUBSTRING_INDEX(phones, o, 1),o,-1),
                country_r,
                cfields_r
                );

    SET vb_cid=LAST_INSERT_ID();
-- select concat(  IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(name1,  o, 1),o,-1),' name1 is null, '),' ',
--                 IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(name2,  o, 1),o,-1),' name2 is null, '),' ',
--                 IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(emails, o, 1),o,-1),' email is null, '),' ',
--                 IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(phones, o, 1),o,-1),' phone is null,  '),' ',
--                 IFNULL(country_r,' country is null '),' ',
--                 IFNULL(cfields_r,' cfields is null ' )) as debug;

 
    INSERT INTO `vb_customers_name2` VALUES (vb_cid, name2_ids );
    INSERT INTO `vb_customers_name1` VALUES (vb_cid, name1_ids);
    INSERT IGNORE INTO `vb_customers_phones` VALUES (vb_cid, phone_ids);
    INSERT IGNORE INTO `vb_customers_emails` VALUES (vb_cid, email_ids);
    UPDATE `vb_order_status`  SET   `status` = 4 WHERE find_in_set(`idorder`,order_ids);
    UPDATE `vb_order_info` SET `idcust` = vb_cid WHERE find_in_set(`idorder`,order_ids);

    SET i = 0;
    WHILE ( i < id_cnt ) DO
        SET i = i + 1;
        SET id = SUBSTRING_INDEX(SUBSTRING_INDEX(order_ids,o, i),o,-1)+0;
        INSERT INTO `6rw_vikbooking_customers_orders` (`idcustomer`,`idorder` )VALUES ( vb_cid, id );
    END WHILE;

END;//
DELIMITER ;
show warnings;


/*
    To fix a situation like:

select id,replace(custdata,'\r',':') , custmail, phone from 6rw_vikbooking_orders where id in (337,1231,1863);
+------+-------------------------------------------------------------------------+---------------------------+------------+
 | id   | replace(custdata,'\r',':')                                             | custmail                  | phone      |
+------+-------------------------------------------------------------------------+---------------------------+------------+
|  337 | Samantha Berry:PO Box 879452:Wasilla AK, 99687:9076995524:samantha20dia | samantha20diane@yahoo.com | 9074565524 |
| 1231 | Name: Samantha berry:e-Mail: Samantha20diane@yahoo.com                  | Samantha20diane@yahoo.com | 9076995382 |
| 1863 |                                                                         | samantha20diane@yahoo.com |            |
+------+-------------------------------------------------------------------------+---------------------------+------------+
3 rows in set (0.01 sec)


*/


DELIMITER // 
 DROP PROCEDURE IF EXISTS vb_create_customers_current_order_status //
 CREATE PROCEDURE         vb_create_customers_current_order_status( OUT order_status ENUM('initial','extracted','matched_customer','created_customer'), order_id SMALLINT )
 BEGIN
        SELECT `status` into order_status from `vb_order_status` where `idorder`=order_id;
 END;//
DELIMITER ;

DELIMITER // 
 DROP PROCEDURE IF EXISTS vb_create_customers_order_set //
 CREATE PROCEDURE         vb_create_customers_order_set( test_ids VARCHAR(63) )
 BEGIN
    DECLARE id_r,i,j,t  SMALLINT;
    DECLARE email_id    SMALLINT;
    DECLARE order_ids,
            phone_orders_r,
            phone_ids_r,
            email_orders_r,
            email_ids_r VARCHAR(255);
    DECLARE email_cnt_r,
            phone_cnt_r,
            email_order_cnt_r,
            phone_order_cnt_r,
            idorder,
            orders_with_phone,
            orders_with_email,
            order_cnt,
            orders_total,
            processed   SMALLINT;
    DECLARE order_status ENUM('initial','extracted','matched_customer','created_customer') default 'initial';
    DECLARE done    BOOLEAN DEFAULT 0;
    DECLARE cur1 CURSOR FOR SELECT `t1`.`idorder`, `t1`.`cnt_email`, `t1`.`cnt_phone`
                                FROM `vb_order_info` as `t1`
                                join `vb_order_status` as `t2`
                                on `t1`.`idorder`=`t2`.`idorder`
                                where ( `t1`.`cnt_email` or `t1`.`cnt_phone` ) and `t2`.`status` < 3;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    SELECT count(t1.idorder) 
        INTO orders_total
        FROM `vb_order_info` as `t1`
        join `vb_order_status` as `t2`
        on `t1`.`idorder`=`t2`.`idorder`
        where (`t1`.`cnt_email` or `t1`.`cnt_phone`) and `t2`.`status` < 3;

    SET processed=0;
    OPEN cur1;

read_loop:
    LOOP
        SET email_cnt_r=0, phone_cnt_r=0, order_cnt=0;
        SET email_orders_r = null, phone_orders_r = null, order_ids = null;

        FETCH cur1 INTO id_r, email_cnt_r, phone_cnt_r;
        IF (done) THEN LEAVE read_loop; END IF;

        call vb_create_customers_current_order_status( order_status, id_r );

        IF ( order_status+0 >= 3 ) THEN
            ITERATE read_loop;
        END IF;

        if ( email_cnt_r ) then
            BEGIN
                DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 0;
                select group_concat(distinct `t1`.`order_ids` order by `t1`.`order_ids` asc)
                    into email_orders_r
                    from `vb_order_map_email` as `t1`
                    where find_in_set(id_r,`t1`.`order_ids`);
            END;
        end if;

        if ( phone_cnt_r ) then
            BEGIN
                DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 0;
                select group_concat(distinct `t1`.`order_ids` order by `t1`.`order_ids` asc)
                    into phone_orders_r
                    from `vb_order_map_phone` as `t1`
                    where find_in_set(id_r,`t1`.`order_ids`); -- and not find_in_set(`t1`.`order_ids`, email_orders_r);
            END;
        end if;

        IF ( NOT ( email_orders_r is null AND phone_orders_r is null ) ) THEN
            SET order_ids = CONCAT( email_orders_r,',',phone_orders_r );
        ELSE
            IF ( email_orders_r is not null )  THEN
               SET order_ids = email_orders_r;
            END IF;
            IF ( phone_orders_r is not null ) THEN
               SET order_ids = phone_orders_r; 
            END IF;
        END IF;
        
        IF ( order_ids is null )  then
            iterate read_loop;
        end if;

-- select order_ids as  before_setify;
        call utility.strlist_setify( order_ids , order_cnt, ',' );
-- select order_ids as after_setify;

        INSERT INTO `vb_order_sets`  (`order_ids`,`id_cnt`) VALUES ( order_ids, order_cnt );
        
        UPDATE `vb_order_status`
            set `status`='matched_customer'
            where find_in_set(`vb_order_status`.`idorder`, order_ids );

        SET processed = processed + order_cnt;

    END LOOP;
    
    CLOSE cur1;

    select 'vb_create_customers_order_set()' as proc, orders_total, processed;


END;//
DELIMITER ;
show warnings;



DELIMITER // 
 DROP PROCEDURE IF EXISTS vb_create_customers_order_set_expand //
 CREATE PROCEDURE         vb_create_customers_order_set_expand( test_ids VARCHAR(63) )
 BEGIN
    DECLARE id_r        SMALLINT;
    DECLARE email_id    SMALLINT;
    DECLARE order_ids   VARCHAR(255);
    DECLARE order_cnt,
            orders_total,
            processed   SMALLINT;
    DECLARE order_status ENUM('initial','extracted','matched_customer','created_customer') default 'initial';

    DECLARE done    BOOLEAN DEFAULT 0;
--    DECLARE cur1 CURSOR FOR SELECT `t1`.`idorder` FROM `vb_order_info` as `t1` where (`t1`.`cnt_email` or `t1`.`cnt_phone`);

    DECLARE cur1 CURSOR FOR SELECT `t1`.`idorder`
                                from `vb_order_status` as `t1`
                                where ( `t1`.`status` = 'matched_customer' );

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    SELECT count(*) INTO orders_total FROM `vb_order_status` as `t1` where ( `t1`.`status` = 'matched_customer' );

    SET processed=0;

    OPEN cur1;

read_loop:
    LOOP
        set order_cnt=0, order_ids = null, id_r = null;
        FETCH cur1 INTO id_r;

        IF (done) THEN LEAVE read_loop; END IF;

        BEGIN
            DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 0;
            select group_concat(distinct `t1`.`order_ids`)
                into order_ids
                from `vb_order_sets` as `t1`
                where find_in_set(id_r,`t1`.`order_ids`);
        END;
        
        IF ( order_ids is null )  then
            iterate read_loop;
        end if;

-- select order_ids as  before_setify;
        call utility.strlist_setify( order_ids , order_cnt, ',' );
-- select order_ids as after_setify;

        INSERT INTO `vb_order_sets_expanded`  (`order_ids`,`id_cnt`) VALUES ( order_ids, order_cnt );
        
--         UPDATE `vb_order_status`
--             set `vb_order_status`.`status`='matched_customer'
--             where find_in_set(`vb_order_status`.`idorder`, order_ids );

        SET processed = processed + 1;

    END LOOP;
    
    CLOSE cur1;

    select 'vb_create_customers_order_set_expand()' as proc, orders_total, processed;


END;//
DELIMITER ;
show warnings;


DELIMITER // 
 DROP PROCEDURE IF EXISTS vb_create_customers_order_sets //
 CREATE PROCEDURE         vb_create_customers_order_sets( order_ids VARCHAR(63) )
 BEGIN
    DECLARE phones_r, emails_r VARCHAR(255);
    DECLARE i,r      SMALLINT;

    TRUNCATE vb_order_map_email;
    TRUNCATE vb_order_map_phone;
    TRUNCATE vb_order_sets;
    TRUNCATE vb_order_sets_expanded;


    INSERT INTO `vb_order_map_email` (`email_id`, `order_ids`)
        SELECT `t1`.`email_id`, group_concat(`t1`.`idorder`) from `vb_orders_emails` as `t1` group by `t1`.`email_id`;

    INSERT INTO `vb_order_map_phone` (`phone_id`, `order_ids`)
        SELECT `t1`.`phone_id`, group_concat(`t1`.`idorder`) from `vb_orders_phones` as `t1` group by `t1`.`phone_id`;

    call vb_create_customers_order_set(order_ids);
    call vb_create_customers_order_set_expand(order_ids);

END;//
DELIMITER ;
show warnings;

DELIMITER // 
 DROP PROCEDURE IF EXISTS vb_create_customers_current_order_stati //
 CREATE PROCEDURE         vb_create_customers_current_order_stati( OUT order_status ENUM('initial','extracted','matched_customer','created_customer'), order_ids VARCHAR(255) )
 BEGIN
    SELECT `t1`.`status`
            INTO order_status
            FROM `vb_order_status` as `t1`
            WHERE FIND_IN_SET(`t1`.`idorder`,order_ids)
            LIMIT 1;
 END;//
DELIMITER ;


DELIMITER // 
 DROP PROCEDURE IF EXISTS vb_create_customers_with_phone_or_email //
 CREATE PROCEDURE         vb_create_customers_with_phone_or_email()
 BEGIN
    DECLARE vb_cid          SMALLINT DEFAULT 0;
    DECLARE order_ids_r     VARCHAR(255);
    DECLARE id_cnt_r        SMALLINT;
    DECLARE status_r        ENUM('initial','extracted','matched_customer','created_customer') DEFAULT 'initial';
    DECLARE done            BOOLEAN DEFAULT 0;
    DECLARE processed       SMALLINT DEFAULT 0;

    -- Here's the trick - order by order_cnt, desc, so that we get the longest order set first
    DECLARE cur1 CURSOR FOR SELECT `t1`.`order_ids`, `t1`.`id_cnt`
        FROM `vb_order_sets_expanded` as `t1`
        ORDER BY `t1`.`id_cnt` DESC;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN cur1;

read_loop:
    LOOP
        FETCH cur1 INTO order_ids_r, id_cnt_r;
        IF ( done )  THEN LEAVE read_loop; END IF;
        call vb_create_customers_current_order_stati(status_r,order_ids_r);
        IF ( status_r+0 = 3 ) THEN
            CALL vb_create_customer_with_orders(order_ids_r, id_cnt_r, vb_cid);
-- leave read_loop;
            SET processed = processed + id_cnt_r;
        END IF;
    END LOOP;

    CLOSE cur1;
    select 'vb_create_customers_with_phone_or_email()' as proc, processed;
END;//
DELIMITER ;
show warnings;


DELIMITER // 
 DROP PROCEDURE IF EXISTS vb_create_customers //
 CREATE PROCEDURE         vb_create_customers(order_ids VARCHAR(63))
 BEGIN

    call vb_create_customers_order_sets(order_ids);
    call vb_create_customers_with_phone_or_email();
    call vb_create_customers_by_name();

END;//
DELIMITER ;
show warnings;


DELIMITER // 
 DROP PROCEDURE IF EXISTS vb_create_customers_by_name //
 CREATE PROCEDURE         vb_create_customers_by_name()
 BEGIN
    DECLARE ocnt,i,vb_cid     SMALLINT;

    TRUNCATE vb_orders_temp;
    -- Create one-name (lastname) customers 
    INSERT INTO vb_orders_temp
        (
        `order_ids`, `id_cnt`
        )
        SELECT
            group_concat(distinct t1.`idorder` order by t1.`idorder` asc ) as order_ids, \
            count(distinct t1.idorder) as id_cnt \
            from vb_orders_name2 as t1 \
            left join vb_orders_name1 as t2 on t2.idorder=t1.idorder \
            left join vb_orders_phones as t3 on t3.idorder=t1.idorder \
            left join vb_orders_emails as t4 on t4.idorder=t1.idorder \
            where ( t1.idorder is not null and t2.idorder is null and t3.idorder is null and t4.idorder is null ) \
            group by t1.name_id; --  having utility.countdelim(',',order_ids)=0;

    SET ocnt=FOUND_ROWS(), i=0;
    WHILE ( i < ocnt )  DO
        SET i = i + 1;
        CALL vb_create_customers_from_table(i,vb_cid);
    END WHILE;

    TRUNCATE vb_orders_temp;
    -- Create one-name (firstname) customers 
    INSERT INTO vb_orders_temp
        (
        `order_ids`, `id_cnt`
        )
        SELECT
            group_concat(t1.`idorder` order by t1.`idorder` asc ) as order_ids, \
            count(distinct t1.idorder) as id_cnt \
            from vb_orders_name1 as t1 \
            left join vb_orders_name2 as t2 on t2.idorder=t1.idorder \
            left join vb_orders_phones as t3 on t3.idorder=t1.idorder \
            left join vb_orders_emails as t4 on t4.idorder=t1.idorder \
            where ( t1.idorder is not null and t2.idorder is null and t3.idorder is null and t4.idorder is null ) \
            group by t1.name_id;  --  having utility.countdelim(',',order_ids)=0;
       
    SET ocnt=FOUND_ROWS(), i=0;
    WHILE ( i < ocnt )  DO
        SET i = i + 1;
        CALL vb_create_customers_from_table(i,vb_cid);
    END WHILE;

    TRUNCATE vb_orders_temp;
    INSERT INTO vb_orders_temp (`order_ids`, `id_cnt` )
        SELECT
            group_concat(t1.idorder order by t1.idorder asc ) as order_ids, \
            count(distinct t1.idorder) as id_cnt \
            from vb_orders_name1 as t1 \
            left join vb_orders_name2 as t2 on t2.idorder=t1.idorder \
            left join vb_orders_phones  as t3 on t3.idorder=t1.idorder \
            left join vb_orders_emails as t4 on t4.idorder=t1.idorder \
            where ( t1.idorder is not null and t2.idorder is not null and t3.idorder is null  and t4.idorder is null ) \
            group by t2.name_id, t1.name_id;   --  having utility.countdelim(',',order_ids)=0;

    SET ocnt=FOUND_ROWS(), i=0;
    WHILE ( i < ocnt )  DO
        SET i = i + 1;
        CALL vb_create_customers_from_table(i,vb_cid);
    END WHILE;



END;//
DELIMITER ;
show warnings;


DELIMITER // 
 DROP PROCEDURE IF EXISTS vb_create_customers_from_table //
 CREATE PROCEDURE         vb_create_customers_from_table(rid SMALLINT UNSIGNED, OUT vb_cid SMALLINT)
 BEGIN
    DECLARE order_ids_r VARCHAR(255);
    DECLARE id_cnt_r    SMALLINT;
    SELECT `order_ids`, `id_cnt` INTO order_ids_r, id_cnt_r FROM vb_orders_temp WHERE `id`=rid;
    CALL vb_create_customer_with_orders( order_ids_r, id_cnt_r, vb_cid );
END;//
DELIMITER ;
show warnings;


DELIMITER // 
    DROP PROCEDURE IF EXISTS vb_create_customers_reset //
    CREATE PROCEDURE         vb_create_customers_reset()
BEGIN
    DECLARE done    BOOLEAN DEFAULT 0;
    DECLARE id_r    SMALLINT UNSIGNED;
    DECLARE cur1    CURSOR FOR SELECT `idorder` FROM `vb_order_info`;
    DECLARE         CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN cur1;

read_loop:
    LOOP
        FETCH cur1 INTO id_r;
        IF (done) THEN LEAVE read_loop; END IF;
        INSERT INTO `vb_order_status` VALUES( id_r, 'extracted' ) ON DUPLICATE KEY UPDATE `status`= 'extracted';
    END LOOP;
    
    CLOSE cur1;

    TRUNCATE `6rw_vikbooking_customers`;                        -- forget ALL customers...
    TRUNCATE `6rw_vikbooking_customers_orders`;                 -- and their order associations
    TRUNCATE `vb_customers_emails`;
    TRUNCATE `vb_customers_name1`;
    TRUNCATE `vb_customers_name2`;
    TRUNCATE `vb_customers_phones`;
    TRUNCATE `vb_order_map_phone`;
    TRUNCATE `vb_order_map_email`;
    TRUNCATE `vb_order_sets`;
    TRUNCATE `vb_order_sets_expanded`;
    TRUNCATE `vb_orders_temp`;

END;//
DELIMITER ;
show warnings;

DELIMITER // 
    DROP PROCEDURE IF EXISTS vb_create_customers_init //
    CREATE PROCEDURE         vb_create_customers_init()
BEGIN

    DROP TABLE IF EXISTS `vb_customers_emails`;
    DROP TABLE IF EXISTS `vb_customers_name1`;
    DROP TABLE IF EXISTS `vb_customers_name2`;
    DROP TABLE IF EXISTS `vb_customers_phones`;
    DROP TABLE IF EXISTS `vb_order_map_phone`;
    DROP TABLE IF EXISTS `vb_order_map_email`;
    DROP TABLE IF EXISTS `vb_order_sets`;
    DROP TABLE IF EXISTS `vb_order_sets_expanded`;
    DROP TABLE IF EXISTS `vb_orders_temp`;


-- Table to collect order -> email matches in VikBooking
CREATE TABLE IF NOT EXISTS `vb_customers_emails` (
	`idcustomer`        SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0 ,
        `email_ids`         varchar(255) NULL,
        PRIMARY KEY (`idcustomer`),
	INDEX (`idcustomer`,`email_ids`)
        ) ENGINE=MYISAM;

-- Table to collect order -> phone matches in VikBooking
CREATE TABLE IF NOT EXISTS `vb_customers_phones` (
	`idcustomer`        SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0 ,
        `phone_ids`         varchar(255) NULL,
        PRIMARY KEY (`idcustomer`),
	INDEX (`idcustomer`,`phone_ids`)
        ) ENGINE=MYISAM;

-- Table to collect order -> name1 matches in VikBooking
CREATE TABLE IF NOT EXISTS `vb_customers_name1` (
	`idcustomer`        SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0 ,
        `name_ids`          varchar(255) NULL,
        PRIMARY KEY (`idcustomer`),
	INDEX (`idcustomer`,`name_ids`)
        ) ENGINE=MYISAM;

-- Table to collect order -> name2 matches in VikBooking
CREATE TABLE IF NOT EXISTS `vb_customers_name2` (
	`idcustomer`        SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0 ,
        `name_ids`          varchar(255) NULL,
        PRIMARY KEY (`idcustomer`),
	INDEX (`idcustomer`,`name_ids`)
        ) ENGINE=MYISAM;

-- TEMPORARY TABLES
CREATE TABLE IF NOT EXISTS `vb_order_map_phone` (
  `id`          SMALLINT(4) UNSIGNED NOT NULL auto_increment,
  `phone_id`    SMALLINT NULL,
  `order_ids`   varchar(255) NULL,
  PRIMARY KEY (`id`)
) ENGINE=MEMORY;

CREATE TABLE  IF NOT EXISTS `vb_order_map_email` (
  `id`          SMALLINT(4) UNSIGNED NOT NULL auto_increment,
  `email_id`    SMALLINT(4) NULL,
  `order_ids`   varchar(255) NULL,
  PRIMARY KEY (`id`)
) ENGINE=MEMORY;

CREATE TABLE IF NOT EXISTS `vb_order_sets` (
  `id`              SMALLINT(4) UNSIGNED NOT NULL auto_increment,
  `order_ids`       varchar(255) NOT NULL,
  `id_cnt`          SMALLINT NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MEMORY;

CREATE TABLE IF NOT EXISTS `vb_order_sets_expanded` (
  `id`              SMALLINT(4) UNSIGNED NOT NULL auto_increment,
  `order_ids`       varchar(255) NOT NULL,
  `id_cnt`          SMALLINT NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MEMORY;

CREATE TABLE IF NOT EXISTS vb_orders_temp (
    `id`            SMALLINT(4) UNSIGNED NOT NULL auto_increment,
    `order_ids`     VARCHAR(255) NULL,
    `id_cnt`        SMALLINT NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE = MEMORY;


END;//
DELIMITER ;
show warnings;

DELIMITER // 
    DROP PROCEDURE IF EXISTS vb_create_customers_show //
    CREATE PROCEDURE         vb_create_customers_show(vb_cids VARCHAR(127))
BEGIN

    IF (vb_cids) is null then
        select t1.id, last_name, first_name, email, phone, group_concat(t2.idorder) as order_ids
            from `6rw_vikbooking_customers` as t1
            left join `6rw_vikbooking_customers_orders` as t2
            on t2.idcustomer=t1.id
            group by t1.id
            order by last_name, first_name;
    else
        select t1.id, last_name, first_name, email, phone,
            group_concat(t2.idorder order by t2.idorder asc) as order_ids
            from `6rw_vikbooking_customers` as t1
            left join `6rw_vikbooking_customers_orders` as t2
            on t2.idcustomer=t1.id
            where find_in_set(t1.id,vb_cids)
            group by t1.id
            order by last_name, first_name;
    end if;

END;//
DELIMITER ;
show warnings;


    call vb_create_customers_reset();
    call vb_create_customers(NULL);
    call vb_total_customers_orders();
    call vb_create_customers_show(null);

