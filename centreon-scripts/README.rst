===========================================================
genconf.sh an handy script for massive configuration import
===========================================================

genconf.sh help importing large cinfigurations in Centreon/Nagios monitoring solution.
The data is a simple csv file (separator is ;)

Prerequisites
~~~~~~~~~~~~~

* A valid installation of Centreon/Nagios
* The centreon clapi module (http://forge.centreon.com/projects/centreon-clapi/wiki)

Note : the script should be runing on the centreon server. Not on a poller.

Usage
~~~~~

    Usage : genconf.sh -d file.data -p poller [-z actions ] [-n]
        -d    Datafile
        -p      assign hosts to poller
        -z    action(s) to do (PARENT|HOST|HOSTGROUP|ORACLE|HGHOST|DELHOST|DELHOSTSVC|HOSTTPL|MACROS)
            if more than one action is specified, it should be separated by a coma
            * PARENT : create parent association between field 1 and field 5
            * HOST : create hosts
            * HOSTGROUP : create hostgroups from field 4 
            * MACROS : Create host macros specified in field 9
            * HGHOSTS : link host with hostgroups from field 4
            * DELHOST : delete hosts defined in field 1
            * DELHOSTSVC : delete services definied in field 8 for host defined in field 1
            * HOSTTPL : apply host templates defined in field 6 so it can generate services from host template 
        -n    Do not try to resolve fqdn when inporting (address is an ip)
        -h    Show usage

        NOTE : genconf need centreon clapi

        NOTE : datafile format is follow
            1      2       3         4          5        6          7           8       9
        hostname;fqdn;description;hostgroups[;parents;templates;oracleinstances;services;macros]

        HOST require at least 1,2,3,4 if -t is omited 6 is required
        PARENT require at least 1,5 and -p 
        MACROS require at least 1 and 9
        * parents is a : separated list
        * templates is a : separated list
        * oracleinstances is a : separated list
        * services is a : separated list
        * macros is a : separated list

