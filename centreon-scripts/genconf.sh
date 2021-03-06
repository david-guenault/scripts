#!/bin/bash 

# environnement
myscripts=$(dirname $0)
cd $myscripts
myscripts=$(pwd)

CENTU="admin"
CENTP="kiloutou"
CLI="/usr/local/centreon/www/modules/centreon-clapi/core/centreon"


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


function skeleton(){
        trap 'trap_handler ${LINENO} $? skeleton' ERR
        cecho "Informational data" green
}


function createHGS(){
        trap 'trap_handler ${LINENO} $? createHGS' ERR
        cecho "Creating hostgroups" green
	rm -f ./hostgroups
	
	OLDIFS=$IFS
	IFS=$'\n'
	for hgs in $(cat $datafile | awk -F\; '{print $4}' | sort | uniq)
	do
		#hgs=$(echo $l | awk -F\; '{print $4}' | sort | uniq)
		if [ ! -z $hgs ]
		then
			OLDIFS=$IFS
			IFS=$':'
			for hg in $hgs
			do
				cecho "processing hostgroup $hg" green
				echo $hg >> ./hostgroups 
				if [ -z $($CLI -u $CENTU -p $CENTP -o HG -a show | grep -q $hg) ]
				then 
					cecho "Creating hostgroup $hg" green
					$CLI -u $CENTU -p $CENTP -o HG -a add -v "$hg;$g" >> /tmp/clapi.log 2>&1 
				else
					cecho "HG $hg allready exist" yellow
				fi
			done
			IFS=$OLDIFS
		fi
	done
	IFS=$OLDIFS
}


function MACROS(){
        cecho "Creating hosts macros" green
	OLDIFS=$IFS
	IFS=$'\n'
	for l in $(cat $datafile)
	do
		hostname=$(echo $l | awk -F\; '{print $1}')
		macros=$(echo $l | awk -F\; '{print $9}')
		OLDIFS2=$IFS
		IFS=$':'
		cadre "processing host $hostname for macros creation" green 
		for macro in $macros
		do
			key=$(echo $macro | awk -F= '{print $1}')
			value=$(echo $macro | awk -F= '{print $2}')
			cecho "processing macro $key with value $value" green 
			$CLI -u $CENTU -p $CENTP -o HOST -a SETMACRO -v "$hostname;$key;$value"  >> /tmp/clapi.log 2>&1
		done
		IFS=$OLDIFS2
	done
	IFS=$OLDIFS

}

function associateHGS(){
        #trap 'trap_handler ${LINENO} $? associateHGS' ERR
        cecho "Associating hosts with hostgroups" green
	OLDIFS=$IFS
	IFS=$'\n'
	for l in $(cat $datafile)
	do
		hostname=$(echo $l | awk -F\; '{print $1}')
		hgs=$(echo $l | awk -F\; '{print $4}')
		OLDIFS=$IFS
		IFS=$':'
		cadre "processing host $hostname for hostgroups association" green 
		for hg in $hgs
		do
			cecho "processing hostgroup $hg" green
			if [ -z $($CLI -u $CENTU -p $CENTP -o HG -a show | grep -q $hg | grep -q $hostname) ]
			then 
				cecho "Associating hostgroup $hg with host $hostname" green
				$CLI -u $CENTU -p $CENTP -o HG -a addchild -v "$hg;$hostname"  >> /tmp/clapi.log 2>&1
			else
				cecho "HG $hg is allready associated with host $hostname " yellow
			fi
		done
		IFS=$OLDIFS
	done
	IFS=$OLDIFS
}

function setParentHosts(){
	rm -f $datafile.parents.ko
	OLDIFS=$IFS
	IFS=$'\n'
	for l in $(cat $datafile)
	do
		hostname=$(echo $l | awk -F\; '{print $1}')
		parents=$(echo $l | awk  -F\; '{print $5}')
		if [ -z "$parents" ]
		then
			cecho "No parents defined for $hostname" yellow
		else
			cadre "$hostname : $parents" magenta 
		fi

		OLDIFS=$IFS
		IFS=$':'
		for parent in $parents
		do
			cecho "Associating $parent to $hostname" green
			$CLI -u $CENTU -p $CENTP -o HOST -a setparent -v "$hostname;$parent"  >> /tmp/clapi.log 2>&1
				
		done
		IFS=$OLDIFS
	done
	IFS=$OLDIFS
	
}


function createHOSTS(){
	rm -f $datafile.ko
	OLDIFS=$IFS
	IFS=$'\n'
	for l in $(cat $datafile)
	do
		fnum=$(echo $l  | awk -F\; '{print NF}')
		hostname=$(echo $l | awk -F\; '{print $1}')
		fqdn=$(echo $l | awk  -F\; '{print $2}')
		# determine if a host template is defined inside data file 
		if [ $fnum -gt 5 ]
		then
			ftemplate=$(echo $l | awk -F\; '{print $6}')
		else
			ftemplate=""
		fi
		
		# if template is specified in data file it override the one specified on commmand line
		if [ -z $ptemplate ]
		then
			if [ -z "$ftemplate" ]
			then
				cecho "Host $hostname does not have a host_template" yellow
			else
				template=$ftemplate	
			fi
		else
			template=$ptemplate
		fi


		# do not try to resolve hostname if -n is specified
		if [ $noresolve -eq 1 ]
		then
			ip=$fqdn
		else	
			ip=$(resolveip -s $fqdn)
			if [ $? -ne 0 ]
			then
				cecho "$fqdn could not be resolved ... may be it is an ip ?" yellow
				ping -c 1 $fqdn > /dev/null 2>&1
				if [ $? -eq 0 ] 
				then
					cecho "$fqdn ping OK" yellow
					ip=$fqdn
				else
					cecho "$fqdn ping KO" yellow
					ip=0
				fi
			fi
		fi


		if [ "$ip" = "0" ]
		then
			cecho " > Unable to resolve $fqdn. This host will not be imported" yellow
			echo "$fqdn" >> $datafile.ko
		else
			# now it is time to import data !
			hgs=$(echo $l | awk -F\; '{print $4}')
			alias=$(echo $l | awk  -F\; '{print $3}')
			hostgroups=$(echo $l | awk  -F\; '{print $4}')
			#count=$($CLI -u $CENTU -p $CENTP -o HOST -a show -v $hostname | wc -l)
			#if [ $count -ne 2 ]
			#then 
				# first create host with firsttemplate then bind other templates to host
				OLDIFS=$IFS
				IFS=$':'
				for t in $template
				do
					# check if host exist
					exist=$($CLI -u $CENTU -p $CENTP -o HOST -a show -v $hostname | wc -l)
					if [ $exist -ne 0 ] 
					then
						# exist so just bind template
						cecho "Associate $hostname with host_template $t" green
						$CLI -u $CENTU -p $CENTP -o HOST -a ADDTEMPLATE -v "$hostname;$t"  >> /tmp/clapi.log 2>&1
					else
						# do not exist so create host 
						cecho "Creating host $hostname ($ip) with host template $t" green
						$CLI -u $CENTU -p $CENTP -o HOST -a add -v "$hostname;$alias;$ip;$t;$poller" >> /tmp/clapi.log 2>&1
					fi
				done
				IFS=$OLDIFS
			#else
			#	cecho "Associate $hostname with host_template $template" green
			#	$CLI -u $CENTU -p $CENTP -o HOST -a ADDTEMPLATE -v "$hostname;$template" > /dev/null 2>&1
			#
			#fi
		fi
	done
	IFS=$OLDIFS
}

function COMMANDS(){
	OLDIFS=$IFS
	IFS=$'\n'
	for l in $(cat $datafile)
	do
		name=$(echo $l | awk -F\; '{print $1}')i
		type=$(echo $l | awk -F\; '{print $2}')i
		command=$(echo $l | awk -F\; '{print $3}')i
		# check if command exist
		exist=$($CLI -u $CENTU -p $CENTP -o CMD -a show | grep "^$name" | wc -l)
		if [ $exist -eq 0 ] 
		then
			cecho "Adding command $name" green
			$CLI -u $CENTU -p $CENTP -o CMD -a ADD -v "$name;$command;$type" >> /tmp/clapi.log 2>&1
			if [ $? -ne 0 ]
			then
				cecho "There was a problem inserting command $name" red
			fi
		else
			cecho "command $name allready exist" yellow 
		fi
	done
	IFS=$OLDIFS
}

function deleteHOSTS(){
	OLDIFS=$IFS
	IFS=$'\n'
	for l in $(cat $datafile)
	do
		hostname=$(echo $l | awk -F\; '{print $1}')
		# check if host exist
		exist=$($CLI -u $CENTU -p $CENTP -o HOST -a show -v "$hostname" | wc -l)
		if [ $exist -ne 0 ] 
		then
			cecho "Removing $hostname" green
			$CLI -u $CENTU -p $CENTP -o HOST -a DEL -v "$hostname" >> /tmp/clapi.log 2>&1
		else
			cecho "$hostname does not exist" yellow 
		fi
	done
	IFS=$OLDIFS
}

function deleteHOSTSVC(){
	OLDIFS=$IFS
	IFS=$'\n'
	for l in $(cat $datafile)
	do
		hostname=$(echo $l | awk -F\; '{print $1}')
		services=$(echo $l | awk -F\; '{print $8}')
		OLDIFS=$IFS
		IFS=$':'
		cecho "------------------------------------------------------------" green
		for srv in $services
		do

			cecho "Removing $srv from $hostname" green
			$CLI -u $CENTU -p $CENTP -o SERVICE -a DEL -v "$hostname;$srv" >> /tmp/clapi.log 2>&1
		done
		IFS=$OLDIFS
	done
	IFS=$OLDIFS
}

function applyTPL(){
	OLDIFS=$IFS
	IFS=$'\n'
	for l in $(cat $datafile)
	do
		hostname=$(echo $l | awk -F\; '{print $1}')
		# check if host exist
		exist=$($CLI -u $CENTU -p $CENTP -o HOST -a show -v "$hostname" | wc -l)

		if [ $exist -ne 0 ] 
		then
			cecho "applying host templates modifications on $hostname" green
			$CLI -u $CENTU -p $CENTP -o HOST -a applytpl -v "$hostname"  >> /tmp/clapi.log 2>&1
		else
			cecho "$hostname does not exist" yellow 
		fi
	done
	IFS=$OLDIFS
}

function usage(){
echo "Usage : genconf.sh -d file.data -p poller [-z actions ] [-n]
        -d	Datafile
        -p      assign hosts to poller
	-z	action(s) to do (PARENT|HOST|HOSTGROUP|HGHOST|DELHOST|DELHOSTSVC|HOSTTPL|MACROS)
		if more than one action is specified, it should be separated by a coma
		* PARENT : create parent association between field 1 and field 5
		* HOST : create hosts
		* HOSTGROUP : create hostgroups from field 4 
		* MACROS : Create host macros specified in field 9
		* HGHOSTS : link host with hostgroups from field 4
		* DELHOST : delete hosts defined in field 1
		* DELHOSTSVC : delete services definied in field 8 for host defined in field 1
		* HOSTTPL : apply host templates defined in field 6 so it can generate services from host template

		* COMMANDS : import commands (caution this is a special import so the format of the data file is a little bit different.
		             in this case poller (-p) is not needed
				1	2	       3
			command_name;command_type;command_line
			command_type should be check, notif or misc

	-n	Do not try to resolve fqdn when inporting (address is an ip)
	-h	Show usage

	NOTE : genconf need centreon clapi

	NOTE : datafile format is follow
	    1      2       3         4          5        6          7		   8       9
	hostname;fqdn;description;hostgroups[;parents;templates;oracleinstances;services;macros]

	HOST require at least 1,2,3,4 if -t is omited 6 is required
	PARENT require at least 1,5 and -p 
	MACROS require at least 1 and 9
	* parents is a : separated list
	* templates is a : separated list
	* oracleinstances is a : separated list
	* services is a : separated list
	* macros is a : separated list
"

}

function cadre(){
cecho "+-----------------------------------------------------------------+" $2 
cecho "| $1" $2 
cecho "+-----------------------------------------------------------------+" $2
}


# Check if we launch the script with root privileges (aka sudo)
if [ "$UID" != "0" ]
then
        cecho "You should start the script with sudo!" red
        exit 1
fi

#trap 'trap_handler ${LINENO} $?' ERR
#cecho "Parsing arguments" green
export noresolve=0
while getopts "d:p:z:nh" opt; do
        case $opt in
		h)
			usage
			exit 0	
			;;
		z)
			actions=$OPTARG
			;;
                d)
                        datafile=$OPTARG
                        ;;
                p)
                        poller=$OPTARG
                        ;;
                n)
			export noresolve=1
                        ;;
		*)
			usage
			exit 0
			;;
        esac
done


if [ ! -f "$datafile" ]
then
	cecho "datafile $datafile not found" red
	usage
	exit 2
fi

if [ -z "$actions" ]
then
	cecho " > You need to specify at least one action " red
	usage
	exit 2
fi

echo "" > /tmp/clapi.log
lactions=$(echo $actions | sed -e "s/,/ /g")
for action in $lactions
do
	case $action in
		PARENT)
			cadre "Set hosts parents" blue
			setParentHosts
			;;
		HOST)
			cadre "Import hosts" blue
			createHOSTS	
			;;
		DELHOST)
			cadre "Delete hosts" blue
			deleteHOSTS	
			;;
		DELHOSTSVC)
			cadre "Delete services for hosts" blue
			deleteHOSTSVC
			;;

		HOSTGROUP)
			cadre "Processing hostgroups" blue
			createHGS
			;;
		HOSTTPL)
			cadre "Applying host template" blue
			applyTPL
			;;
		HGHOST)
			cadre "Processing hosts/hostgroups association" blue
			associateHGS
			;;
		COMMANDS)
			cadre "Importing commands" blue
			COMMANDS	
			;;
		MACROS)
			cadre "Processing host macros" blue
			MACROS
			;;
		*)
			usage
			exit 0
			;;
	esac
done
