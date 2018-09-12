#!/bin/bash -vx


mysql -s montanac_joom899 < drop_all_routines.sql | mysql
mysql -s mcc_customer < drop_all_routines.sql | mysql 
mysql -s utility < drop_all_routines.sql | mysql
mysql -s location < drop_all_routines.sql | mysql
