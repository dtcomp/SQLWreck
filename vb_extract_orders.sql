source global.sql;
source debug.sql;
source vb.sql;




DELIMITER // 
 DROP PROCEDURE IF EXISTS vb_extract_order //
 CREATE PROCEDURE         vb_extract_order(
    idorder         SMALLINT,
    custdata_r      VARCHAR(511),
    custmail_r      VARCHAR(63),
    phone_r         VARCHAR(63),
    country_r       VARCHAR(63),
    paymentlog_r    TEXT,
    
    OUT names_f     VARCHAR(255),
    OUT names_f_cnt TINYINT UNSIGNED,
    OUT names_l     VARCHAR(255),
    OUT names_l_cnt TINYINT UNSIGNED,
    OUT emails_s    VARCHAR(255),
    OUT emails_cnt  TINYINT UNSIGNED,
    OUT phones_s    VARCHAR(255),
    OUT phones_cnt  TINYINT UNSIGNED,
    OUT country_s   VARCHAR(63),
    OUT cfields_j   JSON
)
 BEGIN
    DECLARE o               VARCHAR(1) DEFAULT '|';         -- General delimiter
    DECLARE paymentlog_s    VARCHAR(2047);                  -- Temp variables
    DECLARE custdata_s      VARCHAR(511);
    DECLARE custmail_s,
            phone_s         VARCHAR(63);
    DECLARE cd_fields       VARCHAR(127);
    
    SET paymentlog_s = LEFT(paymentlog_r,2047);                      		-- LIMIT these, some are big
--    SET custdata_s = clean_cd( LEFT(custdata_r,511) );                        -- data now cleaned in database
    SET custdata_s = LEFT(custdata_r,511);
    SET cd_fields = get_cd_fields( @CD_FIELDS_ALLOWED, custdata_s );
    SET custmail_s = utility.normemail( custmail_r );

    CALL findnames(names_f,names_f_cnt,names_l,names_l_cnt,cd_fields, custdata_s, paymentlog_s, o );
    -- call Debug("findnames()",names_s,id_r);

    SET emails_s = findemails( cd_fields, custdata_s, paymentlog_s , custmail_s, o );
    -- call Debug("findemails()",emails_s,idorder);
    SET emails_cnt = utility.listlenw(emails_s,o);

    IF ( country_r is not null AND country_r != '' ) THEN
        SET country_s = country_select( country_r, NULL );
    ELSE
        SET country_s = @DEFAULT_COUNTRY_A;
    END IF;


    SET country_s = findaddress_country( cd_fields, custdata_s, paymentlog_s, phone_r, country_s, @DEFAULT_COUNTRY_A, o );
    -- call Debug("findaddress_country",country_s,idorder);
    SET phone_s = utility.normphone( phone_r, @DEFAULT_AREACODE, country_s );
    -- call Debug("phone field: ",phone_s,idorder);

    SET phones_s = findphones( cd_fields, custdata_s, paymentlog_s, phone_s, @DEFAULT_AREACODE, country_s , o );
    -- call Debug("findphones(1)",phones_s,idorder);

    SET country_s = findaddress_country( cd_fields, custdata_s, paymentlog_s, phones_s, country_s, @DEFAULT_COUNTRY_A, o );
    -- call Debug("findaddress_country",country_s,idorder);

    SET cfields_j = findaddress( cd_fields, custdata_s, paymentlog_s, phones_s, country_s, @DEFAULT_COUNTRY_A, o );

    -- call Debug("findaddr(1)",cfields_j,idorder);
    SET phones_s = findphones( cd_fields, custdata_s, paymentlog_s, phones_s, @DEFAULT_AREACODE, cfield_get('COUNTRY',cfields_j) , o );
    -- call Debug("findphones(2)",phones_s,idorder);

    SET phones_cnt = utility.listlenw(phones_s,o);

    SET cfields_j = findaddress( cd_fields, custdata_s, paymentlog_s, phones_s, cfield_get('COUNTRY',cfields_j), @DEFAULT_COUNTRY_A, o );
    -- call Debug("findaddr(2)",cfields_j,idorder);

--    call cfield_dump( cfields_j );

END;
 //
DELIMITER ;
show warnings;

DELIMITER // 
 DROP PROCEDURE IF EXISTS vb_extract_orders //
 CREATE PROCEDURE         vb_extract_orders( order_ids VARCHAR (63) )
 BEGIN
    DECLARE o               VARCHAR(1) DEFAULT '|';         -- General delimiter
    DECLARE done            BOOLEAN DEFAULT 0;
    DECLARE paymentlog_r    VARCHAR(2047);                  -- Temp variables
    DECLARE custdata_r      VARCHAR(511);
    DECLARE custmail_r,
            phone_r,
            country_r,
            confirmed_r,
            firstname,
            lastname,
            name_s,
            pname_s         VARCHAR(63);
    DECLARE firstnames,
            lastnames       VARCHAR(255);
    DECLARE i,n,fn,ln       INT DEFAULT 0;
    DECLARE id_r            SMALLINT;
    DECLARE _names,_emails,_phones VARCHAR(255);
    DECLARE _country VARCHAR(63);
    DECLARE _cfields JSON;
    DECLARE ts_r            INT;
    DECLARE _cnt_fn,_cnt_ln,_cnt_email,_cnt_phone TINYINT UNSIGNED;
    DECLARE all_orders  BOOLEAN DEFAULT 1;


    DECLARE cur1 CURSOR FOR SELECT `id`,
                                    LEFT(`custdata`,511),
                                    `custmail`,
                                    LEFT(`paymentlog`,2047),
                                    `country`,
                                    `phone`,
                                    `status`,
                                    `ts`
                                FROM `6rw_vikbooking_orders`
                                WHERE all_orders=1 OR FIND_IN_SET(`id`, order_ids );

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    IF ( order_ids is not null ) THEN
        set all_orders=0;
    END IF;

    OPEN cur1;

read_loop:
    LOOP
        SET id_r=NULL,custdata_r=NULL,custmail_r=NULL,paymentlog_r=NULL,
            country_r=NULL,phone_r=NULL,confirmed_r=NULL,ts_r=NULL;
        SET firstnames=NULL,lastnames=NULL,_emails=NULL,_phones=NULL,_country=NULL;

        FETCH cur1 INTO id_r,custdata_r,custmail_r,paymentlog_r,country_r,phone_r,confirmed_r,ts_r;

        IF (done) THEN LEAVE read_loop; END IF;

        call vb_extract_order(id_r,custdata_r,custmail_r,phone_r,country_r,paymentlog_r,
             firstnames,_cnt_fn,lastnames,_cnt_ln,_emails,_cnt_email,_phones,_cnt_phone,_country,_cfields );
-- select firstnames,_cnt_fn,lastnames,_cnt_ln,_emails,_cnt_email,_phones,_cnt_phone,_country;

        INSERT INTO `vb_order_info` (
            `idorder`,
            `first_names`,
            `cnt_fn`,
            `last_names`,
            `cnt_ln`,
            `emails`,
            `cnt_email`,
            `phones`,
            `cnt_phone`,
            `country`,
            `confirmed`,
            `ts`,
            `cfields` )
        VALUES (
            id_r,
            firstnames,
            _cnt_fn,
            lastnames,
            _cnt_ln,
            _emails,
            _cnt_email,
            _phones,
            _cnt_phone,
            _country,
            IF(confirmed_r='confirmed',1,0),
            ts_r,
            _cfields
        )
        ON DUPLICATE KEY UPDATE
            `first_names`   = firstnames,
            `cnt_fn`        = _cnt_fn,
            `last_names`    = lastnames,
            `cnt_ln`        = _cnt_ln,
            `emails`        = _emails,
            `cnt_email`     = _cnt_email,
            `phones`        = _phones,
            `cnt_phone`     = _cnt_phone,
            `country`       = _country,
            `confirmed`     = IF(confirmed_r='confirmed',1,0),
            `ts`            = ts_r,
            `cfields`       = _cfields
        ;

        
        -- Split identifing info into separate tables
        
        SET i = 0;
        WHILE ( i < _cnt_fn ) DO
            SET i = i + 1;
            CALL vb_store_name1( id_r, SUBSTRING_INDEX(SUBSTRING_INDEX(firstnames,o,i),o,-1));
        END WHILE;
        SET i = 0;
        WHILE ( i < _cnt_ln ) DO
            SET i = i + 1;
            CALL vb_store_name2( id_r, SUBSTRING_INDEX(SUBSTRING_INDEX(lastnames,o,i),o,-1));
        END WHILE;
        SET i = 0;
        WHILE ( i < _cnt_email ) DO
            SET i = i + 1;
            CALL vb_store_email(id_r,SUBSTRING_INDEX(SUBSTRING_INDEX(_emails,o,i),o,-1));
        END WHILE;   
        SET i = 0;
        WHILE ( i < _cnt_phone ) DO
            SET i = i + 1;
            CALL vb_store_phone(id_r,SUBSTRING_INDEX(SUBSTRING_INDEX(_phones,o,i),o,-1));
        END WHILE;   

        INSERT INTO `vb_order_status` VALUES ( id_r,'extracted' ) ON DUPLICATE KEY UPDATE `status`='extracted';

-- LEAVE read_loop;
    END LOOP;

    CLOSE cur1;
END;
 //
DELIMITER ;
show warnings;


DELIMITER // 
 DROP PROCEDURE IF EXISTS vb_store_email //
 CREATE PROCEDURE         vb_store_email( order_id SMALLINT, _email VARCHAR(63) )
 BEGIN
    DECLARE email_exists    BOOLEAN DEFAULT 0;
    DECLARE id_email,c      SMALLINT UNSIGNED;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET email_exists = 1;

    INSERT INTO `vb_emails` (email) VALUE (_email);

    IF ( email_exists ) THEN
        SELECT `id` INTO id_email FROM `vb_emails` WHERE `email` = _email;
        SELECT count(*) into c from `vb_orders_emails` where `idorder`=order_id and `email_id`=id_email;
        IF ( c=0 ) THEN
            INSERT INTO `vb_orders_emails` VALUES ( order_id, id_email );
        END IF;
    ELSE
        SET id_email = LAST_INSERT_ID();
        INSERT INTO `vb_orders_emails` VALUES ( order_id, id_email );
    END IF;

END;
 //
DELIMITER ;
show warnings;


DELIMITER // 
 DROP PROCEDURE IF EXISTS vb_store_phone //
 CREATE PROCEDURE         vb_store_phone( order_id SMALLINT, _phone VARCHAR(63) )
 BEGIN
    DECLARE phone_exists    BOOLEAN DEFAULT 0;
    DECLARE id_phone,c      SMALLINT UNSIGNED;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET phone_exists = 1;

    INSERT INTO `vb_phones` (phone) VALUE (_phone);
    SET id_phone = LAST_INSERT_ID();

    IF ( phone_exists ) THEN
        SELECT `id` INTO id_phone FROM `vb_phones` WHERE `phone` = _phone;
        SELECT count(*) into c from `vb_orders_phones` where `idorder`=order_id and `phone_id`=id_phone;
        IF ( c=0 ) THEN
            INSERT INTO `vb_orders_phones` VALUES ( order_id, id_phone );
        END IF;
    ELSE
        SET id_phone = LAST_INSERT_ID();
        INSERT INTO `vb_orders_phones` VALUES ( order_id, id_phone );
    END IF;

 

END;
 //
DELIMITER ;
show warnings;


DELIMITER // 
 DROP PROCEDURE IF EXISTS vb_store_name1 //
 CREATE PROCEDURE         vb_store_name1( order_id SMALLINT, _name VARCHAR(63) )
 BEGIN
    DECLARE name_exists    BOOLEAN DEFAULT 0;
    DECLARE id_name,c      SMALLINT UNSIGNED;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET name_exists = 1;

    INSERT INTO `vb_name1` (name) VALUE (_name);

    IF ( name_exists ) THEN
        SELECT `id` INTO id_name FROM `vb_name1` WHERE `name` = _name;
        SELECT count(*) into c from `vb_orders_name1` where `idorder`=order_id and `name_id`=id_name;
        IF ( c=0 ) THEN
            INSERT INTO `vb_orders_name1` VALUES ( order_id, id_name );
        END IF;
    ELSE
        SET id_name = LAST_INSERT_ID();
        INSERT INTO `vb_orders_name1` VALUES ( order_id, id_name );
    END IF;


 
END;
 //
DELIMITER ;
show warnings;

DELIMITER // 
 DROP PROCEDURE IF EXISTS vb_store_name2 //
 CREATE PROCEDURE         vb_store_name2( order_id SMALLINT, _name VARCHAR(63) )
 BEGIN
    DECLARE name_exists    BOOLEAN DEFAULT 0;
    DECLARE id_name,c      SMALLINT UNSIGNED;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET name_exists = 1;

    INSERT INTO `vb_name2` (name) VALUE (_name);

    IF ( name_exists ) THEN
        SELECT `id` INTO id_name FROM `vb_name2` WHERE `name` = _name;
        SELECT count(*) into c from `vb_orders_name2` where `idorder`=order_id and `name_id`=id_name;
        IF ( c=0 ) THEN
            INSERT INTO `vb_orders_name2` VALUES ( order_id, id_name );
        END IF;
    ELSE
        SET id_name = LAST_INSERT_ID();
        INSERT INTO `vb_orders_name2` VALUES ( order_id, id_name );
    END IF;


 
END;
 //
DELIMITER ;
show warnings;


DELIMITER // 
    DROP PROCEDURE IF EXISTS vb_extract_orders_reset //
    CREATE PROCEDURE         vb_extract_orders_reset()
BEGIN

    TRUNCATE vb_order_info;
    TRUNCATE vb_emails;
    TRUNCATE vb_orders_emails;
    TRUNCATE vb_name1;
    TRUNCATE vb_orders_name1;
    TRUNCATE vb_name2;
    TRUNCATE vb_orders_name2;
    TRUNCATE vb_phones;
    TRUNCATE vb_orders_phones;
    TRUNCATE vb_order_status;

END;
 //
DELIMITER ;
show warnings;

DELIMITER // 
    DROP PROCEDURE IF EXISTS vb_extract_orders_init //
    CREATE PROCEDURE         vb_extract_orders_init()
BEGIN

    DROP TABLE vb_order_info;
    DROP TABLE vb_emails;
    DROP TABLE vb_orders_emails;
    DROP TABLE vb_name1;
    DROP TABLE vb_orders_name1;
    DROP TABLE vb_name2;
    DROP TABLE vb_orders_name2;
    DROP TABLE vb_phones;
    DROP TABLE vb_orders_phones;
    DROP TABLE vb_order_status;


-- Table to collect order -> customer matches in VikBooking
CREATE TABLE IF NOT EXISTS `vb_order_info` (
	`id`            SMALLINT(4) UNSIGNED NOT NULL auto_increment,
	`idorder`       SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0,
        `first_names`   VARCHAR(255)             NULL DEFAULT '',
        `cnt_fn`        TINYINT     UNSIGNED NOT NULL DEFAULT 0,
        `last_names`    VARCHAR(255)             NULL DEFAULT '',
        `cnt_ln`        TINYINT     UNSIGNED NOT NULL DEFAULT 0,
        `emails`        VARCHAR(511)             NULL DEFAULT '',
        `cnt_email`     TINYINT     UNSIGNED NOT NULL DEFAULT 0,
        `phones`        VARCHAR(255)             NULL DEFAULT '',
        `cnt_phone`     TINYINT     UNSIGNED NOT NULL DEFAULT 0,
        `country`       VARCHAR(63)              NULL,
        `cfields`       JSON                 NOT NULL,
        `idcust`        SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0,
        `confirmed`     BOOLEAN              NOT NULL DEFAULT 0,
        `ts`            INT,
        `type`          TINYINT  NOT NULL DEFAULT 0,
	PRIMARY KEY (`id`),
        INDEX ( `id`,`idorder` )
        ) ENGINE=INNODB;


-- Table to collect order -> email matches in VikBooking
CREATE TABLE IF NOT EXISTS `vb_emails` (
	`id`            SMALLINT(4) UNSIGNED NOT NULL auto_increment,
        `email`         VARCHAR(63) UNIQUE   NOT NULL DEFAULT '',
        PRIMARY KEY (`id`),
	INDEX (`id`,`email`)
        ) ENGINE=MYISAM;


-- Table to collect order -> email matches in VikBooking
CREATE TABLE IF NOT EXISTS `vb_orders_emails` (
	`idorder`       SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0 ,
        `email_id`      SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0,
	INDEX (`idorder`,`email_id`)
        ) ENGINE=MYISAM;


-- Table to collect order -> phone matches in VikBooking
CREATE TABLE IF NOT EXISTS `vb_phones` (
	`id`            SMALLINT(4) UNSIGNED NOT NULL auto_increment,
        `phone`         VARCHAR(63) UNIQUE   NOT NULL DEFAULT '',
        PRIMARY KEY (`id`),
	INDEX (`id`,`phone`)
        ) ENGINE=MYISAM;


-- Table to collect order -> phone matches in VikBooking
CREATE TABLE IF NOT EXISTS `vb_orders_phones` (
	`idorder`       SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0 ,
        `phone_id`      SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0,
	INDEX (`idorder`,`phone_id`)
        ) ENGINE=MYISAM;


-- Table to collect order -> name1 matches in VikBooking
CREATE TABLE IF NOT EXISTS `vb_name1` (
	`id`            SMALLINT(4) UNSIGNED NOT NULL auto_increment,
        `name`          VARCHAR(63) UNIQUE   NOT NULL DEFAULT '',
        PRIMARY KEY (`id`),
	INDEX (`id`,`name`)
        ) ENGINE=MYISAM;


-- Table to collect order -> name1 matches in VikBooking
CREATE TABLE IF NOT EXISTS `vb_orders_name1` (
	`idorder`       SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0 ,
        `name_id`       SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0,
	INDEX (`idorder`,`name_id`)
        ) ENGINE=MYISAM;


-- Table to collect order ->  matches in VikBooking
CREATE TABLE IF NOT EXISTS `vb_name2` (
	`id`            SMALLINT(4) UNSIGNED NOT NULL auto_increment,
        `name`          VARCHAR(63) UNIQUE   NOT NULL DEFAULT '',
        PRIMARY KEY (`id`),
	INDEX (`id`,`name`)
        ) ENGINE=MYISAM;


-- Table to collect order -> name2 matches in VikBooking
CREATE TABLE IF NOT EXISTS `vb_orders_name2` (
	`idorder`       SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0 ,
        `name_id`       SMALLINT(4) UNSIGNED NOT NULL DEFAULT 0,
	INDEX (`idorder`,`name_id`)
        ) ENGINE=MYISAM;


CREATE TABLE IF NOT EXISTS `vb_order_status` (
	`idorder`      SMALLINT(4) UNSIGNED UNIQUE NOT NULL DEFAULT 0,
        `status`       ENUM('initial','extracted','matched_customer','created_customer') NOT NULL default 'initial',
        PRIMARY KEY (`idorder`),
	INDEX (`idorder`, `status` )
        ) ENGINE=MYISAM;

END;//
DELIMITER ;
show warnings;

DELIMITER // 
    DROP PROCEDURE IF EXISTS vb_extract_orders_show //
    CREATE PROCEDURE         vb_extract_orders_show(order_ids VARCHAR(127) )
BEGIN

        if (order_ids is null) then
            select id,phone,custmail,
                plogfield('first_name',paymentlog)  as ppfn,
                plogfield('last_name', paymentlog)  as ppln,
                plogfield('payer_email',paymentlog) as ppem,
                LEFT(replace(custdata,'\r',';'),50)
            from 6rw_vikbooking_orders;
        else
            select id,phone,custmail,
                plogfield('first_name',paymentlog)  as ppfn,
                plogfield('last_name', paymentlog)  as ppln,
                plogfield('payer_email',paymentlog) as ppem,
                LEFT(replace(custdata,'\r',';'),50)
            from 6rw_vikbooking_orders
            where find_in_set(`id`,order_ids);
        end if;

END;//
DELIMITER ;
show warnings;

    call vb_extract_orders_reset();
    call vb_extract_orders(NULL);
