#!/bin/bash

sql="GRANT ALL PRIVILEGES ON nagvis.* to 'nagvis'@'localhost' identified by 'manager';
GRANT SELECT on centreon.centreonnagvis to 'nagvis'@'localhost';
GRANT SELECT on centreon.acl_groups to 'nagvis'@'localhost';
GRANT SELECT on centreon.session to 'nagvis'@'localhost';
GRANT SELECT on centreon.acl_group_contacts_relations to 'nagvis'@'localhost';
GRANT SELECT on centreon.contact to 'nagvis'@'localhost';
GRANT SELECT on nagvis.roles to 'centreon'@'localhost';
FLUSH PRIVILEGES;"

echo $sql
