DELIMITER ;
source vb_cfield.sql;
select 'vb_total_customers_orders.sql' as 'file';

DELIMITER // 
 DROP PROCEDURE IF EXISTS vb_total_customers_orders //
 CREATE PROCEDURE         vb_total_customers_orders()
 BEGIN
    DECLARE done            BOOLEAN DEFAULT 0;
    DECLARE vb_cid_r        INT;
    DECLARE spend_r         DECIMAL(12,2);
    DECLARE transactions_r  INT;
    DECLARE vfirst_r,
            vlast_r         DATE;
    DECLARE cfields_r,
            cfields_new     JSON;

    DECLARE cur2 CURSOR FOR
                SELECT
                    t5.id as vb_cid,
                    SUM(t6.cost) as spend,
                    COUNT(t1.idorder) as transactions,
                    DATE(FROM_UNIXTIME(MIN(ts))) as vfirst, 
                    DATE(FROM_UNIXTIME(MAX(ts))) as vlast,
                    t5.cfields
                FROM `6rw_vikbooking_customers` as t5         
                    LEFT JOIN `6rw_vikbooking_customers_orders` as t1 on t1.idcustomer=t5.id         
                    LEFT JOIN `6rw_vikbooking_orders` as t2 on t1.idorder=t2.id 
                    LEFT JOIN `6rw_vikbooking_ordersrooms` as t3 on t1.idorder=t3.idorder 
                    LEFT JOIN `6rw_vikbooking_rooms` as t4 on t3.idroom=t4.id     
                    LEFT JOIN `6rw_vikbooking_dispcost` as t6 on t6.idroom=t3.idroom  
                WHERE t2.days=t6.days AND status='confirmed'
                GROUP BY t5.id;
--                ORDER BY spend desc;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN cur2;

read_loop:
    LOOP
        FETCH cur2 INTO vb_cid_r,spend_r,transactions_r,vfirst_r,vlast_r,cfields_r;
        IF (done) THEN LEAVE read_loop; END IF;
        SET @LAST_ID=vb_cid_r;
        SET cfields_new = cfields_r;
        call cfield_set('TOTAL',  spend_r, cfields_new);
        call cfield_set('VFIRST', vfirst_r, cfields_new);
        call cfield_set('VLAST',  vlast_r,   cfields_new);
        call cfield_set('ORDERS', transactions_r, cfields_new);

        UPDATE `6rw_vikbooking_customers`
            SET `cfields`=cfields_new
            WHERE `id`=vb_cid_r;            
-- LEAVE read_loop;
    END LOOP;
    close cur2;

END;
 //
DELIMITER ;
show warnings;


-- call vb_total_customers_orders();        -- Runtime: ~ 3 minutes




