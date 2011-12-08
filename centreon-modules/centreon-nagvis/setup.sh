#!/bin/bash -e

# environnement
myscripts=$(dirname $0)
cd $myscripts
myscripts=$(pwd)
. ./setup.conf




function trap_handler()
{
        MYSELF="$0"               # equals to my script name
        LASTLINE="$1"            # argument 1: last line of error occurence
        LASTERR="$2"             # argument 2: error code of last command
	FUNCTION="$3"
	if [ -z "$3" ]
	then
        	cecho "[FATAL] Unexpected error on line ${LASTLINE}" red
	else
        	cecho "[FATAL] Unexpected error on line ${LASTLINE} in function ${FUNCTION} ($LASTERR)" red
	fi
	exit 2
}

### colorisation de texte dans un script bash ###
cecho ()                    
{

	# Argument $1 = message
	# Argument $2 = foreground color
	# Argument $3 = background color

	case "$2" in
		"black")
			fcolor='30'
			;;
		"red")
			fcolor='31'
			;;
		"green")
			fcolor='32'
			;;
		"yellow")
			fcolor='33'
			;;
		"blue")
			fcolor='34'
			;;
		"magenta")
			fcolor='35'
			;;
		"cyan")
			fcolor='36'
			;;
		"white")
			fcolor='37'
			;;
		*)
			fcolor=''
	esac	
	case "$3" in
		"black")
			bcolor='40'
			;;
		"red")
			bcolor='41'
			;;
		"green")
			bcolor='42'
			;;
		"yellow")
			bcolor='43'
			;;
		"blue")
			bcolor='44'
			;;
		"magenta")
			bcolor='45'
			;;
		"cyan")
			bcolor='46'
			;;
		"white")
			bcolor='47'
			;;
		*)
			bcolor=""
	esac	

	if [ -z $bcolor ]
	then
		echo -ne "\E["$fcolor"m"$1"\n"
	else
		echo -ne "\E["$fcolor";"$bcolor"m"$1"\n"
	fi
	tput sgr0
	return
}

deploy_module(){
	if [ -d "$CENTREON_WWW/modules/$MODULE_NAME" ]
	then 
		cecho "[FATAL] Module allready exist" red
		return 2
	else
		trap 'trap_handler ${LINENO} $? deploy_module' ERR
		mkdir -p $CENTREON_WWW/modules/$MODULE_NAME > /dev/null 2>&1
		cp -Rf ./module/* $CENTREON_WWW/modules/$MODULE_NAME > /dev/null 2>&1
		chown -R $HTTPD_USER:$HTTPD_GROUP $CENTREON_WWW/modules/nagvis > /dev/null 2>&1
		return 0
	fi
}

install_module(){
	trap 'trap_handler ${LINENO} $? install_module' ERR
	curl -s --dump-header $TMP/centreon -d "useralias=$CENTREONU&password=$CENTREONP&submit=S" $CENTREONURI/index.php > /dev/null 2>&1
	curl -b $TMP/centreon -d "submit=s&o=i&name=$MODULE_NAME" $CENTREONURI/main.php?p=507 > /dev/null 2>&1
	curl -b $TMP/centreon $CENTREONURI/index.php?disconnect=1 > /dev/null 2>&1
	mysql -h $MYSQLHOST -u $MYSQLUSER -p$MYSQLPASSWD --skip-column-names -s -e "$sqlmoduleconf"
}


uninstall_module(){
	trap 'trap_handler ${LINENO} $? uninstall_module' ERR
	IDM=$(mysql -h $MYSQLHOST -u $MYSQLUSER -p$MYSQLPASSWD --skip-column-names -s -e "select id from $CENTREONDB.modules_informations where name='$MODULE_NAME';")
	if [ ! -z $IDM ]
	then
		curl -s --dump-header $TMP/centreon -d "useralias=$CENTREONU&password=$CENTREONP&submit=S" $CENTREONURI/index.php > /dev/null 2>&1
		curl -b "$TMP/centreon" "$CENTREONURI/main.php?p=507&o=w&id=$IDM&o=d" > /dev/null 2>&1
		curl -b $TMP/centreon $CENTREONURI/index.php?disconnect=1 > /dev/null 2>&1
	fi
}


remove_module(){
	cecho "NOT IMPLEMENTED" yellow
}

do_sqlfile(){
	trap 'trap_handler ${LINENO} $? test_dbexist' ERR
	if [ -z "$1" ] 
	then
		return 2
	fi
	EXIST=$(mysql -h $MYSQLHOST -u $MYSQLUSER -p$MYSQLPASSWD --skip-column-names -s -e "select count(*) from information_schema.tables where table_schema='$CENTREONDB' and table_name='centreonnagvis';";)
	
	if [ "$EXIST" = 0 ] 
	then 
		echo 0 
	else
		echo 1 
	fi
}

test_dbexist(){
	trap 'trap_handler ${LINENO} $? test_dbexist ' ERR
	if [ -z "$1" ] 
	then
		cecho "Invalid call : you should specify database name as first argument in function call"
		return 2
	fi
	EXIST=$(mysql -h $MYSQLHOST -u $MYSQLUSER -p$MYSQLPASSWD --skip-column-names -s -e "select count(*) from information_schema.tables where table_schema='$1';";)

	if [ $EXIST -eq 0 ] 
	then
		echo 0 
	else
		echo 1
	fi
}
test_tableexist(){
	trap 'trap_handler ${LINENO} $? test_tableexist' ERR
	if [ -z "$2" ] 
	then
		cecho "Invalid call : you should specify database name as first argument and table name as second argument in function call"
		return 2
	fi

	EXISTS=$(mysql -h $MYSQLHOST -u $MYSQLUSER -p$MYSQLPASSWD --skip-column-names -s -e "select count(*) from information_schema.tables where table_schema='$1' and table_name='$2';";)
	if [ $EXISTS -eq 0 ] 
	then
		echo 0 
	else
		echo 1
	fi
}

do_sqlfile(){
	trap 'trap_handler ${LINENO} $? do_sqlfile' ERR
	if [ -z "$1" ]
	then
		cecho "[FATAL] No sql file specified" red
	else
		if [ -e "$1" ]
		then
			mysql -h $MYSQLHOST -u $MYSQLUSER -p$MYSQLPASSWD $2 < $1 
		else
			cecho "[FATAL] The specified sql file does not exist ($1)" red
			return 2
		fi
	fi
}

do_dbs(){
	trap 'trap_handler ${LINENO} $? do_dbs' ERR
	cecho " > creating table centreon nagvis in $CENTREONDB" green
	mysql -h $MYSQLHOST -u $MYSQLUSER -p$MYSQLPASSWD -e "$sqlcentreon"
	cecho " > creating database $NAGVISDB" green
	mysql -h $MYSQLHOST -u $MYSQLUSER -p$MYSQLPASSWD -e "$sqlnagvisdb"
	cecho " > populating $NAGVISDB database" green
	mysql -h $MYSQLHOST -u $MYSQLUSER -p$MYSQLPASSWD -e "$sqlacl"
	#do_sqlfile sql/nagvisdata.sql $NAGVISDB
}

clean_dbs(){
	trap 'trap_handler ${LINENO} $? clean_dbs' ERR
	mysql -h $MYSQLHOST -u $MYSQLUSER -p$MYSQLPASSWD -e "$sqlclean"
}

get_nagvis(){
	trap 'trap_handler ${LINENO} $? get_nagvis' ERR
	if [ -d $TMP/nagvis-$NAGVISVER ]
	then
		rm -Rf $TMP/nagvis-$NAGVISVER 
	fi
	cd $TMP
	if [ ! -e nagvis-$NAGVISVER.tar.gz ]
	then
		wget $NAGVISDL
	fi
	tar zxvf nagvis-$NAGVISVER.tar.gz > /dev/null 2>&1
}

deploy_nagvis(){
	if [ ! -f $GRAPHVIZBIN/dot ] 
	then
		cecho "[FATAL] unable to find graphviz binaries" red
		exit 2
	else
		cd $TMP/nagvis-$NAGVISVER
		./install.sh -q -c y -a y -s $ENGINE -n $ENGINEPATH -B $ENGINEBIN -b $GRAPHVIZBIN -p $NAGVISPATH -W $NAGVISURI -u $HTTPD_USER -g $HTTPD_GROUP -i $NAGVISBACKENDS -w $HTTPD_CONF 
		cd $myscripts
		cp -Rf ./nagvis/* $NAGVISPATH/
		cp GlobalMainCfg.php.patch $NAGVISPATH/share/server/core/classes/
		chown -R $HTTPD_USER:$HTTPD_GROUP $NAGVISPATH
		cd $NAGVISPATH/share/server/core/classes/
		patch -p1 GlobalMainCfg.php < GlobalMainCfg.php.patch > /dev/null
		$HTTPD_INIT restart > /dev/null 2>&1 
	fi
}

remove_module(){
	trap 'trap_handler ${LINENO} $? remove_module' ERR
	cecho "removing existing databases" green
	clean_dbs
	cecho "uninstalling module" green
	uninstall_module
	cecho "removing module" green
	rm -Rf $CENTREON_WWW/modules/$MODULE_NAME
}

remove_nagvis(){
	trap 'trap_handler ${LINENO} $? remove_module' ERR
	rm -Rf $NAGVISPATH
	rm -f $HTTPD_CONF/nagvis.conf
	$HTTPD_INIT restart  > /dev/null 2>&1
}

subst_nagvis(){
	trap 'trap_handler ${LINENO} $? subst_nagvis' ERR
	VARS="MYSQLHOST MYSQLPORT MYSQLUSER MYSQLPASSWD NAGVISDB CENTREONDB NAGVISPATH CENTSTATUSDB INSTANCE CENTREONUSER CENTREONPASSWD CENTSTATUSDB"
	cd $myscripts	
	cp nagvis.ini.php.in nagvis.ini.php
	for v in $VARS
	do
		sed -i "s#@@$v@@#${!v}#g" nagvis.ini.php 
	done
	mv nagvis.ini.php $NAGVISPATH/etc/
}


check_exist_module(){

	Ex=0

	cecho " Checking database $CENTREONDB for centreonnagvis table" yellow
	if [ "$(test_tableexist $CENTREONDB centreonnagvis)" != "0" ]
	then
		cecho "  > Found centreonnagvis table in $CENTREONDB database" red 
		Ex=1
	fi
	 
	cecho " Checking database $NAGVISDB" yellow
	if [ "$(test_dbexist $NAGVISDB)" != "0" ] 
	then
		cecho "  > Found $NAGVISD database" red 
		Ex=1
	fi

	cecho " Checking centreon module $CENTREON_WWW/modules/$MODULE_NAME folder" yellow
	if [ -e "$CENTREON_WWW/modules/$MODULE_NAME" ]
	then
		cecho "  > Found $CENTREON_WWW/modules/$MODULE_NAME folder" red 
		Ex=1
	fi
	

	if [ $Ex -eq 1 ]
	then
		cecho "  Module allready exist. Do you want to remove it ? (yes or no)" red 
		read response
		if [ "$response" == "yes" ]
		then
			remove_module
			remove_nagvis
			clean_dbs
			return
		fi
		if [ "$response" == "no" ]
		then
			cecho "Aborting installation" red
			exit 2
		fi
		check_exist_module
	else
		return 0
	fi
}

function doinstall(){
	cecho "Checking existing installation" green
	check_exist_module
	cecho "Deploy module" green
	deploy_module
	cecho "Deploying databases modifications" green
	do_dbs
	cecho "Install module" green
	install_module
	cecho "Getting nagvis" green
	get_nagvis
	cecho "installing nagvis" green
	deploy_nagvis
	subst_nagvis
	do_sqlfile sql/nagvisdata.sql $NAGVISDB
}

function doupdate(){
	cecho "Not implemented yet" red
}

function douninstall(){
	cecho "  Do you really want to uninstall the module ? (yes or no)" red 
	read response
	if [ "$response" == "yes" ]
	then
		remove_module
		remove_nagvis
		clean_dbs
		return
	fi
	if [ "$response" == "no" ]
	then
		cecho "Aborting" red
		exit 2
	fi
}

function docheck(){
	Ex=0
	cecho " Checking database $CENTREONDB for centreonnagvis table" yellow
	if [ "$(test_tableexist $CENTREONDB centreonnagvis)" != "0" ]
	then
		cecho "  > Found centreonnagvis table in $CENTREONDB database" red 
		Ex=1
	fi
	 
	cecho " Checking for nagvis in $NAGVISPATH" yellow
	if [ -e "$NAGVISPATH" ] 
	then
		cecho "  > Found Nagvis" red 
		Ex=1
	fi

	cecho " Checking database $NAGVISDB" yellow
	if [ "$(test_dbexist $NAGVISDB)" != "0" ] 
	then
		cecho "  > Found $NAGVISD database" red 
		Ex=1
	fi

	cecho " Checking centreon module $CENTREON_WWW/modules/$MODULE_NAME folder" yellow
	if [ -e "$CENTREON_WWW/modules/$MODULE_NAME" ]
	then
		cecho "  > Found $CENTREON_WWW/modules/$MODULE_NAME folder" red 
		Ex=1
	fi
	return $Ex
}


function usage(){
	echo	"setup.sh -i|-d|-c"
	echo	"-i will install centreon module and nagvis"
	echo	"-d will remove centreon module and nagvis"
	echo 	"-c will check for an existing installation"
}

# Check if we launch the script with root privileges (aka sudo)
if [ "$UID" != "0" ]
then
        cecho "You should start the script with sudo!" red
        exit 1
fi

cecho "Parsing arguments" green

while getopts "iudc" opt; do
	case $opt in
		i)
			doinstall
			exit 0
			;;
		u)
			doupdate
			exit 0
			;;
		c)
			docheck
			exit 0
			;;
		d)
			douninstall
			exit 0
			;;
	esac
done
usage
exit 0
