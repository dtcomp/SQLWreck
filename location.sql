DELIMITER ;
source global.sql
create database if not exists `location`;
use `location`;
source areacode.sql;
source zip.sql;
select 'location.sql' as 'file';
