use montanac_joom899_a;

select concat('use ', database(),';' );

select concat('drop table ', table_name, ';')
from information_schema.TABLES
where table_schema = database()
and table_name not like '%vikbooking%';

