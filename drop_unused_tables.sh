#!/bin/bash -vx


mysql -s -uroot -p montanac_joom899_a < drop_unused_tables.sql | mysql -uroot -p
