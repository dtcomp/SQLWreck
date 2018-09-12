DELIMITER ;
source global.sql;
source utility.sql;
select 'sq_load_data.sql' as 'file';


create database if not exists `mcc_customer`;
drop table if exists `mcc_customer`.`sq_customers`;

-- This mostly matches column set from Square customer CSV dump
create table if not exists `mcc_customer`.`sq_customers` (
 `reference_id` SMALLINT UNSIGNED   NULL ,  -- Map to VB customer Id if matched
 `first_name`   VARCHAR(31)         NULL,
 `last_name`    VARCHAR(31)         NULL,
 `email`	VARCHAR(63)         NULL,
 `phone`	VARCHAR(31)         NULL,
 `nickname`     VARCHAR(63)         NULL,
 `company`      VARCHAR(63)         NULL,
 `address1`	VARCHAR(63)         NULL,
 `address2`	VARCHAR(63)         NULL,
 `city`		VARCHAR(63)         NULL,
 `state`	VARCHAR(63)         NULL,
 `post`	        VARCHAR(31)         NULL,
 `birthday`     DATE                NULL,
 `memo`         text                NULL,
 `square_id`	VARCHAR(31)         NULL,
 `source`       VARCHAR(63)         NULL,
 `vfirst`	DATE                NULL,
 `vlast`	DATE                NULL,
 `transactions` SMALLINT UNSIGNED   NULL  DEFAULT 0,
 `spent`	decimal(12,2)             DEFAULT 0.0,
 `unsubscribed` BOOLEAN                   DEFAULT 0,
 `instant`      BOOLEAN                   DEFAULT 0,
 `id`           INT UNSIGNED PRIMARY KEY AUTO_INCREMENT NOT NULL
) ENGINE=INNODB;

TRUNCATE `mcc_customer`.`sq_customers`;

-- Load our data from the named infile

select 'Loading data from: INFILE data/export-20180412-083012.csv' as info;
LOAD DATA LOCAL INFILE 'data/export-20180412-083012.csv'
REPLACE INTO TABLE `mcc_customer`.`sq_customers`
fields terminated by ','
optionally enclosed by '"'
ignore 1 lines
 (@a,@b,@c,@d,@e,@nick,@g,@h,@i,@j,@k,@post,@m,@n,@o,@p,@q,@r,@s,@t,@u,@v)
SET
`reference_id`  = IF(@a='',NULL,@a),
`first_name`    = IF(@b='',NULL,@b),
`last_name`     = IF(@c='',NULL,@c),
`email`         = IF(@d='',NULL,utility.normemail(@d)),
`phone`         = IF(@e='',NULL,utility.normphone(@e,@DEFAULT_AREACODE,@DEFAULT_COUNTRY_A)),
`nickname`      = IF(@nick='',NULL,utility.normname(@nick,0)),
`company`       = IF(@g='',NULL,@g),
`address1`      = IF(@h='',NULL,utility.cap1(utility.strippunc(".- ",TRIM(REPLACE(@h,'  ',' '))))),
`address2`      = IF(@i='',NULL,utility.cap1(utility.strippunc(".- ",TRIM(REPLACE(@i,'  ',' '))))),
`city`          = IF(@j='',NULL,utility.cap1(utility.strippunc("- ", TRIM(REPLACE(@j,'  ',' '))))),
`state`         = IF(@k='',NULL,utility.cap1(utility.strippunc("- ", TRIM(REPLACE(@k,'  ',' '))))),
`post`          = IF(@post='',NULL,utility.normzip(@post)),
`birthday`      = IF(@m='',NULL,@m),
`memo`          = IF(@n='',NULL,@n),
`square_id`     = IF(@o='',NULL,@o),
`source`        = IF(@p='',NULL,@p),
`vfirst`        = IF(@r='',NULL,@q),
`vlast`         = IF(@r='',NULL,@r),
`transactions`  = @s,
`spent`         = CAST(REPLACE(@t,'$','') AS DECIMAL(12,2)),
`unsubscribed`  = IF(@u LIKE 'yes',1,0),
`instant`       = IF(@v LIKE 'yes',1,0);


