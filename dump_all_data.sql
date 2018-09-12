
select concat('mysqldump -A ', schema_name, ' > ', schema_name , '-', date(now()), '_', replace(time(now()),':','-'),'.sql')
from information_schema.schemata;

