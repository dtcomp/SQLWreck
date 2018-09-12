select concat('use ', database(),';' );
select concat('drop procedure ', routine_name, ';')
from information_schema.routines
where routine_schema = database()
and ROUTINE_TYPE='PROCEDURE'
and definer = 'root@localhost'; 

select concat('drop function ', routine_name, ';')
from information_schema.routines
where routine_schema = database()
and ROUTINE_TYPE='FUNCTION'
and definer = 'root@localhost'; 

