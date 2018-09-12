DELIMITER ;
source utility.sql;
source location.sql;
source vb_cfield.sql;
select 'vb.sql' as 'file';


-- ===================================================================================
-- This collection deals mainly with parsing and normalizing VB order records.
--
-- Specifically, fields:
--
--              `phone`
--              `custmail`
--              `country`
--              `custdata` ( Name and all above data types can exist here )
--              `paymentlog` ( Name, email )
--
-- The last two of these fields are textual and are parsed to extract data
-- Then, all of the data is merged into a set of customer data based on the
-- record contents.
--
-- Later, multiple order records will be merged further to fill in missing information
-- if possible.
--
-- -----------------------------------------------------------------------------------




-- =============================================================================================================
-- Customer Data sub-fields that *might* exist in order records  - `*_orders`.`custdata`
-- Records do not contain all sub-fields, selection varies
--
SET @CD_FIELDS_ALLOWED = ',Name,Last Name,e-Mail,Phone,Address,Zip Code,City,State,Country,Date of Birth,Notes,';
-- =============================================================================================================


-- ===================================================================================
-- Basic format corrections/optimization.
--
-- <newline> (\r\n) is the normal subfield-end delimiter, though some records vary...
-- -----------------------------------------------------------------------------------

DELIMITER //
DROP FUNCTION IF EXISTS clean_cd //
CREATE FUNCTION clean_cd(cdata TEXT)
  RETURNS TEXT
  BEGIN
    DECLARE data_s TEXT;

    SET data_s = TRIM(cdata);
    SET data_s = REPLACE(data_s, '\n', '\r');   			-- no newlines
    SET data_s = REPLACE(data_s, '\r\r', '\r'); 			-- remove duplicates
    SET data_s = REPLACE(data_s, '  ', ' ');    			-- remove duplicates
    SET data_s = REPLACE(data_s, '..', '.');
    SET data_s = REPLACE(data_s, '--', '-');
    SET data_s = utility.chop_leading('\r', data_s);      	-- leading delimiters
    SET data_s = TRIM(data_s);
    SET data_s = utility.chop_trailing('\r', data_s);       -- trailing delimiters
    RETURN TRIM(data_s);

  END;
//
DELIMITER ;
SHOW WARNINGS;

-- ===================================================================================
--   Parse custdata record for available subfield markers..
--
-- -----------------------------------------------------------------------------------
DELIMITER //
DROP FUNCTION IF EXISTS get_cd_fields //
CREATE FUNCTION get_cd_fields(fields_allowed VARCHAR(255), cdata TEXT)
  RETURNS TEXT
  BEGIN
    DECLARE o VARCHAR(1) DEFAULT ',';               -- intput & output delimiter for subfield markers
    DECLARE d VARCHAR(1) DEFAULT ',';
    DECLARE fn, fn_s, rx_s VARCHAR(127) DEFAULT '';
    DECLARE cnt, i, n INT DEFAULT 0;
    DECLARE fresult VARCHAR(255) DEFAULT o;       -- output starts with delim

    SET cnt = utility.countdelim( d, fields_allowed ) + 1;

    start1:
    WHILE (i < cnt) DO
      SET i = i + 1;
      SET fn = SUBSTRING_INDEX(SUBSTRING_INDEX(fields_allowed, d, i), d, -1);
      IF (NOT LENGTH(fn) OR fn IS NULL )
      THEN
        ITERATE start1;
      END IF;
      SET fn_s = CONCAT(fn, ': ');
      SET rx_s = CONCAT('^', fn_s, '|[^[:alpha:]]+', fn_s);
      IF (cdata RLIKE rx_s)
      THEN
        SET fresult = CONCAT(fresult, fn, o);
        SET n = n + 1;
      END IF;
    END WHILE;

    IF (n)
    THEN
      RETURN fresult;

    ELSE
      RETURN NULL;
    END IF;

  END;
//
DELIMITER ;
SHOW WARNINGS;


-- ===================================================================================
-- Extract field value from "normal" custdata field -
-- Some records have bogus or manually-altered data that breaks the format
-- We try to deal with broken records elsewhere, for important data
-- Strangely, some record's subfields are delimited by "\n" only!
--
-- -----------------------------------------------------------------------------------
DELIMITER //
DROP FUNCTION IF EXISTS xtract_cd_field //
CREATE FUNCTION xtract_cd_field(field VARCHAR(31), custdata TEXT)
  RETURNS TEXT
  BEGIN
    DECLARE f VARCHAR(31);
    DECLARE fresult TEXT DEFAULT '';
    DECLARE fl, ndx INT;

    SET f = field;
    SET fl = LENGTH(f);

    IF ( fl=0 OR f IS NULL )
    THEN
        RETURN NULL;
    END IF;

    IF (NOT LOCATE(':', f))
    THEN                                    -- Conveiniently add missing subfield marker text
      SET f = CONCAT(field, ': ');
      SET fl = LENGTH(f);
    END IF;

    SET ndx = LOCATE(f, custdata);

    IF (ndx > 0)
    THEN                                    -- field found
        SET fresult = TRIM(SUBSTRING_INDEX(SUBSTRING(custdata, ndx+fl ), '\r', 1));
    END IF;

    RETURN fresult;

  END
//
DELIMITER ;
SHOW WARNINGS;



-- ===================================================================================
-- Extract Phone numbers from "free-form" custdata subfields.
--   To be used on records that do NOT already have normal Phone: info
--
-- Returns: A delimiter-separated string of "normalized" numbers
--
-- -----------------------------------------------------------------------------------
DELIMITER //
DROP FUNCTION IF EXISTS xtractphone2 //
CREATE FUNCTION xtractphone2(custdata TEXT, area_default VARCHAR(5), country VARCHAR(255), delim VARCHAR(1) )
  RETURNS VARCHAR(255)
  BEGIN
    DECLARE area VARCHAR(5) DEFAULT area_default;
    DECLARE o VARCHAR(1) DEFAULT delim;             -- output delimter
    DECLARE last_s, i, pos INT DEFAULT 0;
    DECLARE ldat, try_s TEXT;
    DECLARE phone, fresult, ptok VARCHAR(255) DEFAULT '';

    SET ldat = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(custdata, '\n', '\r'), '\r\r', '\r'), '\r', '|'), '  ', ' '),'_','');
    SET ldat = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ldat, ')', ''), '(', ''), ' ', ''), ':', '|'), '.', '');
    SET ldat = TRIM(ldat);

    SET i = 0;

    IF (ldat RLIKE '.*[+]?[[:digit:]-]{7,14}.*')
    THEN -- any possibilites?
      SET last_s = LENGTH(ldat);
      SET pos = 0;
      start1:
      REPEAT
        SET pos = pos + 1;
        SET try_s = SUBSTRING_INDEX(SUBSTRING(ldat, pos), '|', 1);
        IF (try_s RLIKE '^[^[:digit:]]{2,}[,]?[[:digit:]]{7,7}[^[:digit:]]*$')
        THEN   -- Postcode
          SET pos = pos + length(try_s);
          ITERATE start1;
        END IF;
        IF (try_s RLIKE '^[^[:digit:]]{2,}[,]?[[:digit:]]{5,5}[-]?[[:digit:]]{4,4}[^[:digit:]]*$')
        THEN -- Zip+4
          SET pos = pos + length(try_s);
          ITERATE start1;
        END IF;
        IF (try_s RLIKE '^[^[:digit:]]+[0-1][0-9][/-]0?[0-3][0-9][/-][[:digit:]]{2,4}[^[:digit:]]*$')
        THEN -- Date
          SET pos = pos + length(try_s);
          ITERATE start1;
        END IF;
        IF (try_s RLIKE '^.*[Gg][Rr][Oo][^[:digit:]]+#[[:digit:]-]{8,15}[^[:digit:]]*$')
        THEN -- Goupon code
          SET pos = pos + length(try_s);
          ITERATE start1;
        END IF;
        IF (try_s RLIKE '.*\\+?[[:digit:]-]{7,14}.*')
        THEN -- there's something like a phone# there
          WHILE (SUBSTRING_INDEX(SUBSTRING(ldat, pos), '|', i+1) RLIKE '^[+]?[[:digit:]-]{7,14}$') DO
            SET i = i + 1;
            SET phone = utility.normphone(SUBSTRING_INDEX(SUBSTRING(ldat, pos), '|', i), area, country);
            SET fresult = CONCAT(fresult, phone, o);
            SET pos = pos + LENGTH(phone);
          END WHILE;
        END IF;
      UNTIL (pos >= last_s)
      END REPEAT;
    END IF;

    IF (i)
    THEN
      RETURN utility.chop_last(o, fresult);
    ELSE
      RETURN NULL;
    END IF;

  END
//
DELIMITER ;
SHOW WARNINGS;


-- ===================================================================================
--   Lookup things in the VikBooking "Country" table.
--   Several variations to lookup by:
--      2-letter code
--      3-letter code
--      Country Name
--      Country Phone-Prefix
--
--  Returns: * 3-letter country code if a match is found
--           * NULL if no match
-- -----------------------------------------------------------------------------------

DELIMITER //
DROP FUNCTION IF EXISTS lookup_country3_2 //
CREATE FUNCTION lookup_country3_2(c VARCHAR(3))
  RETURNS VARCHAR(4)
  BEGIN
    DECLARE c3 VARCHAR(4) DEFAULT NULL;

    BEGIN
      SELECT `country_3_code`
      INTO c3
      FROM `6rw_vikbooking_countries`
      WHERE `country_2_code` LIKE c limit 1;
    END;

    RETURN c3;
  END
//
DELIMITER ;
SHOW WARNINGS;

--
DELIMITER //
DROP FUNCTION IF EXISTS lookup_country3_3 //
CREATE FUNCTION lookup_country3_3(c VARCHAR(255))
  RETURNS VARCHAR(4)
  BEGIN
    DECLARE c3 VARCHAR(4) DEFAULT NULL;

    BEGIN
      SELECT `country_3_code`
      INTO c3
      FROM `6rw_vikbooking_countries`
      WHERE `country_3_code` LIKE c limit 1;
    END;

    RETURN c3;
  END
//
DELIMITER ;
SHOW WARNINGS;

--
DELIMITER //
DROP FUNCTION IF EXISTS lookup_country3_name //
CREATE FUNCTION lookup_country3_name(c TEXT)
  RETURNS VARCHAR(3)
  BEGIN
    DECLARE c3 VARCHAR(3) DEFAULT NULL;

    BEGIN
      SELECT `country_3_code`
      INTO c3
      FROM `6rw_vikbooking_countries`
      WHERE `country_name` LIKE c
      LIMIT 1;
    END;

    RETURN c3;
  END
//
DELIMITER ;
SHOW WARNINGS;


--
DELIMITER //
DROP FUNCTION IF EXISTS lookup_country2_phone //
CREATE FUNCTION lookup_country2_phone( phone VARCHAR(255) )
  RETURNS VARCHAR(2)
  BEGIN
    DECLARE c2 VARCHAR(2);
    DECLARE max_dig INT DEFAULT 7;
    DECLARE i,n INT DEFAULT 0;
    DECLARE pre,tmp_s VARCHAR(7) DEFAULT LEFT(phone,7);
    DECLARE r INT DEFAULT 0;

      WHILE ( LOCATE('+',pre)=1 OR LOCATE('0',pre)=1  ) DO
        SET pre = SUBSTRING(pre,2);
      END WHILE;

      IF ( pre IS NULL OR pre = '' ) THEN
        RETURN NULL;
      END IF;
      
      SET n = max_dig;

      IF ( LENGTH(pre)< n ) THEN
        SET n=LENGTH(pre);
      END IF;

      SET tmp_s=pre;
      SET i=0;
start1:
      WHILE ( i<n ) DO
        SET i = i + 1;
        SET tmp_s = SUBSTRING(pre,1,i);
        SELECT SQL_CALC_FOUND_ROWS `country_2_code`
        INTO c2
        FROM `6rw_vikbooking_countries`
        WHERE REPLACE(REPLACE(`phone_prefix`,' ',''),'+','') LIKE CONCAT(tmp_s, '%')
        LIMIT 1;
        SET r = FOUND_ROWS();
        IF ( r=1 ) THEN
            return c2;
        END IF;
      END WHILE;

      SET i=n;

      SET tmp_s=pre;
start2:
      WHILE ( i >= 2 ) DO
        SET tmp_s = LEFT(pre,i);
        SELECT SQL_CALC_FOUND_ROWS `country_2_code`
        INTO c2
        FROM `6rw_vikbooking_countries`
        WHERE REPLACE(REPLACE(`phone_prefix`,' ',''),'+','') LIKE CONCAT(tmp_s, '%')
        LIMIT 1;
        SET r = FOUND_ROWS();
        IF ( r=1 ) THEN
            return c2;
        ELSE
            SET i = i - 1;
        END IF;
      END WHILE;

      RETURN NULL;
  END
//
DELIMITER ;
SHOW WARNINGS;


-- ===================================================================================
-- Look for a matching zip/post code in the database of US postal info
--
-- Returns an ordered, delimiter-separated record of associated info:
--
--  CountryCode(2-letter),Postcode,City,State,State-Abbreviation
--
-- -----------------------------------------------------------------------------------

-- DELIMITER //
-- DROP FUNCTION IF EXISTS vb_lookup_zip //
-- CREATE FUNCTION vb_lookup_zip(zip VARCHAR(20), default_country VARCHAR(2), delim VARCHAR(1))
--   RETURNS VARCHAR(255)
--   BEGIN
--     DECLARE o           VARCHAR(1)      DEFAULT delim;
--     DECLARE ziprec      VARCHAR(80)     DEFAULT NULL;
-- 
--       IF ( zip IS NULL OR zip ='' )  THEN
--         RETURN NULL;
--       END IF;
-- 
--     SET ziprec = location.lookup_zip( zip, o );
-- 
--     RETURN  ziprec;
-- 
--   END //
-- DELIMITER ;
-- SHOW WARNINGS;

-- Name Strategy
-- 1) Go for custdata Name/Last Name subfields, if not found then:
-- 2) Go for free-form data in custdata with "Room Closed", if not found then:
-- 3) Go for free-form data in custdata
-- 4) Go for paymentlog First/Last name fields
-- 5 Punt!

-- ===================================================================================
-- Horrible hack to cleanup "free-form" order records to make them parse-able
-- RAN against DB !!
-- -----------------------------------------------------------------------------------

DELIMITER //
DROP FUNCTION IF EXISTS skip_phrases //
CREATE FUNCTION skip_phrases(str TEXT)
  RETURNS TEXT
  BEGIN
    DECLARE s TEXT
    DEFAULT '
/ put back into this site cause people booked into 26 moved to 34 MCF 7/19,
groupon /not sure amt. paid...balance due when checking in..mcf,
he will pay when he gets here he is friends with 30,
has 2 grouppos and will pay the diff. to upgrade,
groupon for 2 day and 3 one charge 22.00,
moving from 17 to 26 for one more night,
/moved to stay extra night from 62 & 63,
MAY WANT SAT TO HOLD SITE UNTIL TONIGHT,
will paid the diff for the up grade,
paid in store on 8/12/16 with Karen,
already paid on oct 26 2015 pay pal,
WILL HAVE A LOT OF STANDING WATER,
for 2 day and 3 one charge 22.00,
paid on line was a over booked,
Paid in store for 6/15-6/19 tj,
stay 2 day they get 1 free day,
paid for other week in site 49,
Illegible Booked in store 7/2,
he in the site and paid store,
/moved to stay from 62 & 63,
will pay when comes in today,
/staying over/mcf/paid 7/18,
/staying another night/mcf,
/staying another night/mcf,
will pay when he gets here,
paid with cash on 07-31-16,
will update soon by Karen,
on line was a over booked,
HAD TO MOVE DOUBLE BOOKED,
rented paid for in store,
Stay over/same site/mcf,
Paid in $20.00 store tj,
Paid $28.00 in store tj,
Joes friends no payment,
will paid when come in,
Some place not America,
will pay when gets in,
paid in store with kw,
this is a better site,
rented paid in store,
paid on tab in store,
PAID IN STORE ON TAB,
Paid in store on tab,
Germans...I think...,
they have 59 and 58,
pd in store with cc,
pd in store with cc,
groupon extra night,
closed for spraying,
walked in and paid,
Room Closed rented,
rented in store kw,
paid cash in store,
switching from 6-8,
2 SITES 42 AND 43,
2 SITES 24 AND 25,
this site is for,
Room Closed rent,
PD KW DONT MOVED,
PAID KW IN STORE,
paid in store kw,
in store with kw,
hold for friends,
closed for spray,
ADDITIONAL NIGHT,
pd in store mcf,
will pay later,
PD KW IN STORE,
pd in store kw,
groupon....mcf,
groupon closed,
cj you because,
WILL PAY CASH,
piad in store,
PAID IN STORE,
paid in store,
/mcf/not paid,
HAS A GOUPPON,
Dorin/paid by,
cash in store,
will paid kw,
staying over,
Room Closed.,
Room Closed:,
Room Closed:,
Room Closed;,
PAI IN STORE,
paid on ipad,
OFF THE ROAD,
karen s site,
2 nites x 35,
Room Closed,
rented paid,
rented from,
PD IN STORE,
Extra Night,
Extra night,
extra night,
DO NOT MOVE,
/bikers mcf,
and than 43,
Room Close,
rent pd kw,
rented for,
NO ENGLISH,
extra site,
also in 57,
will call,
rented to,
rented by,
PD ONLINE,
/paid/mcf,
/not paid,
/mcf/ NOT,
Dorin/ by,
pd Karen,
PARTY OF,
in store,
WITH JW,
pd cash,
GROUPON,
Groupon,
groupon,
2 SITES,
walk IN
RENTED,
rented,
ON TAB,
...mcf,
GROUPO,
PD KW,
MOVED,
//mcf,
paid,
/mcf,
mcf,
 PD,
 pd,
 KW,
 Kw,
 kw,
 JW,
 jw
';

        DECLARE phrase TEXT;
        DECLARE i,l,len,pos,p INT DEFAULT 0;

        SET s = REPLACE(REPLACE(REPLACE(REPLACE(s,'\r',''),'\n',''),'\t',''),'  ',' ');
        SET str = REPLACE(REPLACE(str,'\t',' '),'  ',' ');
        SET str = REPLACE(str,'  ',' ');
        SET len = utility.countdelim(',',s) +1 ;
        WHILE ( i < len ) DO
            SET i = i + 1;
            SET phrase = TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(s,',',i),',', -1));
            SET l = LENGTH(phrase);
            SET pos = LOCATE(phrase, str);
            WHILE ( pos ) DO
                SET str = CONCAT( SUBSTRING(str, 1, pos-1 ),SUBSTRING(str, pos+l) );
                SET pos = LOCATE(phrase, str);
            END WHILE;
        END WHILE;

        RETURN TRIM(str);

    END
//
DELIMITER ;
SHOW WARNINGS;


    -- Process a  manually-altered "record" with subfields
    -- but format has been broken...

DELIMITER //
DROP FUNCTION IF EXISTS xtractname0 //
CREATE FUNCTION xtractname0(custdata_line TEXT)
RETURNS TEXT
      BEGIN
        DECLARE name_s TEXT;
        DECLARE cm INT;
        DECLARE f, l TEXT;

        SET name_s = TRIM(custdata_line);
--        SET name_s = skip_phrases(name_s);
        SET name_s = TRIM(utility.chop_first('\r',name_s));
        SET name_s = SUBSTRING_INDEX(name_s, '\r', 1);
        SET name_s = TRIM(utility.stripnum('', name_s));
        SET name_s = utility.chop_last('-', name_s);

        IF (NOT LENGTH(name_s))
        THEN
          RETURN NULL;
        END IF;

        SET name_s = REPLACE(name_s, '.', '. '); -- ensure space after '.'
        SET name_s = REPLACE(name_s, '  ', ' '); -- single spaces tho
        SET name_s = REPLACE(name_s, ',,', ','); -- dedup comma

        SET cm = LOCATE(',', name_s);            -- Last name first?

        IF (cm)                                  -- Swap
        THEN
          SET l = SUBSTRING_INDEX(name_s, ',', 1);
          SET f = SUBSTRING_INDEX(name_s, ',', -1);
          SET name_s = CONCAT(TRIM(f), ' ', TRIM(l));
        END IF;

        RETURN name_s;
      END;
//
DELIMITER ;
SHOW WARNINGS;

    -- Process a  manually-altered "record" with subfields
    -- but format has been broken...

    DELIMITER //
    DROP FUNCTION IF EXISTS xtractname1 //
    CREATE FUNCTION xtractname1(custdata TEXT)
      RETURNS TEXT
      BEGIN
        DECLARE data_s TEXT;
        DECLARE l1, l2, l3, l4, l5, l6 TEXT;

        SET data_s = TRIM(custdata);
        SET data_s = TRIM(utility.chop_first('\r',data_s));

        SET l1 = SUBSTRING_INDEX(data_s, '\r', 1);
        SET l2 = SUBSTRING_INDEX(SUBSTRING_INDEX(data_s, '\r', 2),'\r', -1);
        SET l3 = SUBSTRING_INDEX(SUBSTRING_INDEX(data_s, '\r', 3),'\r', -1);
        SET l4 = SUBSTRING_INDEX(SUBSTRING_INDEX(data_s, '\r', 4),'\r', -1);
        SET l5 = SUBSTRING_INDEX(SUBSTRING_INDEX(data_s, '\r', 5),'\r', -1);
        SET l6 = SUBSTRING_INDEX(SUBSTRING_INDEX(data_s, '\r', 6),'\r', -1);

        IF (l1 RLIKE '^Room Close[d]?.?$')
        THEN
          SET data_s = xtractname0(l2);
        ELSE
          SET data_s = xtractname0(l1);
        END IF;

        RETURN (data_s);
      END
    //
    DELIMITER ;
    SHOW WARNINGS;

-- ===================================================================================
--
--   Attempt to extract a person-name from a manually-entered order "record"
--    with subfields.
--   
-- -----------------------------------------------------------------------------------

    DELIMITER //
    DROP FUNCTION IF EXISTS xtractname //
    CREATE FUNCTION xtractname(custdata TEXT)
      RETURNS TEXT
      BEGIN
        DECLARE line_i,i,tokens,results INT DEFAULT 0;
        DECLARE name_s,fresult VARCHAR(255) DEFAULT '';
        DECLARE l TEXT DEFAULT '';
        DECLARE data_s TEXT;

        SET data_s=custdata;
--        SET data_s = TRIM(skip_phrases(data_s));
        SET data_s = TRIM(utility.chop_first('\r',data_s));
        SET data_s = TRIM(utility.chop_last ('\r',data_s));
        SET data_s = TRIM(REPLACE(data_s,'_',' '));
        SET line_i = utility.countdelim('\r', data_s) + 1;
start1:
        WHILE ( i < line_i ) DO
            SET i = i + 1;
            SET l = TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(data_s, '\r', i),'\r', -1));
            SET tokens = utility.countdelim(' ',l ) + 1;
            IF (  l IS NULL OR l = '' OR (tokens > 4) OR ( l RLIKE '^[.*[:digit:]]+.*$' ))  THEN
                ITERATE start1;
            END IF;
            IF ( l RLIKE "^[[:alpha:] /.,&'-]+$" )  THEN
                SET name_s = xtractname0(l);
                IF ( name_s IS NOT NULL AND LENGTH(name_s) ) THEN
                   SET fresult = CONCAT(fresult, name_s, ' ');
                   SET results = results + 1;
                   SET name_s = NULL;
                   RETURN fresult;
                END IF;
            ELSE
                IF ( results ) THEN             -- probably got the names alreay
                    LEAVE start1;
                END IF;
            END IF;
        END WHILE;

        IF ( results ) THEN
            RETURN TRIM(fresult);
        ELSE
            RETURN NULL;
        END IF;

  END
//
DELIMITER ;
SHOW WARNINGS;


-- ===================================================================================
-- Extract "abnormal" `custdata` email field

DELIMITER //
DROP FUNCTION IF EXISTS xtractemail2 //
CREATE FUNCTION xtractemail2(custdata TEXT, delim VARCHAR(1))
  RETURNS TEXT
  BEGIN
    DECLARE o VARCHAR(1) DEFAULT delim;
    DECLARE ldata TEXT;
    DECLARE a, pos, results INT DEFAULT 0;
    DECLARE fresult, lt, rt TEXT DEFAULT '';
    DECLARE el, er, email VARCHAR(63);

    SET ldata = REPLACE(
        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(custdata, '\n', '\r'), '\r\r', '\r'), '..', '.'), '@@', '@'), '\t\t',
                '\t'), '\t', '');
    SET ldata = REPLACE(REPLACE(REPLACE(ldata, '\r', '\t'), '  ', ' '), ' ',
                        '\t'); -- convert entire data to <TAB> delimiter
    SET pos = 1;

    SET a = LOCATE('@', ldata, pos);

    WHILE (a) DO
      SET lt = SUBSTRING(ldata, pos, a - pos);  -- find tokens on left, if any
      SET el = SUBSTRING_INDEX(lt, '\t', -1);   -- local part
      SET rt = SUBSTRING(ldata, a + 1);         -- tokens on right
      SET er = SUBSTRING_INDEX(rt, '\t', 1);    -- domain part
      SET email = utility.normemail(CONCAT(el, '@', er));
      SET fresult = CONCAT(fresult, email, o);
      SET results = results + 1;
      SET pos = a + LENGTH(er) + 1;
      SET a = LOCATE('@', ldata, pos);
    END WHILE;

    IF ( results )
    THEN
      RETURN utility.chop_last(o, fresult);
    ELSE
      RETURN NULL;
    END IF;

  END
//
DELIMITER ;

SHOW WARNINGS;

-- ===================================================================================
-- Extract Post Code from custdata, if any.
-- To be used on records that do NOT already have normal Zip Code:
--
-- Returns:
--
--  If record lookup suceeded,
--      A (partial) record from zip table if found, prepended with "verified".
--
--  If record lookup failed, but Zip-like codes were found in custdata,
--      A record of "candidate" codes parsed from custdata, prepended with "parsed".
--
--  If no Zip-like codes were found,
--      NULL is returned.
--
--  Most International codes are unsupported
-- -----------------------------------------------------------------------------------
DELIMITER //
DROP FUNCTION IF EXISTS xtractzip //
CREATE FUNCTION xtractzip(custdata TEXT,  country VARCHAR(63),o VARCHAR(1) )
  RETURNS VARCHAR(255)
  BEGIN
    DECLARE d VARCHAR(1) DEFAULT ' ';                                           -- input delimiter
    DECLARE dash, zc, z_found, len, i, max_tokens INT DEFAULT 0;
    DECLARE try_s VARCHAR(255) DEFAULT NULL;
    DECLARE data_s TEXT;
    DECLARE fresult,first_result, candidates VARCHAR(255) DEFAULT '';

    SET data_s = REPLACE(custdata, '\r', d);                                  -- delim by ' '
    SET data_s = TRIM(REPLACE(REPLACE(data_s, '.', d), CONCAT(d,d), d));

    SET len = LENGTH(data_s);
    SET max_tokens = utility.countdelim(d, data_s) + 1;

    -- Phase 1
    start1:
    WHILE (ABS(i) < max_tokens) DO
      SET i = i - 1;
      SET try_s = TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(data_s, d, i), d, 1)); -- next token

      IF (try_s RLIKE '.*[Gg][Rr][Oo][^[:digit:]]+[#]?[[:digit:]-]{8,15}[^[:digit:]]*')
      THEN -- Groupon code
        ITERATE start1;
      END IF;

      IF (try_s RLIKE '^99[[:digit:]]{3}$')
      THEN -- AK Zip                                    -- put at front
        SET candidates = CONCAT(candidates, try_s, o);
        SET zc = zc + 1;
        LEAVE start1;
      END IF;

      IF (try_s RLIKE '^99[[:digit:]]{3}[-][[:digit:]]{3,4}$')
      THEN -- AK Zip+4
        SET candidates = CONCAT(candidates, SUBSTRING(try_s,1,5),o );
        SET zc = zc + 1;
        LEAVE start1;
      END IF;

      IF (try_s RLIKE '^[[:digit:]]{5}$')
      THEN -- Zip
        SET candidates = CONCAT(candidates, try_s, o );
        SET zc = zc + 1;
        ITERATE start1;
      END IF;

      IF (try_s RLIKE '^[[:digit:]]{5}[-][[:digit:]]{4}$')
      THEN -- Zip+4
        SET candidates = CONCAT(candidates, SUBSTRING(try_s, 1, 5), o );
        SET zc = zc + 1;
        ITERATE start1;
      END IF;

      IF (try_s RLIKE '^[[:digit:]]{7,7}$')
      THEN -- Possible Intl code
        SET candidates = CONCAT(candidates, try_s, o );
        SET zc = zc + 1; -- Postcode num
        ITERATE start1;
      END IF;

    END WHILE;

    -- Phase 2, Try verify, Only for US
    SET candidates=utility.chop_last(o,candidates);
SET @CCC=candidates;
    SET i = zc;
    start2:
    WHILE (i > 0) DO
      SET try_s = SUBSTRING_INDEX(SUBSTRING_INDEX(candidates, o, i), o, -1);
      SET fresult = location.lookup_zip( try_s, o );
      IF (fresult IS NULL)
      THEN
        SET i = i - 1;
        ITERATE start2;
      ELSE
        IF ( LOCATE(country,fresult) ) THEN                 -- Prefer default country (should be State!)
            SET first_result=fresult;
            SET z_found = i;
            LEAVE start2;
        ELSE
            IF ( NOT z_found )  THEN                        -- Remember 1st match (from end)
                SET z_found = i;
                SET first_result=fresult;
            END IF;
        END IF;
      END IF;
      SET i = i - 1;
    END WHILE;

    IF (zc) THEN
      IF ( NOT z_found )
      THEN                                                  -- Just return 1st zip-like token encountered
        RETURN SUBSTRING_INDEX(SUBSTRING_INDEX(candidates,o,-1),o,1);
      ELSE
        RETURN first_result;
      END IF;
    END IF;

    RETURN NULL;

  END
//
DELIMITER ;
SHOW WARNINGS;


-- Extract UNLABLED State from custdata - to be used on records that do NOT already have "State:" in custdata
-- Not Implemented...
DELIMITER //
DROP FUNCTION IF EXISTS xtractstate2 //
CREATE FUNCTION xtractstate2(custdata TEXT)
  RETURNS VARCHAR(31)
  BEGIN
    DECLARE T1, T2 TEXT;
    DECLARE look1, done, len INT DEFAULT 0;
    DECLARE state_s VARCHAR(31) DEFAULT '';
    RETURN NULL;
    SET T1 = REPLACE(custdata, '\n', '\r');
    SET T1 = REPLACE(T1, '\r', '|');

    start1:
    WHILE (NOT done AND look1 > -11) DO
      SET look1 = look1 - 1;
      SET T2 = SUBSTRING_INDEX(strippunc("- ", SUBSTRING_INDEX(T1, '|', look1)), '|', 1);

      SET len = LENGTH(T2);

      IF (len < 2)
      THEN
        ITERATE start1;
      END IF;

      IF (T2 RLIKE '^[[:digit:]]{5,5}-[[:digit:]]{4}$')
      THEN
        SET done = 1;
      END IF;

      IF (T2 RLIKE '^[[:digit:]]{5,5}$')
      THEN
        SET done = 1;
      END IF;

    END WHILE;

    IF (done)
    THEN
      RETURN T2;
    ELSE
      RETURN NULL;
    END IF;
  END
//
DELIMITER ;
SHOW WARNINGS;

-- Extract UNLABLED City from custdata - to be used on records that do NOT already have "City:" in custdata
-- Not Implemented...
DELIMITER //
DROP FUNCTION IF EXISTS xtractcity2 //
CREATE FUNCTION xtractcity2(custdata TEXT)
  RETURNS VARCHAR(31)
  BEGIN
    DECLARE T1, T2 TEXT;
    DECLARE look1, done, len INT DEFAULT 0;
    DECLARE state_s VARCHAR(31) DEFAULT '';

    RETURN NULL;
    SET T1 = REPLACE(custdata, '\n', '\r');
    SET T1 = REPLACE(T1, '\r', '|');

    start1:
    WHILE (NOT done AND look1 > -11) DO
      SET look1 = look1 - 1;
      SET T2 = SUBSTRING_INDEX(strippunc("- ", SUBSTRING_INDEX(T1, '|', look1)), '|', 1);

      SET len = LENGTH(T2);

      IF (len < 2)
      THEN
        ITERATE start1;
      END IF;

      IF (T2 RLIKE '^[[:digit:]]{5,5}-[[:digit:]]{4}$')
      THEN
        SET done = 1;
      END IF;

      IF (T2 RLIKE '^[[:digit:]]{5,5}$')
      THEN
        SET done = 1;
      END IF;

    END WHILE;

    IF (done)
    THEN
      RETURN T2;
    ELSE
      RETURN NULL;
    END IF;
  END
//
DELIMITER ;
SHOW WARNINGS;

-- Extract UNLABLED Street from custdata - to be used on records that do NOT already have "Address:" in custdata
-- Not Implemented...
DELIMITER //
DROP FUNCTION IF EXISTS xtractstreet2 //
CREATE FUNCTION xtractstreet2(custdata TEXT)
  RETURNS VARCHAR(31)
  BEGIN
    DECLARE T1, T2 TEXT;
    DECLARE look1, done, len INT DEFAULT 0;
    DECLARE state_s VARCHAR(31) DEFAULT '';

    RETURN NULL;
    SET T1 = REPLACE(custdata, '\n', '\r');
    SET T1 = REPLACE(T1, '\r', '|');

    start1:
    WHILE (NOT done AND look1 > -11) DO
      SET look1 = look1 - 1;
      SET T2 = SUBSTRING_INDEX(strippunc("- ", SUBSTRING_INDEX(T1, '|', look1)), '|', 1);

      SET len = LENGTH(T2);

      IF (len < 2)
      THEN
        ITERATE start1;
      END IF;

      IF (T2 RLIKE '^[[:digit:]]{5,5}-[[:digit:]]{4}$')
      THEN
        SET done = 1;
      END IF;

      IF (T2 RLIKE '^[[:digit:]]{5,5}$')
      THEN
        SET done = 1;
      END IF;

    END WHILE;

    IF (done)
    THEN
      RETURN T2;
    ELSE
      RETURN NULL;
    END IF;
  END
//
DELIMITER ;
SHOW WARNINGS;

-- ======================================================================================
-- Generalized extractor for subfield data from `paymentlog` field (VikBooking).
-- There are 2 entry versions in the table, we try to accomodate both styles
-- There are only 2 useful fields in the older style log: "First Name" and "Last Name"
-- Log subfields are terminated by a single <newline> char "\n"
--
-- There may be multiple entries in the `paymentlog`, with last one first (reverse order)
-- We probably will get info from the first (latest) entry.
--
-- * Example fields for long style:   ( NOTE: url-encoding of subfield values )
--
-- mc_gross: 40.00
-- protection_eligibility: Ineligible
-- payer_id: WTPLXJ4FLBLLE
-- tax: 0.00
-- payment_date: 19%3A11%3A12+May+23%2C+2015+PDT
-- payment_status: Completed
-- charset: windows-1252
-- first_name: Mr. Test
-- mc_fee: 1.46
-- notify_version: 3.8
-- custom:
-- payer_status: unverified
-- business: montanacreek%40mtaonline.net
-- quantity: 1
-- verify_sign: AOZG.611erBSpIqNMqYg4NettnqLAOGlcNLKLNJv8c-efXn28-iOyhmH
-- payer_email: testuser%40gci.net
-- txn_id: 201687285J379572V
-- payment_type: instant
-- last_name: User
-- receiver_email: montanacreek%40mtaonline.net
-- payment_fee: 1.46
-- receiver_id: DQ8VXGVMTBWZA
-- txn_type: web_accept
-- item_name: Campsite+Reservation
-- mc_currency: USD
-- item_number:
-- residence_country: US
-- receipt_id: 1051-2797-8265-7775
-- handling_amount: 0.00
-- transaction_subject:
-- payment_gross: 40.00
-- shipping: 0.00
-- ipn_track_id: b183470427fc5
--
-- The old short style:
--
-- 2015-07-29T15:29:06-05:00
-- Credit Card Number: XXXXXXXXXXXXXXXX
-- Valid Through (mm/yy): 09/16
-- CVV: *** (Sent via eMail)
-- First Name: Mr. Test
-- Last Name: User
-- -----------------------------------------------------------------------------


DELIMITER //
DROP FUNCTION IF EXISTS plogfield //
CREATE FUNCTION plogfield(field VARCHAR(31), log TEXT)
  RETURNS VARCHAR(255)
  BEGIN
    DECLARE search_s VARCHAR(31);
    DECLARE fresult VARCHAR(255) DEFAULT NULL;
    DECLARE pos,eol,search_l INT;

    IF ( log IS NULL OR field IS NULL )
    THEN
        RETURN NULL;
    END IF;

    SET search_s = field;

    IF (NOT LOCATE(":", field))
    THEN -- add trailing delimiter as all log fields should have it
      SET search_s = CONCAT(TRIM(field), ': ');
    END IF;
    SET search_l = LENGTH(search_s);
    -- try bare search first
    SET pos =  LOCATE(search_s, log);
    IF (NOT pos)
    THEN
      IF (LOCATE('_', field))
      THEN -- has underscore, try without
        SET search_s = REPLACE(search_s, '_', ' ');
      ELSE -- no underscore, try with one
        SET search_s = CONCAT(SUBSTR(search_s, 1, LOCATE(' ', search_s) - 1), '_', SUBSTRING_INDEX(search_s, ' ', -2));
      END IF;
      SET pos = LOCATE(search_s, log);
    END IF;
    IF (pos) THEN
        SET eol = LOCATE('\n',log,pos);
        SET fresult = SUBSTRING(log, pos + search_L,eol-pos-search_l);
        SET fresult = REPLACE(fresult,'+',' ');
        IF (field LIKE '%email%')           -- Attempt to cope with url-encode
        THEN
            SET fresult = REPLACE(fresult, '%40', '@');
        END IF;
        SET fresult = REPLACE(fresult, '%27',"'");    -- Single quote
    END IF;

    RETURN fresult;

  END
//
DELIMITER ;
SHOW WARNINGS;

-- Normalize City name
-- Not Implemented...
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

    RETURN utility.normname(fresult,0);
  END
//
DELIMITER ;
SHOW WARNINGS;

-- ======================================================================
-- Lookup country-2 code from list
--
-- Accepts:  One or more delimiter-separated country names, country codes
--
-- Returns: 2-letter code, or default selection if nothing matched
-- ----------------------------------------------------------------------
DELIMITER //
DROP FUNCTION IF EXISTS country_select //
CREATE FUNCTION country_select( country VARCHAR(63), default_selection VARCHAR(2)  )
  RETURNS VARCHAR(2)
  BEGIN
    DECLARE country_2_code_r CHAR(2) DEFAULT NULL;

    IF ( LENGTH(country) < 2 OR country IS NULL )
    THEN
      RETURN default_selection;
    END IF;

      BEGIN
        SELECT
          `country_2_code`
        INTO country_2_code_r
        FROM `6rw_vikbooking_countries`
        WHERE
          `country_name` LIKE country
          OR
          `country_3_code` LIKE country
          OR
          `country_2_code` LIKE country
        LIMIT 1;
      END;

    RETURN IFNULL(country_2_code_r,default_selection);
  END
//
DELIMITER ;
SHOW WARNINGS;

-- ======================================================================
-- Lookup country info from list
--
-- Accepts:  One or more delimiter-separated country names/codes
--
-- Returns: delim-separated list of country info for first found country:
--   country_name,country_2_code,country_3_code,o,phone_prefix_r
-- 
-- Returns: NULL if default selection is not matched
-- ----------------------------------------------------------------------
DELIMITER //
DROP FUNCTION IF EXISTS country_info_select //
CREATE FUNCTION country_info_select( countries VARCHAR(255), default_selection VARCHAR(63), delim VARCHAR(1)  )
  RETURNS VARCHAR(255)
  BEGIN
    DECLARE d VARCHAR(1) DEFAULT delim;                     -- input delimiter
    DECLARE country_s VARCHAR(127) DEFAULT NULL;
    DECLARE i, n  INT DEFAULT 0;
    DECLARE country_name_r VARCHAR(255) DEFAULT NULL;
    DECLARE country_3_code_r CHAR(5) DEFAULT NULL;
    DECLARE country_2_code_r CHAR(4) DEFAULT NULL;
    DECLARE phone_prefix_r VARCHAR(15) DEFAULT NULL;

    IF ( LENGTH(countries) < 2 OR countries IS NULL )
    THEN
      RETURN default_selection;
    END IF;

    IF ( d != '' AND d IS NOT NULL ) THEN
        SET n = utility.countdelim(d, countries) + 1;
    ELSE
        SET d = '';
        SET n = 1;
    END IF;

start1:
    WHILE (i < n) DO
      SET i = i + 1;
      SET country_s = SUBSTRING_INDEX(SUBSTRING_INDEX(countries, d, i), d, -1);
      SET country_2_code_r = NULL;
      BEGIN
        SELECT
          `country_name`,
          `country_3_code`,
          `country_2_code`,
          `phone_prefix`
        INTO country_name_r, country_3_code_r, country_2_code_r, phone_prefix_r
        FROM `6rw_vikbooking_countries`
        WHERE
          `country_name` LIKE country_s
          OR
          `country_3_code` LIKE country_s
          OR
          `country_2_code` LIKE country_s
        LIMIT 1;
      END;

      IF ( country_2_code_r IS NOT NULL ) THEN
        LEAVE start1;
      END IF; 

    END WHILE;

    IF ( country_2_code_r IS NULL ) THEN
      BEGIN
        SELECT
          `country_name`,
          `country_3_code`,
          `country_2_code`,
          `phone_prefix`
        INTO country_name_r, country_3_code_r, country_2_code_r, phone_prefix_r
        FROM `6rw_vikbooking_countries`
        WHERE
          `country_name` LIKE default_selection
          OR
          `country_3_code` LIKE default_selection
          OR
          `country_2_code` LIKE default_selection
        LIMIT 1;
      END;
    END IF;

    RETURN CONCAT(country_name_r,d,country_2_code_r,d,country_3_code_r,d,phone_prefix_r);

  END
//
DELIMITER ;
SHOW WARNINGS;




-- ====================================================================
-- Find names associated with an `order` record.
--
-- 1) Search custdata field/subfields
-- 2) Search paymentlog
-- 3) Search custdata as "free text", if (1) did not work
-- 4) Punt
--
-- Returns colon-separated string of found names
-- NULL, if none found
--
-- To test:
-- select id, findnames(@CD_FIELDS_ALLOWED,custdata,paymentlog,'|') 
--              from `6rw_vikbooking_orders`;
-- -------------------------------------------------------------------

DELIMITER //
DROP PROCEDURE IF EXISTS findnames //
CREATE PROCEDURE         findnames(  OUT firstnames VARCHAR(255),OUT cnt_fn INT, OUT lastnames VARCHAR(255),OUT cnt_ln INT, cd_fields VARCHAR(255), custdata TEXT, paymentlog TEXT, delim VARCHAR(1) )
  BEGIN
    DECLARE o VARCHAR(1) DEFAULT delim;                    -- output delimeter
    DECLARE cname, cname_first, cname_last VARCHAR(255) DEFAULT '';
    DECLARE fresult VARCHAR(255) DEFAULT '';
    DECLARE found_cd, found_plog, results_f,results_l INT DEFAULT 0;
    DECLARE pname,
            name_s,
            fname,
            lname    VARCHAR(63);
--    DECLARE firstnames,
--            lastnames   VARCHAR(255) DEFAULT '';
    SET firstnames='', lastnames='';

    -- Normal Custdata

    IF (LENGTH(cd_fields))
    THEN
        IF (LOCATE(',Last Name,', cd_fields))            -- There's only a few of these
        THEN
            SET cname_last = utility.normname(xtract_cd_field('Last Name', custdata),1);
            IF ( cname_last != '' ) THEN
                SET lastnames=cname_last;
                SET results_l = results_l + 1;
            END IF;
            IF (LOCATE(',Name,', cd_fields))
            THEN
                SET cname_first = utility.normname(xtract_cd_field('Name', custdata),0);
                IF ( cname_first != '' ) THEN
                    SET firstnames=cname_first;
                    SET results_f = results_f + 1;
                END IF;
            END IF;
        ELSE      -- No "Last Name:" tag
            IF (LOCATE(',Name,', cd_fields) )
            THEN
                SET cname = xtract_cd_field('Name', custdata);
                SET pname = utility.parsename(cname,o);
                SET cname_first = SUBSTRING_INDEX(pname,o,1);
                SET cname_last  = SUBSTRING_INDEX(pname,o,-1);
                IF ( cname_first != '' ) THEN
                    SET firstnames=cname_first;
                    SET results_f = results_f + 1;
                END IF;
                IF ( cname_last != '' ) THEN
                    SET lastnames=cname_last;
                    SET results_l = results_l + 1;
                END IF;
            END IF;
        END IF;
    END IF;
    -- Paymentlog

    IF ( paymentlog IS NOT NULL )
    THEN
      SET cname_first = utility.normname(plogfield('first_name', paymentlog),0);
      SET cname_last  = utility.normname(plogfield('last_name',  paymentlog),1);
      IF (cname_first IS NOT NULL AND cname_last IS NOT NULL )
      THEN
        IF ( LENGTH( cname_first ) AND LENGTH( cname_last )) THEN
            SET found_plog = 1;
            SET cname = CONCAT(cname_first,' ',cname_last);
            SET pname = utility.parsename(cname,o);
            SET cname_first = SUBSTRING_INDEX(pname,o,1);
            SET cname_last  = SUBSTRING_INDEX(pname,o,-1);
            IF ( NOT LOCATE(cname_first,firstnames)) THEN
                    SET firstnames = CONCAT( cname_first,o,firstnames );
                    SET results_f = results_f + 1;
            END IF;
            IF ( NOT LOCATE(cname_last,lastnames)) THEN
                    SET lastnames = CONCAT( cname_last,o,lastnames );
                    SET results_l = results_l + 1;
            END IF;
        END IF;
      END IF;
    END IF;

    -- Abnormal custdata

    IF ( custdata IS NOT NULL AND  NOT ( results_l  AND results_f )) 
    THEN
      SET cname = xtractname(custdata);         -- Not normalized ( not list )
      IF ( cname IS NOT NULL AND LENGTH(cname) )
      THEN
        SET pname = utility.parsename(cname,o);
        SET cname_first = SUBSTRING_INDEX(pname,o,1);
        SET cname_last  = SUBSTRING_INDEX(pname,o,-1);
        IF ( cname_first != '' AND NOT LOCATE(cname_first,firstnames) ) THEN
            SET firstnames = CONCAT(cname_first,o,firstnames);
            SET results_f = results_f + 1;
        END IF;
        IF ( cname_last != '' AND NOT LOCATE(cname_last,lastnames)) THEN
            SET lastnames=CONCAT(cname_last,o,lastnames);
            SET results_l = results_l + 1;
        END IF;            
      END IF;
    END IF;

    SET firstnames = utility.chop_last(o,firstnames);        -- del last delimiter
    SET lastnames = utility.chop_last(o,lastnames);         -- del last delimiter
    SET cnt_fn = results_f;
    SET cnt_ln = results_l;
  END
//
DELIMITER ;
SHOW WARNINGS;


DELIMITER //
DROP FUNCTION IF EXISTS findnames //
CREATE FUNCTION         findnames(  cd_fields VARCHAR(255), custdata TEXT, paymentlog TEXT, delim VARCHAR(1) )
    RETURNS TEXT
  BEGIN
    DECLARE o VARCHAR(1) DEFAULT delim;
    DECLARE firstnames, lastnames VARCHAR(255);
    DECLARE cnt_fn, cnt_ln INT;

    call findnames(firstnames,cnt_fn,lastnames,cnt_ln,cd_fields,custdata, paymentlog, delim );

    RETURN CONCAT( cnt_fn,o,firstnames,':',cnt_ln,o,lastnames ); 

  END
//
DELIMITER ;
SHOW WARNINGS;


-- ====================================================================
-- Find email addresses associated with an `order` record.
--
-- 1) Check `custmail` field
-- 2) Search custdata field/subfields
-- 3) Search paymentlog
-- 3) Search custdata as "free text", if (2) did not work
-- 4) Punt
--
-- Returns:
--
-- * Delimiter-separated string of email addresses
-- 
-- * NULL, if none found
--
-- Attempts to avoid duplicates
-- -------------------------------------------------------------------

DELIMITER //
DROP FUNCTION IF EXISTS findemails //
CREATE FUNCTION findemails(cd_fields VARCHAR(255),custdata TEXT,paymentlog TEXT,custmail VARCHAR(63),delim VARCHAR(1) )
  RETURNS VARCHAR(511)
  BEGIN

    DECLARE o VARCHAR(1) DEFAULT delim;                     -- output delimter
    DECLARE email VARCHAR(255) DEFAULT NULL;
    DECLARE fresult VARCHAR(511) DEFAULT '';
    DECLARE found_cm, found_cd, found_plog, results INT DEFAULT 0;

    -- custmail field

    IF (custmail IS NOT NULL AND LENGTH(custmail) )
    THEN
      SET fresult = CONCAT(utility.normemail(custmail), o);
      SET results = results + 1;
      SET found_cm = 1;
    END IF;

    -- Normal Custdata

    IF (LOCATE(',e-Mail,', cd_fields))
    THEN
      SET email = utility.normemail(xtract_cd_field('e-Mail', custdata));
      IF ( email IS NOT NULL )
      THEN
        IF ( LENGTH( email )) THEN
             SET found_cd = 1;
            IF ( NOT LOCATE(LOWER(email), LOWER(fresult)) )
            THEN
                SET fresult = CONCAT(fresult, email, o);
                SET results = results + 1;
            END IF;
        END IF;
      END IF;
    END IF;

    -- Paymentlog

    IF ( paymentlog IS NOT NULL )
    THEN
      SET email = utility.normemail(plogfield('payer_email', paymentlog));
      IF ( email IS NOT NULL ) THEN
        IF ( LENGTH(email) ) THEN
            SET found_plog = 1;            
            IF ( NOT LOCATE(LOWER(email), LOWER(fresult))) THEN
                SET fresult = CONCAT(fresult, email, o);
                SET results = results + 1;
            END IF;
        END IF;
      END IF;
    END IF;

    -- Abnormal custdata

    IF (NOT found_cd)
    THEN
      SET email = xtractemail2(custdata, o);            -- already normalized
      IF ( email IS NOT NULL ) THEN
        IF ( LENGTH(email) ) THEN
            SET found_cd = 1;
            IF ( NOT LOCATE(LOWER(email), LOWER(fresult))) THEN
                SET fresult = CONCAT(fresult, email, o);
                SET results = results + 1;
            END IF;
        END IF;
      END IF;
    END IF;

    IF ( results )
    THEN
      RETURN utility.chop_last(o, fresult);                 -- drop trailing delimiter
    ELSE
      RETURN NULL;
    END IF;

  END
//
DELIMITER ;
SHOW WARNINGS;



-- ====================================================================
-- Find phone numbers associated with an `order` record.
--
-- 1) Check `custmail` field
-- 2) Search custdata field/subfields
-- 3) Search paymentlog
-- 3) Search custdata as "free text", if (2) did not work
-- 4) Punt ( return default )
--
-- Returns:
--
-- * Delimiter-separated string of "normailzed" phone numbers
--
-- * NULL, if none found
--
-- Attempts to avoid duplicates
--
--  To test:
-- select id,findphones(@CD_FIELDS_ALLOWED,clean_cd(custdata),paymentlog,phone,@DEFAULT_AREACODE,@DEFAULT_COUNTRY_A,'|') from `6rw_vikbooking_orders`;
-- --------------------------------------------------------------------

DELIMITER //
DROP FUNCTION IF EXISTS findphones //
CREATE FUNCTION findphones(cd_fields VARCHAR(255),custdata TEXT,paymentlog TEXT,phone VARCHAR(31),area_default VARCHAR(5),country VARCHAR(2),delim VARCHAR(1) )
  RETURNS VARCHAR(255)
  BEGIN
    DECLARE area VARCHAR(5) DEFAULT area_default;
    DECLARE o VARCHAR(1) DEFAULT delim;                                 -- output delimiter
    DECLARE phone_s VARCHAR(255) DEFAULT NULL;
    DECLARE fresult VARCHAR(511) DEFAULT '';
    DECLARE found_cd, found_plog, found_ph, results INT DEFAULT 0;



    -- Normal Custdata

    IF ( custdata IS NOT NULL AND LOCATE(',Phone,', cd_fields))
      THEN
        SET phone_s = utility.normphone(xtract_cd_field('Phone', custdata), area, country);
        IF ( phone_s IS NOT NULL ) THEN
            IF ( LENGTH(phone_s) ) THEN
                SET found_cd = 1;
                IF ( NOT LOCATE(phone_s, fresult)) THEN
                    SET fresult = CONCAT(fresult, phone_s, o);
                    SET results = results + 1;
                END IF;
            END IF;
        END IF;
    END IF;


    -- `phone` field


    IF ( phone IS NOT NULL AND phone != '' ) THEN
        SET phone_s = utility.normphone(phone,area,country);
        IF ( phone_s IS NOT NULL AND phone_s != '' ) THEN
            SET found_ph = 1;
            IF ( NOT LOCATE(phone_s, fresult)) THEN
                SET fresult = CONCAT(phone_s, o);
                SET results = results + 1;
            END IF;
        END IF;
    END IF;


    -- Paymentlog

    IF ( paymentlog IS NOT NULL )
    THEN
      SET phone_s = utility.normphone(plogfield('payer_phone', paymentlog), area,country);
      IF ( phone_s IS NOT NULL )  THEN
        IF ( LENGTH( phone_s )) THEN
            SET found_plog = 1;
            IF ( NOT LOCATE(phone_s, fresult)) THEN
                SET fresult = CONCAT(fresult, phone_s, o);
                SET results = results + 1;
            END IF;
        END IF;
      END IF;
    END IF;

    -- Abnormal custdata

    IF (NOT found_cd AND custdata IS NOT NULL )
    THEN
      SET phone_s = xtractphone2(custdata, area, country, o);                    -- Already normailzed
      IF ( phone_s IS NOT NULL ) THEN
        IF ( LENGTH(phone_s)) THEN
            SET found_cd = 2;
            IF ( NOT LOCATE(phone_s, fresult)) THEN
                SET fresult = CONCAT(phone_s, o);
                SET results = results + 1;
            END IF;
        END IF;
      END IF;
    END IF;

    IF ( results )
    THEN
      RETURN utility.chop_last(o,fresult); -- drop trailing delimiter
    ELSE
      RETURN NULL;
    END IF;

  END
//
DELIMITER ;
SHOW WARNINGS;



-- Search various locations for Country info

DELIMITER //
DROP FUNCTION IF EXISTS findaddress_country //
CREATE FUNCTION findaddress_country(cd_fields VARCHAR(255),custdata TEXT,paymentlog TEXT,phones VARCHAR(255),country VARCHAR(255), default_country VARCHAR(2),delim VARCHAR(1) )
  RETURNS VARCHAR(2)
  BEGIN

    DECLARE o VARCHAR(1) DEFAULT delim;
    DECLARE country_r, country_s, country_field, country_cd, country_plog VARCHAR(255) DEFAULT NULL;
    DECLARE phone_l VARCHAR(255) DEFAULT NULL;
    DECLARE sph,areacode,tmp VARCHAR(63) DEFAULT NULL;
    DECLARE fresult VARCHAR(255) DEFAULT '';
    DECLARE i,n,found_plog, found_co, found_cd_co, found_plog_co, results INT DEFAULT 0;

    -- `country` field

    IF (country IS NOT NULL AND country != '')
    THEN
      SET country_field = country;
      SET fresult = CONCAT(country, o,fresult);
      SET results = results + 1;
      SET found_co = 1;
    END IF;

    -- Normal `custdata`, Country

    IF ( LOCATE(',Country,', cd_fields))
    THEN
      SET country_cd = xtract_cd_field('Country', custdata);

      IF ( country_cd IS NOT NULL AND country_cd != '')
      THEN
        SET fresult = CONCAT(fresult, country_cd, o);
        SET results = results + 1;
        SET found_cd_co = 1;
      END IF;
    END IF;

    -- `paymentlog`, Country

    IF ( paymentlog IS NOT NULL )
    THEN
      SET country_plog = plogfield('residence_country', paymentlog);
      IF (country_plog != '')
      THEN
        SET fresult = CONCAT(fresult, country_plog, o);
        SET results = results + 1;
        SET found_plog_co = 1;
      END IF;
    END IF;

    -- Abnormal `custdata`, Country

--     IF (custdata IS NOT NULL AND NOT found_cd_co)
--     THEN
-- 
--       SET country_s = xtractcountry2(custdata, default_country);
--       IF ( country_s IS NOT NULL AND country_s != '')
--       THEN
--         SET fresult = CONCAT(fresult, country_s, o);
--         SET results = results + 1;
--       END IF;
--     END IF;

    -- Lookup by phone?
    IF ( NOT results AND phones IS NOT NULL  )  THEN
            SET n = utility.listlen(phones,o);
start1:
        WHILE ( i < n ) DO
            SET i = i + 1;
            SET sph = SUBSTRING_INDEX(SUBSTRING_INDEX(phones,o,i),o,-1);
            IF ( sph  RLIKE  '^[+]?[1]?[[:digit:]]{10}$' )  THEN      -- 10-digit, with optional lead '1'
              SET tmp=SUBSTRING(sph,-10,3);
              SET areacode=`location`.lookup_areacode(tmp,o);
              IF ( areacode IS NOT NULL ) THEN
                SET fresult = CONCAT( default_country, o, fresult);
                SET results = results + 1;
              END IF;
              ITERATE start1;
            END IF;
            IF ( sph RLIKE  '^[0]{0,2}[1]{0,2}[[:digit:]]{11,13}$' )  THEN  -- 11+ digits, with optional lead '1s','0s'
                SET country_s = lookup_country2_phone(sph);
                IF ( country_s IS NOT NULL ) THEN
                    SET fresult = CONCAT( country_s, o, fresult);
                    SET results = results + 1;
      --              LEAVE start1;
                END IF;
           END IF;
        END WHILE;
    END IF;

    IF ( NOT results )  THEN
        RETURN default_country;
    END IF;
    SET fresult = country_info_select(utility.chop_last(o,fresult), default_country,o);
    RETURN SUBSTRING_INDEX(SUBSTRING_INDEX(fresult,o,2),o,-1);

  END
//
DELIMITER ;
SHOW WARNINGS;

-- Find zipcode, if any exist
-- Returns a single zipcode
-- Or, NULL if zipcode cannot be determined
--
-- To test:
-- select id, findaddress_zipcode(get_cd_fields(@CD_FIELDS_ALLOWED,custdata),clean_cd(custdata),':') from 6rw_vikbooking_orders;
--
DELIMITER //
DROP FUNCTION IF EXISTS findaddress_zipcode //
CREATE FUNCTION findaddress_zipcode(cd_fields VARCHAR(255), custdata TEXT, country VARCHAR(127), default_country VARCHAR(2), o VARCHAR(1) )
  RETURNS VARCHAR(255)
  BEGIN

    DECLARE zip_s VARCHAR(255) DEFAULT NULL;
    DECLARE fresult, zip_record VARCHAR(255) DEFAULT NULL;
    DECLARE found_cd_zip, l INT DEFAULT 0;

    -- Normal `custdata`

    IF (LENGTH(cd_fields))
    THEN
      IF (LOCATE(',Zip Code,', cd_fields))
      THEN
        SET zip_s = xtract_cd_field('Zip Code', custdata);
        IF (zip_s != '')
        THEN
          IF ( country = default_country OR country IS NULL OR country = '')  THEN
            SET zip_record = location.lookup_zip( zip_s, o );
            IF ( zip_record IS NOT NULL )  THEN
                RETURN zip_record;
            ELSE
                RETURN zip_s;
            END IF;
          ELSE
            RETURN zip_s;
          END IF;
        END IF;
      END IF;
    END IF;

    -- Abnormal `custdata`
    SET zip_record = xtractzip(custdata, NULL, o);
    IF (zip_record IS NOT NULL)
    THEN
      RETURN zip_record;
    END IF;

    RETURN NULL;

  END
//
DELIMITER ;
SHOW WARNINGS;

-- Find state, if any exist
-- Returns a single state
-- Or, NULL if state cannot be determined

DELIMITER //
DROP FUNCTION IF EXISTS findaddress_state //
CREATE FUNCTION findaddress_state(cd_fields VARCHAR(255), custdata TEXT, zipcode_s VARCHAR(15) )
  RETURNS VARCHAR(31)
  BEGIN

    DECLARE state_s VARCHAR(63) DEFAULT NULL;

    -- Normal `custdata`

    IF (LOCATE(',State,', cd_fields)) THEN
      SET state_s = xtract_cd_field('State', custdata);
    END IF;

    -- Abnormal `custdata`, State  ( last resort )

--     IF ( state_s IS NULL OR state_s = '' ) THEN
--         SET state_s = xtractstate2(custdata);
--     END IF;

    IF ( state_s IS NULL OR state_s = '' AND zipcode_s IS NOT NULL AND zipcode_s != '' ) THEN
        SET state_s = location.lookup_zip_state_a( zipcode_s );
    END IF;

    IF ( state_s IS NOT NULL AND state_s != '' ) THEN
        IF ( LENGTH(state_s)>2 ) THEN
            RETURN location.lookup_state_state_a(state_s);
        ELSE
            RETURN UPPER(state_s);
        END IF;
    END IF;

    RETURN NULL;

  END
//
DELIMITER ;
SHOW WARNINGS;

-- Find state, if any exist
-- Returns a single state
-- Or, NULL if state cannot be determined
--

DELIMITER //
DROP FUNCTION IF EXISTS findaddress_city //
CREATE FUNCTION findaddress_city(cd_fields VARCHAR(255), custdata TEXT, zipcode VARCHAR(15) )
  RETURNS VARCHAR(255)
  BEGIN

    DECLARE city_s VARCHAR(255) DEFAULT NULL;

    -- Normal Custdata, City

    IF (LOCATE(',City,', cd_fields))
    THEN
      SET city_s = xtract_cd_field('City', custdata);
      IF (city_s != '')
      THEN
        RETURN normcity(city_s);
      END IF;
    END IF;

    -- Abnormal custdata, City  ( only as a last resort )

    SET city_s = xtractcity2(custdata);
    IF (city_s != '')
    THEN
        RETURN normcity(city_s);
    END IF;

    RETURN NULL;

  END
//
DELIMITER ;
SHOW WARNINGS;

-- Find state, if any exist
-- Returns a single state
-- Or, NULL if state cannot be determined
--

DELIMITER //
DROP FUNCTION IF EXISTS findaddress_street //
CREATE FUNCTION findaddress_street(cd_fields VARCHAR(255), custdata TEXT )
  RETURNS VARCHAR(255)
  BEGIN

    DECLARE street_s VARCHAR(255) DEFAULT NULL;
    DECLARE fresult VARCHAR(255) DEFAULT '';
    DECLARE found_cd_st, l INT DEFAULT 0;

    -- Normal `custdata`

    IF (LOCATE(',Address,', cd_fields))
    THEN
      SET street_s = xtract_cd_field('Address', custdata);
      IF ( street_s IS NOT NULL AND street_s != '')
      THEN
        SET fresult = street_s;
        SET found_cd_st = 1;
      END IF;
    END IF;

    -- Abnormal `custdata`  ( only as a last resort )

    IF (NOT found_cd_st)
    THEN
      SET street_s = xtractstreet2(custdata);
      IF ( street_s IS NOT NULL AND street_s != '')
      THEN
        SET fresult = street_s;
      END IF;
    END IF;

    IF ( fresult != '' )
    THEN
      RETURN utility.normname(fresult, 0);
    ELSE
      RETURN NULL;
    END IF;

  END
//
DELIMITER ;
SHOW WARNINGS;



--
-- Create a subset of custom fields inculding:
--
--  ORDER_ADDRESS, ORDER_ZIP, ORDER_CITY, ORDER_STATE, COUNTRY
--
-- These map respectively to Square fields:
--  address1
--  post
--  city
--  state
--  address2
--
DELIMITER // 
 DROP FUNCTION IF EXISTS vb_make_address_cfields //
 CREATE FUNCTION vb_make_address_cfields(
                                address  VARCHAR(63),
                                zip      VARCHAR(31),
                                city     VARCHAR(31),
                                state_sa VARCHAR(63),
                                country  VARCHAR(2)
                             )
    RETURNS JSON
    BEGIN

        RETURN JSON_OBJECT(
            cfield_map_name_bare('ORDER_ADDRESS'),   IFNULL(address,''),
            cfield_map_name_bare('ORDER_ZIP'),       IFNULL(zip,''),
            cfield_map_name_bare('ORDER_CITY'),      IFNULL(city,''),
            cfield_map_name_bare('ORDER_STATE'),     IFNULL(state_sa,''),
            cfield_map_name_bare('COUNTRY'),         IFNULL(country,'')
        );

    END
//
DELIMITER ;
SHOW WARNINGS;




-- Find postal/physical address associated with an `order` record.
--
--  Returns simple JSON object containing location info
--
DELIMITER //
DROP FUNCTION IF EXISTS findaddress //
CREATE FUNCTION findaddress(cd_fields VARCHAR(255),custdata TEXT,paymentlog TEXT,phones VARCHAR(255),country VARCHAR(255),default_country VARCHAR(2),delim VARCHAR(1) )
  RETURNS JSON
  BEGIN
    DECLARE o VARCHAR(1) DEFAULT delim;
    DECLARE zipcode_s, state_s, city_s, street_s VARCHAR(63) DEFAULT '';
    DECLARE zipcode_rec VARCHAR(255) DEFAULT NULL; -- May hold record
    DECLARE fresult JSON DEFAULT JSON_OBJECT();
    DECLARE country_s VARCHAR(2) DEFAULT default_country;
    DECLARE state_sa VARCHAR(63) DEFAULT '';

    -- Try to get zip first, if found, we can lookup other info from `location`.`zip` ( public Zip info )
    SET country_s = findaddress_country( cd_fields, custdata, paymentlog, phones, country, default_country, o );
    SET zipcode_rec = findaddress_zipcode(cd_fields, custdata, country_s, default_country, o);

    IF (zipcode_rec IS NOT NULL) THEN

        IF ( LOCATE(o,zipcode_rec ) ) THEN
            IF (LOCATE('verified', zipcode_rec)) THEN              -- Zip lookup-verified
-- set @zrecv=zipcode_rec;
                SET country_s = SUBSTRING_INDEX(SUBSTRING_INDEX(zipcode_rec, o, 2), o, -1);
                SET zipcode_s = SUBSTRING_INDEX(SUBSTRING_INDEX(zipcode_rec, o, 3), o, -1);
                SET city_s = SUBSTRING_INDEX(SUBSTRING_INDEX(zipcode_rec, o, 4), o, -1);
                SET state_s = SUBSTRING_INDEX(SUBSTRING_INDEX(zipcode_rec, o, 5), o, -1);
                SET state_sa = SUBSTRING_INDEX(SUBSTRING_INDEX(zipcode_rec, o, 6), o, -1);
            ELSE              -- Zip not verified, try parsing the rest
-- set @zrecn=zipcode_rec;
                SET country_s = SUBSTRING_INDEX(SUBSTRING_INDEX(zipcode_rec, o, 1), o, -1);
                SET zipcode_s = SUBSTRING_INDEX(SUBSTRING_INDEX(zipcode_rec, o, 2), o, -1);
                SET city_s = SUBSTRING_INDEX(SUBSTRING_INDEX(zipcode_rec, o, 3), o, -1);
                SET state_s = SUBSTRING_INDEX(SUBSTRING_INDEX(zipcode_rec, o, 4), o, -1);
                SET state_sa = SUBSTRING_INDEX(SUBSTRING_INDEX(zipcode_rec, o, 5), o, -1);
            END IF;
        ELSE            -- Zip record is just a code
-- set @zrecx=zipcode_rec;
            SET zipcode_s = zipcode_rec;
            SET state_sa  = findaddress_state( cd_fields, custdata, zipcode_s );
            SET city_s    = findaddress_city( cd_fields, custdata, zipcode_s );
        END IF;
    END IF;

    SET street_s  = findaddress_street( cd_fields, custdata );

    SET fresult=vb_make_address_cfields(
                            street_s,
                            zipcode_s,
                            city_s,
                            state_sa,
                            country_s
                            );
    RETURN fresult;
--    RETURN CONCAT(street_s, o, city_s, o, state_s, o, state_sa, o, zipcode_s, o, country_s);

  END
//
DELIMITER ;
SHOW WARNINGS;


-- Select "random" pin, not in the customer table
DELIMITER //
DROP FUNCTION IF EXISTS randpin //
CREATE FUNCTION randpin(min INT, max INT)
  RETURNS INT(5)
  BEGIN
    DECLARE r, k, x INT(5);

    SET x = max - min;
    SET k = 1;
    WHILE (k) DO

      SET r = ROUND((RAND() * x) + min);

      BEGIN
        SELECT COUNT(*)
        INTO k
        FROM `6rw_vikbooking_customers`
        WHERE pin = r
        LIMIT 1;
      END;

    END WHILE;

    RETURN r;
  END
//
DELIMITER ;
SHOW WARNINGS;