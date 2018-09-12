DELIMITER ;
source global.sql;
source debug.sql;
source utility.sql;
source location.sql;
use `montanac_joom899`;
source vb_cfield.sql;

-- Global debug variables
SET @LAST_ID=-1,@NO_INFO=0,@ITER=0,@NEW_CUST=0;

DELIMITER //
 DROP PROCEDURE IF EXISTS dbinfo //
 CREATE PROCEDURE dbinfo()
    BEGIN
    SELECT CONCAT(  "\r\nDuplicated Rows (srch):", @DUP_ROWS,'\r\n',
                        "Last Id Processed     :", @LAST_ID,'\r\n'
                        "Records not matched   :", @NOT_MATCHED,'\r\n',
                        "Loose matches         :", @MATCH_LOOSE,'\r\n',
                        "Orders w/o info       :", @NO_INFO,'\r\n',
                        "Square record updates :", @SQUARE_UPDATES,'\r\n',
                        "New customers created :", @NEW_CUST,'\r\n',
                        "Loop iterations       :", @ITER,'\r\n') as "Debug Info";
    END //
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
 DROP PROCEDURE IF EXISTS sq_customer_save //
 CREATE PROCEDURE sq_customer_save(
            OUT id              SMALLINT,
                reference_id_i  INT,
                firstname_s     VARCHAR(31),
                lastname_s      VARCHAR(31),
                email_s         VARCHAR(63),
                phone_s         VARCHAR(31),
                nickname_s      VARCHAR(63),
                company_s       VARCHAR(63),
                address1_s      VARCHAR(63),
                address2_s      VARCHAR(63),
                city_s          VARCHAR(63),
                state_sa        VARCHAR(2),
                post_s          VARCHAR(31),
                birthday_d      DATE,
                memo_s          TEXT,
                square_id_s     VARCHAR(31),       
                source_s        VARCHAR(63),
                vfirst_d        DATE,
                vlast_d         DATE,
                transactions_i  INT,
                spent_d         DECIMAL(12,2),
                unsubscribed_b  BOOLEAN,
                instant_b       BOOLEAN
                )
BEGIN
    DECLARE mmsg    TEXT;

    set mmsg = concat( 'Created by VB:Merge on:  ', now() );
    if ( memo_s is null or memo_s ='') then
        set memo_s = mmsg;
    else
        set memo_s = concat( memo_s, '\n\r', mmsg );
    end if;





    INSERT INTO `mcc_customer`.`sq_customers` (
                `reference_id`,
                `first_name`,
                `last_name`,
                `email`,
                `phone`,
                `nickname`,
                `company`,
                `address1`,
                `address2`,
                `city`,
                `state`,
                `post`,
                `birthday`,
                `memo`,
                `square_id`,
                `source`,
                `vfirst`,
                `vlast`,
                `transactions`,
                `spent`,
                `unsubscribed`,
                `instant`
                 )






        VALUES( 
                reference_id_i,
                firstname_s,
                lastname_s,
                email_s,
                phone_s,
                nickname_s,
                company_s,
                address1_s,
                address2_s,
                city_s,
                state_sa,
                post_s,
                birthday_d,
                memo_s,
                square_id_s,
                ifnull(source_s,'VB:Merge'),
                vfirst_d,
                vlast_d,
                transactions_i,
                spent_d,
                unsubscribed_b,
                instant_b
                );

    SET id = LAST_INSERT_ID();         -- Not the "Square" customer id, refers to the record row id

    INSERT INTO `mcc_customer`.`sq_customer_status`
        VALUES ( id,'created' );

END; //
DELIMITER ;
show warnings;


DELIMITER //
 DROP PROCEDURE IF EXISTS sq_customer_update //
 CREATE PROCEDURE         sq_customer_update(
            sq_rid          INT,    -- rid to update
            reference_id_i  INT,
            firstname_s     VARCHAR(31),
            lastname_s      VARCHAR(31),
            email_s         VARCHAR(63),
            phone_s         VARCHAR(31),
            nickname_s      VARCHAR(63),
            company_s       VARCHAR(63),
            address1_s      VARCHAR(63),
            address2_s      VARCHAR(63),
            city_s          VARCHAR(63),
            state_sa        VARCHAR(2),
            post_s          VARCHAR(31),
            birthday_d      DATE,
            memo_s          TEXT,
            square_id_s     VARCHAR(32),
            source_s        VARCHAR(63),
            vfirst_d        DATE,
            vlast_d         DATE,
            transactions_i  INT,
            spent_d         DECIMAL(12,2),
            unsubscribed_b  BOOLEAN,
            instant_b       BOOLEAN
             )
BEGIN
        DECLARE _now        DATETIME default now();





        UPDATE `mcc_customer`.`sq_customers`
            SET
                `reference_id`  = reference_id_i,
                `first_name`    = firstname_s,
                `last_name`     = lastname_s,
                `email`         = email_s,
                `phone`         = phone_s,
                `nickname`      = nickname_s,
                `company`       = company_s,
                `address1`      = address1_s,
                `address2`      = address2_s,
                `city`          = city_s,
                `state`         = state_sa,
                `post`          = post_s,
                `birthday`      = birthday_d,
                `memo`          = CONCAT( memo_s, "\r\nUpdated by VB:Merge at: ", _now ),
                `square_id`     = square_id_s,
                `source`        = 'VB:Merge',
                `vfirst`        = vfirst_d,
                `vlast`         = vlast_d,
                `transactions`  = transactions_i,
                `spent`         = spent_d,
                `unsubscribed`  = unsubscribed_b,
                `instant`       = instant_b
            WHERE
                `id`=sq_rid;

        INSERT INTO `mcc_customer`.`sq_customer_merge_history`
                    ( `vb_cid`, `square_rids`, `merged_on` )
            VALUES  ( reference_id_i, CONCAT( sq_rid,'' ), _now );

        UPDATE `mcc_customer`.`sq_customer_status`
            SET  `status`='merged' WHERE `square_rid`=sq_rid;

END; //
DELIMITER ;
show warnings;


-- Procedure vb_total_customers_orders() should have been called prior to merging
-- 
--
DELIMITER //
 DROP PROCEDURE IF EXISTS sq_merge_customer_data //
 CREATE PROCEDURE sq_merge_customer_data( vb_cid SMALLINT, match_cnt TINYINT UNSIGNED, match_level TINYINT UNSIGNED, match_ids VARCHAR(63))
 BEGIN
    DECLARE o               VARCHAR(1) DEFAULT ',';
    DECLARE area            VARCHAR(3) DEFAULT @DEFAULT_AREACODE;
    DECLARE country         VARCHAR(2) DEFAULT @DEFAULT_COUNTRY_A;
    DECLARE i,j,n,m  	    INT;
    DECLARE sq_rid          INT;
-- Square fields
    DECLARE 	    reference_id_r  	INT;
    DECLARE         first_name_r     	VARCHAR(63);
    DECLARE 	    last_name_r      	VARCHAR(63);
    DECLARE 	    email_r         	VARCHAR(63);
    DECLARE 	    phone_r         	VARCHAR(63);
    DECLARE 	    nickname_r      	VARCHAR(63);
    DECLARE 	    company_r       	VARCHAR(63);
    DECLARE 	    address1_r      	VARCHAR(63);
    DECLARE 	    address2_r      	VARCHAR(63);
    DECLARE 	    city_r          	VARCHAR(63);
    DECLARE 	    state_r      	VARCHAR(63);
    DECLARE 	    post_r          	VARCHAR(15);
    DECLARE 	    birthday_r      	DATE;
    DECLARE 	    memo_r          	TEXT;
    DECLARE         square_id_r     	VARCHAR(63);
    DECLARE 	    source_r        	VARCHAR(63);
    DECLARE 	    vfirst_r        	DATE;
    DECLARE 	    vlast_r         	DATE;
    DECLARE 	    transactions_r  	INT;
    DECLARE 	    spent_r         	DECIMAL(12,2);
    DECLARE 	    unsubscribed_r  	BOOLEAN;
    DECLARE 	    instant_r       	BOOLEAN;
    DECLARE         sq_rid_r            INT;        -- not part of square record, just our local id
-- New values
    DECLARE 	    reference_id_n  	INT;
    DECLARE         first_name_n     	VARCHAR(63);
    DECLARE 	    last_name_n      	VARCHAR(63);
    DECLARE 	    email_n         	VARCHAR(63);
    DECLARE 	    phone_n         	VARCHAR(63);
    DECLARE 	    nickname_n      	VARCHAR(63);
    DECLARE 	    company_n       	VARCHAR(63);
    DECLARE 	    address1_n      	VARCHAR(63);
    DECLARE 	    address2_n      	VARCHAR(63);
    DECLARE 	    city_n          	VARCHAR(63);
    DECLARE 	    state_n      	VARCHAR(63);
    DECLARE 	    post_n          	VARCHAR(15);
    DECLARE 	    birthday_n      	DATE;
    DECLARE 	    memo_n          	TEXT;
    DECLARE         square_id_n     	VARCHAR(63);
    DECLARE 	    source_n        	VARCHAR(63);
    DECLARE 	    vfirst_n        	DATE;
    DECLARE 	    vlast_n         	DATE;
    DECLARE 	    transactions_n  	INT;
    DECLARE 	    spent_n         	DECIMAL(12,2);
    DECLARE 	    unsubscribed_n  	BOOLEAN;
    DECLARE 	    instant_n       	BOOLEAN;

--  VB Regular fields...
    DECLARE vb_cid_r        INT DEFAULT NULL;
    DECLARE vb_country_r    VARCHAR(63);
    DECLARE vb_email_r,
            vb_phone_r,
            vb_first_name_r,
            vb_last_name_r  VARCHAR(63);
    DECLARE vb_pin_r,
            vb_ujid_r       INT;
    DECLARE vb_cfields_r    JSON;
--  VB "custom" fields
    DECLARE vb_order_name,
            vb_order_email,
            vb_order_phone,
            vb_order_address,
            vb_order_city,
            vb_order_state,
            vb_order_zipcode,
            vb_country      VARCHAR(63);
    DECLARE vb_total        DECIMAL(12,2);
    DECLARE vb_vfirst,
            vb_vlast        DATE;
    DECLARE vb_orders       SMALLINT    DEFAULT 0;
    DECLARE vb_square_id    VARCHAR(63);
    DECLARE vb_LastNames,   -- lists
            vb_FirstNames,
            vb_Emails,
            vb_Phones       VARCHAR(255);

    DECLARE done boolean default 0;
    DECLARE cur2 CURSOR FOR
    select  `t1`.*,
            `t2`.*,
            cfield_get('ORDER_NAME',`t2`.`cfields`),
            cfield_get('ORDER_EMAIL',`t2`.`cfields`),
            cfield_get('ORDER_PHONE',`t2`.`cfields`),
            cfield_get('ORDER_ADDRESS',`t2`.`cfields`),
            cfield_get('ORDER_CITY',`t2`.`cfields`),
            cfield_get('ORDER_STATE',`t2`.`cfields`),
            cfield_get('ORDER_ZIPCODE',`t2`.`cfields`),            
            cfield_get('COUNTRY',`t2`.`cfields`),
            cfield_get('TOTAL',`t2`.`cfields`),
            cfield_get('VFIRST',`t2`.`cfields`),
            cfield_get('VLAST',`t2`.`cfields`),
            cfield_get('ORDERS',`t2`.`cfields`),
            cfield_get('SQUARE_ID',`t2`.`cfields`),
            cfield_get_array('FIRST_NAMES',`t2`.`cfields`,o),
            cfield_get_array('LAST_NAMES',`t2`.`cfields`,o),
            cfield_get_array('EMAILS',`t2`.`cfields`,o),
            cfield_get_array('PHONES',`t2`.`cfields`,o)
        from `mcc_customer`.`sq_customers` as `t1`
        left join `6rw_vikbooking_customers` as `t2`
            on `t2`.`id`=vb_cid
        where find_in_set(`t1`.`id`, match_ids );

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN cur2;

read_loop:
    LOOP
        FETCH cur2
            INTO
            reference_id_r,
            first_name_r,
            last_name_r,
            email_r,
            phone_r,
            nickname_r,
            company_r,
            address1_r,
            address2_r,
            city_r,
            state_r,
            post_r,
            birthday_r,
            memo_r,
            square_id_r,
            source_r,
            vfirst_r,
            vlast_r,
            transactions_r,
            spent_r,
            unsubscribed_r,
            instant_r,
            sq_rid_r,
            -- vb cust
            vb_cid_r,
            vb_first_name_r,
            vb_last_name_r,
            vb_email_r,
            vb_phone_r,
            vb_country_r,
            vb_cfields_r,
            vb_pin_r,
            vb_ujid_r,
            -- vb cfields
            vb_order_name,
            vb_order_email,
            vb_order_phone,
            vb_order_address,
            vb_order_city,
            vb_order_state,
            vb_order_zipcode,
            vb_country,
            vb_total,
            vb_vfirst,
            vb_vlast,
            vb_orders,
            vb_square_id,
            vb_FirstNames,
            vb_LastNames,
            vb_Emails,
            vb_Phones;

        IF (done) THEN LEAVE read_loop; END IF;

-- Merge VB fields
        set reference_id_n  = vb_cid;
        set first_name_n    = utility.merge_value_str(first_name_r,vb_first_name_r,'');
        set last_name_n     = utility.merge_value_str(last_name_r,vb_last_name_r,''); 
        set email_n         = utility.merge_value_str(email_r,vb_email_r,'');
        set phone_n         = utility.merge_value_str(phone_r,vb_phone_r,'');
        set nickname_n      = nickname_r;
        set company_n       = company_r;
        if ( locate(',',vb_order_address)) then
            set address1_n  = TRIM(utility.merge_value_str(address1_r,SUBSTRING_INDEX(vb_order_address,',',1),''));
            set address2_n  = TRIM(utility.merge_value_str(address1_r,SUBSTRING_INDEX(vb_order_address,',',-1),''));
        else
            set address1_n  = utility.merge_value_str(address1_r,vb_order_address,'');
            set address2_n  = address2_r;
        end if;
        set city_n = utility.merge_value_str(city_r,vb_order_city,'');
        if ( state_r is null and vb_order_state is not null) then
            set state_n     = vb_order_state;
        else
            if ( NOT (vb_order_state is null and vb_order_zipcode is null
                      and post_r is null) and state_r is null ) then
            set state_n     = utility.merge_value_str_shortest(state_r,
                                              location.lookup_zip_state_a(ifnull(post_r,vb_order_zipcode)),
                                              location.lookup_areacode_state_name2(vb_order_state));
            end if;
        end if;
        set post_n          = utility.merge_value_str(post_r,vb_order_zipcode,'');
        set birthday_n      = birthday_r;
        set memo_n          = memo_r;
        set square_id_n     = square_id_r;
        set source_n        = source_r;
        IF ( DATEDIFF( vb_vfirst, vfirst_r ) < 0 ) THEN                 -- If data is from earlier period
            SET vfirst_n    = IFNULL(vb_vfirst,vfirst_r);                  -- Set to earlier date from VB
            SET transactions_n  = IFNULL(transactions_r,0) + IFNULL(vb_orders,0); -- Update accumulations
            SET spent_n     = spent_r + IFNULL(vb_total,0.0);
        ELSE
            set vfirst_n    = vfirst_r;
            set transactions_n = transactions_r;
            set spent_n     = spent_r;
        END IF;
        set vlast_n         = vlast_r;                                          -- Should not update
        set unsubscribed_n  = unsubscribed_r;
        set instant_n       = instant_r;

 call sq_customer_update(
            sq_rid_r,
            reference_id_n,
            first_name_n,
            last_name_n,
            email_n,
            phone_n,
            nickname_n,
            company_n,
            address1_n,
            address2_n,
            city_n,
            state_n,
            post_n,
            birthday_n,
            memo_n,
            square_id_n,
            source_n,
            vfirst_n,
            vlast_n,
            transactions_n,
            spent_n,
            unsubscribed_n,
            instant_n
            );

    END LOOP;

END; //
DELIMITER ;
show warnings;

--  Select matched square/vb records based on
--  type of match ( match level )
--  send to merge
--
DELIMITER //
 DROP PROCEDURE IF EXISTS sq_merge_customer_select //
 CREATE PROCEDURE sq_merge_customer_select(list BOOLEAN)
start1:
 BEGIN
    DECLARE vb_cid_r,
            match_cnt_r,
            match_level_r INT UNSIGNED;
    DECLARE match_ids_r   VARCHAR(63);

    DECLARE done boolean default 0;
    DECLARE cur2 CURSOR FOR select
        `t1`.`vb_cid` as vb_cid,
        count(distinct `t1`.`square_rid`) as match_cnt,
        min(`t1`.`type`) as match_level,
        group_concat(distinct `t1`.`square_rid`) match_ids
        from `mcc_customer`.`sq_customer_vb_matches` as `t1`
        left join `mcc_customer`.`sq_customers` as t2 on t2.id=t1.square_rid
        where t2.reference_id is null
        group by `t1`.`vb_cid`
        having match_cnt=1 and match_level<=3;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    if (list) then                  -- Print list of customers to merge
        select
            `t1`.`vb_cid` as vb_cid,
            count(distinct `t1`.`square_rid`) as mcnt,
            min(`t1`.`type`) as mlevel,
            group_concat(distinct `t1`.`square_rid`) matched,
            t3.first_name as vb_name1,
            t3.last_name as vb_name2,
            t3.email as vb_email,
            t3.phone as vb_phone,
            group_concat(distinct t2.first_name) as sq_name1,
            group_concat(distinct t2.last_name)  as sq_name2,
            group_concat(distinct t2.email) as sq_email,
            group_concat(distinct t2.phone) as sq_phone
            from `mcc_customer`.`sq_customer_vb_matches` as `t1`
            left join `mcc_customer`.`sq_customers` as t2 on t2.id=t1.square_rid
            left join `6rw_vikbooking_customers` as t3 on t3.id=t1.vb_cid
            where t2.reference_id is null
            group by `t1`.`vb_cid`
            having mcnt=1 and mlevel<=3
            order by t3.last_name, t3.first_name;

        leave start1;
    end if;

    OPEN cur2;

read_loop:
    LOOP
        set vb_cid_r=null, match_cnt_r=null, match_level_r=0, match_ids_r=null;  
        FETCH cur2 INTO vb_cid_r,match_cnt_r,match_level_r,match_ids_r;
        IF (done) THEN LEAVE read_loop; END IF;
--        select "Merge: " as '', vb_cid_r as 'VB-custid' , match_cnt_r as matches, match_level_r as 'level', match_ids_r as 'Square-custrid'; 
        call sq_merge_customer_data(vb_cid_r,match_cnt_r,match_level_r,match_ids_r);
-- LEAVE start1;
    END LOOP;

END; //
DELIMITER ;
show warnings;

-- Procedure vb_total_customers_orders() should have been called prior to creating
-- 
--
DELIMITER //
 DROP PROCEDURE IF EXISTS sq_customer_create //
 CREATE PROCEDURE sq_customer_create(vb_cid SMALLINT UNSIGNED)
 BEGIN
    DECLARE o               VARCHAR(1) DEFAULT ',';
    DECLARE area            VARCHAR(3) DEFAULT @DEFAULT_AREACODE;
    DECLARE country         VARCHAR(2) DEFAULT @DEFAULT_COUNTRY_A;
    DECLARE i,j,n,m  	    INT;
    DECLARE sq_rid          INT;
-- Square fields
    DECLARE 	    reference_id_n  	INT;
    DECLARE         first_name_n     	VARCHAR(63);
    DECLARE 	    last_name_n      	VARCHAR(63);
    DECLARE 	    email_n         	VARCHAR(63);
    DECLARE 	    phone_n         	VARCHAR(63);
    DECLARE 	    nickname_n      	VARCHAR(63);
    DECLARE 	    company_n       	VARCHAR(63);
    DECLARE 	    address1_n      	VARCHAR(63);
    DECLARE 	    address2_n      	VARCHAR(63);
    DECLARE 	    city_n          	VARCHAR(63);
    DECLARE 	    state_n      	VARCHAR(63);
    DECLARE 	    post_n          	VARCHAR(15);
    DECLARE 	    birthday_n      	DATE;
    DECLARE 	    memo_n          	TEXT;
    DECLARE         square_id_n     	VARCHAR(63);
    DECLARE 	    source_n        	VARCHAR(63);
    DECLARE 	    vfirst_n        	DATE;
    DECLARE 	    vlast_n         	DATE;
    DECLARE 	    transactions_n  	INT;
    DECLARE 	    spent_n         	DECIMAL(12,2);
    DECLARE 	    unsubscribed_n  	BOOLEAN;
    DECLARE 	    instant_n       	BOOLEAN;

--  VB Regular fields...
    DECLARE vb_cid_r        INT DEFAULT NULL;
    DECLARE vb_country_r    VARCHAR(63);
    DECLARE vb_email_r,
            vb_phone_r,
            vb_first_name_r,
            vb_last_name_r  VARCHAR(63);
    DECLARE vb_pin_r,
            vb_ujid_r       INT;
    DECLARE vb_cfields_r    JSON;
--  VB "custom" fields
    DECLARE vb_order_name,
            vb_order_email,
            vb_order_phone,
            vb_order_address,
            vb_order_city,
            vb_order_state,
            vb_order_zipcode,
            vb_country      VARCHAR(63);
    DECLARE vb_total        DECIMAL(12,2);
    DECLARE vb_vfirst,
            vb_vlast        DATE;
    DECLARE vb_orders       SMALLINT    DEFAULT 0;
    DECLARE vb_square_id    VARCHAR(63);
    DECLARE vb_LastNames,   -- lists
            vb_FirstNames,
            vb_Emails,
            vb_Phones       VARCHAR(255);

    DECLARE done boolean default 0;
    DECLARE cur2 CURSOR FOR
    select  `t1`.*,
            cfield_get('ORDER_NAME',`t1`.`cfields`),
            cfield_get('ORDER_EMAIL',`t1`.`cfields`),
            cfield_get('ORDER_PHONE',`t1`.`cfields`),
            cfield_get('ORDER_ADDRESS',`t1`.`cfields`),
            cfield_get('ORDER_CITY',`t1`.`cfields`),
            cfield_get('ORDER_STATE',`t1`.`cfields`),
            cfield_get('ORDER_ZIPCODE',`t1`.`cfields`),            
            cfield_get('COUNTRY',`t1`.`cfields`),
            cfield_get('TOTAL',`t1`.`cfields`),
            cfield_get('VFIRST',`t1`.`cfields`),
            cfield_get('VLAST',`t1`.`cfields`),
            cfield_get('ORDERS',`t1`.`cfields`),
            cfield_get('SQUARE_ID',`t1`.`cfields`),
            cfield_get_array('FIRST_NAMES',`t1`.`cfields`,o),
            cfield_get_array('LAST_NAMES',`t1`.`cfields`,o),
            cfield_get_array('EMAILS',`t1`.`cfields`,o),
            cfield_get_array('PHONES',`t1`.`cfields`,o)
        from `6rw_vikbooking_customers` as `t1`
            where `t1`.`id`=vb_cid;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN cur2;

read_loop:
    LOOP
        FETCH cur2
            INTO
            -- vb cust
            vb_cid_r,
            vb_first_name_r,
            vb_last_name_r,
            vb_email_r,
            vb_phone_r,
            vb_country_r,
            vb_cfields_r,
            vb_pin_r,
            vb_ujid_r,
            -- vb cfields
            vb_order_name,
            vb_order_email,
            vb_order_phone,
            vb_order_address,
            vb_order_city,
            vb_order_state,
            vb_order_zipcode,
            vb_country,
            vb_total,
            vb_vfirst,
            vb_vlast,
            vb_orders,
            vb_square_id,
            vb_FirstNames,
            vb_LastNames,
            vb_Emails,
            vb_Phones;

        IF (done) THEN LEAVE read_loop; END IF;

-- Transfer VB fields
        set reference_id_n  = vb_cid;
        set first_name_n    = vb_first_name_r;
        set last_name_n     = vb_last_name_r; 
        set email_n         = vb_email_r;
        set phone_n         = vb_phone_r;
        set nickname_n      = null;
        set company_n       = null;
        if ( locate(',',vb_order_address)) then
            set address1_n  = TRIM(SUBSTRING_INDEX(vb_order_address,',',1));
            set address2_n  = TRIM(SUBSTRING_INDEX(vb_order_address,',',-1));
        else
            set address1_n  = vb_order_address;
            set address2_n  = null;
        end if;
        set city_n          = vb_order_city;
        set state_n         = vb_order_state;
        set post_n          = vb_order_zipcode;
        set birthday_n      = null;
        set memo_n          = null;
        set square_id_n     = null;
        set source_n        = 'VB:import';
        SET vfirst_n        = vb_vfirst;                  -- Set to earlier date from VB
        SET transactions_n  = vb_orders; -- Update accumulations
        SET spent_n         = vb_total;
        set vlast_n         = vb_vlast;                                          -- Should not update
        set unsubscribed_n  = 0;
        set instant_n       = 0;

        call sq_customer_save(
            sq_rid,
            reference_id_n,
            first_name_n,
            last_name_n,
            email_n,
            phone_n,
            nickname_n,
            company_n,
            address1_n,
            address2_n,
            city_n,
            state_n,
            post_n,
            birthday_n,
            memo_n,
            square_id_n,
            source_n,
            vfirst_n,
            vlast_n,
            transactions_n,
            spent_n,
            unsubscribed_n,
            instant_n
            );

    END LOOP;

END; //
DELIMITER ;
show warnings;


--  Select matched square/vb records based on

--
DELIMITER //
 DROP PROCEDURE IF EXISTS sq_create_customer_select //
 CREATE PROCEDURE sq_create_customer_select(list BOOLEAN)
start1:
 BEGIN
    DECLARE vb_cid_r    INT UNSIGNED;
    DECLARE done        boolean default 0;
    DECLARE cur2        CURSOR FOR select
                        `t1`.`id` as vb_cid
                        from `6rw_vikbooking_customers` as `t1`
                        left join `mcc_customer`.`sq_customer_vb_matches` as `t2`
                            on `t2`.`vb_cid` = `t1`.`id`
                        where
                            `t2`.`id` is null
                            and (
                                `t1`.`email` is not null
                             or `t1`.`phone` is not null
                                );

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    if (list) then      -- Print list of customers to create
        select
            `t1`.`id` as vb_cid,
            `t1`.`first_name` as vb_name1,
            `t1`.`last_name` as vb_name2,
            `t1`.`email` as vb_email,
            `t1`.`phone` as vb_phone,
            cfield_get('TOTAL',`t1`.`cfields`) as spend,
            cfield_get('VFIRST',`t1`.`cfields`) as firstseen,
            cfield_get('VLAST',`t1`.`cfields`) as lastseen,
            cfield_get('ORDERS',`t1`.`cfields`) as orders
            from `6rw_vikbooking_customers` as `t1`
            left join `mcc_customer`.`sq_customer_vb_matches` as `t2`
                on `t2`.`vb_cid` = `t1`.`id`
            where
                `t2`.`id` is null
                and (
                       `t2`.`email` is not null
                    or `t2`.`phone` is not null
                    )
            order by `t1`.`last_name`, `t1`.`first_name`;
        leave start1;
    end if;

    OPEN cur2;

read_loop:
    LOOP
        set vb_cid_r=null;  
        FETCH cur2 INTO vb_cid_r;
        IF (done) THEN LEAVE read_loop; END IF;
        call sq_customer_create(vb_cid_r);
    END LOOP;

END; //
DELIMITER ;
show warnings;


DELIMITER // 
 DROP PROCEDURE IF EXISTS sq_match_customers_extract //
 CREATE PROCEDURE         sq_match_customers_extract()
 BEGIN
    DECLARE o               VARCHAR(1) DEFAULT '|';
    DECLARE done            BOOLEAN DEFAULT 0;
    DECLARE extracted       INT DEFAULT 0;
    DECLARE pname,
            pname_first,
            pname_last,
            email,
            phone           VARCHAR(63);

-- Square fields
    DECLARE 	    reference_id_r  	INT;
    DECLARE         first_name_r     	VARCHAR(63);
    DECLARE 	    last_name_r      	VARCHAR(63);
    DECLARE 	    email_r         	VARCHAR(63);
    DECLARE 	    phone_r         	VARCHAR(63);
    DECLARE 	    nickname_r      	VARCHAR(63);
    DECLARE 	    company_r       	VARCHAR(63);
    DECLARE 	    address1_r      	VARCHAR(63);
    DECLARE 	    address2_r      	VARCHAR(63);
    DECLARE 	    city_r          	VARCHAR(31);
    DECLARE 	    state_sa_r      	VARCHAR(31);
    DECLARE 	    post_r          	VARCHAR(15);
    DECLARE 	    birthday_r      	DATE;
    DECLARE 	    memo_r          	TEXT;
    DECLARE         square_id_r     	VARCHAR(63);
    DECLARE 	    source_r        	VARCHAR(63);
    DECLARE 	    vfirst_r        	DATE;
    DECLARE 	    vlast_r         	DATE;
    DECLARE 	    transactions_r  	INT;
    DECLARE 	    spent_r         	DECIMAL(12,2);
    DECLARE 	    unsubscribed_r  	BOOLEAN;
    DECLARE 	    instant_r       	BOOLEAN;
    DECLARE 	    sq_rid_r        	INT;

    DECLARE cur2 CURSOR FOR SELECT
                                sq.reference_id,
                                sq.first_name,
                                sq.last_name,
                                sq.email,
                                sq.phone,
                                sq.address1,
                                sq.address2,
                                sq.city,
                                sq.`state`,
                                sq.post,
                                sq.transactions,
                                sq.spent,
                                sq.vfirst,
                                sq.vlast,
                                sq.`source`,
                                sq.memo,
                                sq.id
                            FROM `mcc_customer`.`sq_customers` as sq
                            WHERE
                                (  sq.first_name is not null
                                OR sq.last_name is not null
                                OR sq.email is not null
                                OR sq.phone is not null )
                                AND reference_id is null;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
    OPEN cur2;

read_loop:
    LOOP
        FETCH cur2 INTO
                reference_id_r,first_name_r,last_name_r,email_r,phone_r,address1_r,address2_r,
                city_r,state_sa_r,post_r,transactions_r,spent_r,vfirst_r,vlast_r,source_r,memo_r,sq_rid_r;

        IF (done) THEN LEAVE read_loop; END IF;

--        SELECT sq_rid_r,first_name_r,last_name_r,email_r,phone_r,address1_r,address2_r,city_r,state_sa_r,post_r, transactions_r,spent_r,vfirst_r;

        -- Shard identifing info
        
        SET pname = utility.parsename(CONCAT(first_name_r,' ',last_name_r),o);
        SET pname_first = SUBSTRING_INDEX(pname,o,1);
        SET pname_last  = SUBSTRING_INDEX(pname,o,-1);

        IF ( pname_first != '' ) THEN
            CALL sq_store_name1( sq_rid_r, pname_first );
        END IF;
        IF ( pname_last != '' ) THEN
            CALL sq_store_name2( sq_rid_r, pname_last);
        END IF;

        SET email = utility.normemail(email_r);
        IF ( email != '') THEN
            CALL sq_store_email( sq_rid_r, email);
        END IF;

        SET phone = normphone( phone_r, @DEFAULT_AREACODE, @DEFAULT_COUNTRY_A );
        IF ( phone != '' ) THEN
            CALL sq_store_phone( sq_rid_r, phone);
        END IF;

        INSERT INTO `mcc_customer`.`sq_customer_status`
            ( `square_rid`, `status` )
            VALUES ( sq_rid_r,'extracted' )
            ON DUPLICATE KEY UPDATE `status`='extracted';

        SET extracted = extracted + 1;
    END LOOP;

    close cur2;

    select 'sq_match_customers_extract()' as proc, extracted;
END;//
DELIMITER ;
show warnings;



DELIMITER // 
 DROP PROCEDURE IF EXISTS sq_store_email //
 CREATE PROCEDURE         sq_store_email( order_id SMALLINT, email VARCHAR(63) )
 BEGIN
    DECLARE email_exists    BOOLEAN DEFAULT 0;
    DECLARE id_email,c      SMALLINT UNSIGNED;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET email_exists = 1;

    INSERT INTO `vb_emails` (`email`) VALUE (email);

    IF ( email_exists ) THEN
        SELECT `t1`.`id` INTO id_email FROM `vb_emails` as `t1` WHERE `t1`.`email` = email;
        SELECT count(*) into c from `vb_orders_emails` where `idorder`=order_id and `email_id`=id_email;
        IF ( c=0 ) THEN
            INSERT INTO `mcc_customer`.`sq_customers_emails` VALUES ( order_id, id_email );
        END IF;
    ELSE
        SET id_email = LAST_INSERT_ID();
        INSERT INTO `mcc_customer`.`sq_customers_emails` VALUES ( order_id, id_email );
    END IF;

END;//
DELIMITER ;
show warnings;

DELIMITER // 
 DROP PROCEDURE IF EXISTS sq_store_phone //
 CREATE PROCEDURE         sq_store_phone( order_id SMALLINT, phone VARCHAR(63) )
 BEGIN
    DECLARE phone_exists    BOOLEAN DEFAULT 0;
    DECLARE id_phone,c      SMALLINT UNSIGNED;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET phone_exists = 1;

    INSERT INTO `vb_phones` (`phone`) VALUE (phone);

    IF ( phone_exists ) THEN
        SELECT `t1`.`id` INTO id_phone FROM `vb_phones` as `t1` WHERE `t1`.`phone` = phone;
        SELECT count(*) into c from `vb_orders_phones` as `t1` where `t1`.`idorder`=order_id and `t1`.`phone_id`=id_phone;
        IF ( c=0 ) THEN
            INSERT INTO `mcc_customer`.`sq_customers_phones` VALUES ( order_id, id_phone );
        END IF;
    ELSE
        SET id_phone = LAST_INSERT_ID();
        INSERT INTO `mcc_customer`.`sq_customers_phones` VALUES ( order_id, id_phone );
    END IF;

END;//
DELIMITER ;
show warnings;

DELIMITER // 
 DROP PROCEDURE IF EXISTS sq_store_name1 //
 CREATE PROCEDURE         sq_store_name1( order_id SMALLINT, name1 VARCHAR(63) )
 BEGIN
    DECLARE name_exists    BOOLEAN DEFAULT 0;
    DECLARE id_name,c      SMALLINT UNSIGNED;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET name_exists = 1;

    INSERT INTO `vb_name1` (name) VALUE (name1);

    IF ( name_exists ) THEN
        SELECT `t1`.`id` INTO id_name FROM `vb_name1` as `t1` WHERE `t1`.`name` = name1;
        SELECT count(*) into c from `vb_orders_name1` as t1 where `t1`.`idorder`=order_id and `t1`.`name_id`=id_name;
        IF ( c=0 ) THEN
            INSERT INTO `mcc_customer`.`sq_customers_name1` VALUES ( order_id, id_name );
        END IF;
    ELSE
        SET id_name = LAST_INSERT_ID();
        INSERT INTO `mcc_customer`.`sq_customers_name1` VALUES ( order_id, id_name );
    END IF;

END;//
DELIMITER ;
show warnings;

DELIMITER // 
 DROP PROCEDURE IF EXISTS sq_store_name2 //
 CREATE PROCEDURE         sq_store_name2( order_id SMALLINT, name2 VARCHAR(63) )
 BEGIN
    DECLARE name_exists    BOOLEAN DEFAULT 0;
    DECLARE id_name,c      SMALLINT UNSIGNED;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET name_exists = 1;

    INSERT INTO `vb_name2` (name) VALUE (name2);

    IF ( name_exists ) THEN
        SELECT `t1`.`id` INTO id_name FROM `vb_name2` as `t1` WHERE `t1`.`name`=name2;
        SELECT count(*) into c from `vb_orders_name2` as `t1` where `t1`.`idorder`=order_id and `t1`.`name_id`=id_name;
        IF ( c=0 ) THEN
            INSERT INTO `mcc_customer`.`sq_customers_name2` VALUES ( order_id, id_name );
        END IF;
    ELSE
        SET id_name = LAST_INSERT_ID();
        INSERT INTO `mcc_customer`.`sq_customers_name2` VALUES ( order_id, id_name );
    END IF;

END;//
DELIMITER ;
show warnings;

DELIMITER //
 DROP PROCEDURE IF EXISTS sq_match_customers_vb //
 CREATE PROCEDURE sq_match_customers_vb()
 BEGIN
    DECLARE sq_rid  INT UNSIGNED;
    DECLARE done    BOOLEAN default 0;
    DECLARE cur2    CURSOR FOR
                    SELECT `square_rid`
                    FROM `mcc_customer`.`sq_customer_vb_matches` as t1;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    TRUNCATE `mcc_customer`.`sq_customer_vb_matches`;

-- Match on email
    INSERT INTO `mcc_customer`.`sq_customer_vb_matches` (`vb_cid`, `square_rid`, `type` )
        SELECT `t2`.`idcustomer`, `t1`.`square_rid`, 1
            from `mcc_customer`.`sq_customers_emails` as `t1`
            join `vb_customers_emails` as `t2` on find_in_set(`t1`.`email_id`,`t2`.`email_ids`) ;

-- Phone
    INSERT INTO `mcc_customer`.`sq_customer_vb_matches` (`vb_cid`, `square_rid`, `type` )
        SELECT `t2`.`idcustomer`, `t1`.`square_rid`, 2
            from `mcc_customer`.`sq_customers_phones` as `t1`
            join `vb_customers_phones` as `t2` on find_in_set(`t1`.`phone_id`,`t2`.`phone_ids`) ;

-- First, last
    INSERT INTO `mcc_customer`.`sq_customer_vb_matches` (`vb_cid`, `square_rid`, `type` )
        SELECT `t3`.`idcustomer`, `t1`.`square_rid`, 3
            from `mcc_customer`.`sq_customers_name1` as `t1`
            join `mcc_customer`.`sq_customers_name2` as `t2` on `t2`.`square_rid`=`t1`.`square_rid`
            join `vb_customers_name1` as `t3` on `t3`.`idcustomer` = `t3`.`idcustomer`
            join `vb_customers_name2` as `t4` on `t4`.`idcustomer` = `t3`.`idcustomer`
            where find_in_set(`t1`.`name_id`,`t3`.`name_ids`) and find_in_set(`t2`.`name_id`,`t4`.`name_ids`);

    -- print matches...
    select 'sq_match_customers_vb(): VB customer matches' as info;
    select * from `mcc_customer`.`sq_customer_vb_matches`;

    -- log
    open cur2;
read_loop:
    LOOP
        fetch cur2 into sq_rid;
        IF (done) THEN LEAVE read_loop; END IF;
        update `mcc_customer`.`sq_customer_status`
            set `status` = 'matched'
            where `square_rid` = sq_rid;
    END LOOP;
    close cur2;

END;//
DELIMITER ;
show warnings;

-- Additional match types not in use
-- -- Last, First
--   INSERT INTO `mcc_customer`.`sq_customer_vb_matches` (`vb_cid`, `square_rid`, `type` )
--         SELECT `t3`.`idcustomer`, `t1`.`square_rid`, 4
--             from `mcc_customer`.`sq_customers_name1` as `t1`
--             join `mcc_customer`.`sq_customers_name2` as `t2` on `t2`.`square_rid`=`t1`.`square_rid`
--             join `vb_customers_name1` as `t3` 
--             join `vb_customers_name2` as `t4`
--             where find_in_set(`t1`.`name_id`,`t4`.`name_ids`) and find_in_set(`t2`.`name_id`,`t3`.`name_ids`);
--  
-- 
-- -- Last name
--    INSERT INTO `mcc_customer`.`sq_customer_vb_matches` (`vb_cid`, `square_rid`, `type` )
--         SELECT `t2`.`idcustomer`, `t1`.`square_rid`, 5
--             from `mcc_customer`.`sq_customers_name2` as `t1`
--             join `vb_customers_name2` as `t2` on find_in_set(`t1`.`name_id`,`t2`.`name_ids`);
-- 
-- -- First
--    INSERT INTO `mcc_customer`.`sq_customer_vb_matches` (`vb_cid`, `square_rid`, `type` )
--         SELECT `t2`.`idcustomer`, `t1`.`square_rid`, 6
--             from `mcc_customer`.`sq_customers_name1` as `t1`
--             join `vb_customers_name1` as `t2` on find_in_set(`t1`.`name_id`,`t2`.`name_ids`);
-- 
-- -- Names reversed
-- -- Last name
--    INSERT INTO `mcc_customer`.`sq_customer_vb_matches` (`vb_cid`, `square_rid`, `type` )
--         SELECT `t2`.`idcustomer`, `t1`.`square_rid`, 7
--             from `mcc_customer`.`sq_customers_name2` as `t1`
--             join `vb_customers_name1` as `t2` on find_in_set(`t1`.`name_id`,`t2`.`name_ids`);
-- 
-- -- First
--    INSERT INTO `mcc_customer`.`sq_customer_vb_matches` (`vb_cid`, `square_rid`, `type` )
--         SELECT `t2`.`idcustomer`, `t1`.`square_rid`, 8
--             from `mcc_customer`.`sq_customers_name1` as `t1`
--             join `vb_customers_name2` as `t2` on find_in_set(`t1`.`name_id`,`t2`.`name_ids`);

DELIMITER //
 DROP PROCEDURE IF EXISTS sq_match_customers //
 CREATE PROCEDURE sq_match_customers()
 BEGIN
    DECLARE sq_rids VARCHAR(63);
    DECLARE done    BOOLEAN default 0;
    DECLARE cur2    CURSOR FOR
                    SELECT `square_rids`
                    FROM `mcc_customer`.`sq_customer_matches` as t1;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

   TRUNCATE `mcc_customer`.`sq_customer_matches`;

-- Match on email
   INSERT INTO `mcc_customer`.`sq_customer_matches` (`mcnt`,`type`, `square_rids` )
        SELECT  
            count(`t1`.`square_rid`) as mcnt,
            1,
            group_concat(distinct `t1`.`square_rid`)
            from `mcc_customer`.`sq_customers_emails` as `t1`
            join `mcc_customer`.`sq_customers` as t2 on t2.id=t1.square_rid
            where t2.email is not null and t2.reference_id is null
            group by t1.email_id
            having mcnt>1;

-- Phone
   INSERT INTO `mcc_customer`.`sq_customer_matches` (`mcnt`,`type`, `square_rids` )
        SELECT  
            count(`t1`.`square_rid`) as mcnt,
            2,
            group_concat(distinct `t1`.`square_rid`)
            from `mcc_customer`.`sq_customers_phones` as `t1`
            join `mcc_customer`.`sq_customers` as t2 on t2.id=t1.square_rid
            where t2.phone is not null and t2.reference_id is null
            group by t1.phone_id
            having mcnt>1;

-- First, last
    INSERT INTO `mcc_customer`.`sq_customer_matches` ( `mcnt`,`type`, `square_rids`  )
        SELECT
            count(`t1`.`square_rid`) as mcnt,
            3,
            group_concat(distinct `t1`.`square_rid`)
            from
                `mcc_customer`.`sq_customers_name1` as `t1`
                join `mcc_customer`.`sq_customers_name2` as `t2` on t2.square_rid=t1.square_rid
                join `mcc_customer`.`sq_customers` as t3 on t3.id=t1.square_rid
            where t3.first_name is not null and t3.reference_id is null
            group by t1.name_id,t2.name_id
            having mcnt>1;

    -- print duplicates...
    select 'sq_match_customers(): Possible Square duplicates' as info;
    select * from `mcc_customer`.`sq_customer_matches`;

    -- log
    open cur2;
read_loop:
    LOOP
        fetch cur2 into sq_rids;
        IF (done) THEN LEAVE read_loop; END IF;
        update `mcc_customer`.`sq_customer_status`
            set `status` = 'duplicate'
            where find_in_set(`square_rid`,sq_rids );
    END LOOP;
    close cur2;    

END;//
DELIMITER ;
show warnings;


DELIMITER // 
    DROP PROCEDURE IF EXISTS sq_match_customers_reset //
    CREATE PROCEDURE         sq_match_customers_reset()
BEGIN

    TRUNCATE `mcc_customer`.sq_customers_emails;
    TRUNCATE `mcc_customer`.sq_customers_name1;
    TRUNCATE `mcc_customer`.sq_customers_name2;
    TRUNCATE `mcc_customer`.sq_customers_phones;
    TRUNCATE `mcc_customer`.sq_customer_status;
    TRUNCATE `mcc_customer`.sq_customer_matches;
    TRUNCATE `mcc_customer`.sq_customer_vb_matches;
    TRUNCATE `mcc_customer`.sq_customers;

--    TRUNCATE `mcc_customer`.`sq_customer_merge_history`;   -- do this manually

END;
 //
DELIMITER ;
show warnings;



DELIMITER // 
    DROP PROCEDURE IF EXISTS sq_match_customers_init //
    CREATE PROCEDURE         sq_match_customers_init()
BEGIN

    DROP TABLE IF EXISTS `mcc_customer`.`sq_customers_emails`;
    DROP TABLE IF EXISTS `mcc_customer`.`sq_customers_name1`;
    DROP TABLE IF EXISTS `mcc_customer`.`sq_customers_name2`;
    DROP TABLE IF EXISTS `mcc_customer`.`sq_customers_phones`;
    DROP TABLE IF EXISTS `mcc_customer`.`sq_customer_status`;
    DROP TABLE IF EXISTS `mcc_customer`.`sq_customer_matches`;
    DROP TABLE IF EXISTS `mcc_customer`.`sq_customer_vb_matches`;
    DROP TABLE IF EXISTS `mcc_customer`.`sq_customer_merge_history`;
    DROP TABLE IF EXISTS `mcc_customer`.`sq_customers`;

-- Table to collect order -> email matches
CREATE TABLE IF NOT EXISTS `mcc_customer`.`sq_customers_emails` (
	`square_rid`     SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0 ,
        `email_id`      SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`square_rid`),
	INDEX (`square_rid`,`email_id`)
        ) ENGINE=MYISAM;

-- Table to collect order -> phone matches
CREATE TABLE IF NOT EXISTS `mcc_customer`.`sq_customers_phones` (
	`square_rid`     SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0 ,
        `phone_id`      SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`square_rid`),
	INDEX (`square_rid`,`phone_id`)
        ) ENGINE=MYISAM;

-- Table to collect order -> name1 matches
CREATE TABLE IF NOT EXISTS `mcc_customer`.`sq_customers_name1` (
	`square_rid`     SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0 ,
        `name_id`       SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`square_rid`),
	INDEX (`square_rid`,`name_id`)
        ) ENGINE=MYISAM;

-- Table to collect order -> name2 matches
CREATE TABLE IF NOT EXISTS `mcc_customer`.`sq_customers_name2` (
	`square_rid`     SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0 ,
        `name_id`       SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`square_rid`),
	INDEX (`square_rid`,`name_id`)
        ) ENGINE=MYISAM;

CREATE TABLE IF NOT EXISTS `mcc_customer`.`sq_customer_status` (
	`square_rid`    SMALLINT(4) UNSIGNED UNIQUE NOT NULL DEFAULT 0,
        `status`       ENUM('initial','extracted','matched','duplicate','merged','created','deleted') NOT NULL default 'initial',
        PRIMARY KEY (`square_rid`),
	INDEX (`square_rid`, `status` )
        ) ENGINE=MYISAM;

CREATE TABLE IF NOT EXISTS `mcc_customer`.`sq_customer_matches` (
        `mcnt`          TINYINT UNSIGNED not null,
        `type`          TINYINT UNSIGNED not null,
        `square_rids`   VARCHAR(255)     not null
        ) ENGINE=MYISAM;

CREATE TABLE IF NOT EXISTS `mcc_customer`.`sq_customer_vb_matches` (
        `id`           	INT(10) UNSIGNED NOT NULL auto_increment,
        `vb_cid`        INT(10) UNSIGNED,
        `square_rid`    INT(10) UNSIGNED,
        `type`          TINYINT UNSIGNED,
	PRIMARY KEY (`id`),
        INDEX(`vb_cid`,`square_rid`)
        ) ENGINE=MYISAM;

CREATE TABLE IF NOT EXISTS `mcc_customer`.`sq_customer_merge_history` (
        `id`            INT(10)      UNSIGNED NOT NULL auto_increment,
        `vb_cid`        INT(4)       UNSIGNED NOT NULL,
	`square_rids`   VARCHAR(63)           NOT NULL DEFAULT '',
        `merged_on`     DATETIME              NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
	INDEX (`id`, `vb_cid` )
        ) ENGINE=MYISAM;

END;//
DELIMITER ;
show warnings;


DELIMITER // 
    DROP PROCEDURE IF EXISTS sq_match_customer_relate //
    CREATE PROCEDURE         sq_match_customer_relate( vb_cid SMALLINT UNSIGNED, match_count_limit TINYINT, match_level_limit TINYINT )
start1:
BEGIN
    DECLARE square_rids varchar(127);
    DECLARE mc          TINYINT default 1;
    DECLARE ml          TINYINT default 1;
    DECLARE matches     tinyint;
    DECLARE mlevel      tinyint;
    DECLARE rowc        int default 0;
    DECLARE vb_order_ids varchar(127);
    
    if (match_count_limit is not null) then set mc=match_count_limit; end if;
    if (match_level_limit is not null) then set ml=match_level_limit; end if;
 
    select  count(*),
        count(distinct `t1`.`square_rid`) as match_cnt,
        group_concat(distinct `t1`.`square_rid`) as sq_cust,
        min(`t1`.`type`) as match_level
        into rowc, matches, square_rids, mlevel
        from `mcc_customer`.`sq_customer_vb_matches` as `t1`
        where `t1`.`vb_cid` = vb_cid
        having match_cnt<=mc and match_level<=ml;

    if ( rowc=0 ) then   -- search without some paramaters
        select
            t1.vb_cid,
            count(distinct `t1`.`square_rid`) as match_cnt,
            group_concat(distinct `t1`.`square_rid`),
            min(`t1`.`type`) as match_level
            from `mcc_customer`.`sq_customer_vb_matches` as `t1`
            where `t1`.`vb_cid` = vb_cid
            having match_cnt<=mc+1 and match_level<=ml+1;

        leave start1;
    end if;

    select
        count(distinct `t1`.`square_rid`) as match_cnt,
        group_concat(distinct `t1`.`square_rid`),
        min(`t1`.`type`) as match_level
        into matches, square_rids, mlevel
        from `mcc_customer`.`sq_customer_vb_matches` as `t1`
        where `t1`.`vb_cid` = vb_cid
        group by `t1`.`vb_cid`
        having match_cnt<=mc and match_level<=ml;

    select square_rids, rowc;

    select reference_id as vb_cid,last_name,first_name,email,phone,address1,city,post,vfirst,spent
        from `mcc_customer`.`sq_customers` as `t1`
        where find_in_set(`t1`.`id`,square_rids);

    if ( vb_cid is not null ) then
    call vb_create_customers_show(vb_cid);

    select group_concat(distinct `t1`.`idorder`) into vb_order_ids
        from `6rw_vikbooking_customers_orders` as `t1`
        where `t1`.`idcustomer`=vb_cid;

    call vb_extract_orders_show(vb_order_ids);
    end if;

END;//
DELIMITER ;
show warnings;


    call sq_match_customers_reset();
    source sq_load_data.sql;
    use `montanac_joom899`;
    call sq_match_customers_extract();
    call sq_match_customers();              -- List possibly duplicated square customers
    call sq_match_customers_vb();           -- Connect VB customers to Square
    call sq_merge_customer_select(0);       -- merge VB customer data in to Square
    call sq_create_customer_select(0);      -- Create *new* Square customers that exist in VB only