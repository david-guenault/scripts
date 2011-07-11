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
					$CLI -u $CENTU -p $CENTP -o HG -a add -v "$hg;$hg" 
				else
					cecho "HG $hg allready exist" yellow
				fi
			done
			IFS=$OLDIFS
		fi
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
				$CLI -u $CENTU -p $CENTP -o HG -a addchild -v "$hg;$hostname" > /dev/null 2>&1
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
			$CLI -u $CENTU -p $CENTP -o HOST -a setparent -v "$hostname;$parent" 
				
		done
		IFS=$OLDIFS
	done
	IFS=$OLDIFS
	
}

function ORACLE(){
	#createHOSTS
	createORAINSTANCES
}

function createORAINSTANCES(){
	rm -f $datafile.ko
	OLDIFS=$IFS
	IFS=$'\n'
	for l in $(cat $datafile)
	do
		fnum=$(echo $l  | awk -F\; '{print NF}')
		hostname=$(echo $l | awk -F\; '{print $1}')
		fqdn=$(echo $l | awk  -F\; '{print $2}')
		cecho " > Processing $hostname" green
		# determine if a host template is defined inside data file 
		if [ $fnum -eq 7 ]
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
				cecho "   > Host $hostname does not have a host_template" yellow
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
				cecho "   > $fqdn could not be resolved ... may be it is an ip ?" yellow
				ping -c 1 $fqdn > /dev/null 2>&1
				if [ $? -eq 0 ] 
				then
					cecho "   > $fqdn ping OK" yellow
					ip=$fqdn
				else
					cecho "   > $fqdn ping KO" yellow
					ip=0
				fi
			fi
		fi


		if [ "$ip" = "0" ]
		then
			cecho "   > Unable to resolve $fqdn. This host will not be imported" yellow
			echo "$fqdn" >> $datafile.ko
		else
			# now it is time to import data !
			alias=$(echo $l | awk  -F\; '{print $3}')
			hostgroups=$(echo $l | awk  -F\; '{print $4}')
			instances=$(echo $l | awk  -F\; '{print $7}')
			templates=$(echo $l | awk -F\; '{print $6}' | sed -e "s/:/,/g")

			# check if oracle server exist
			exist=$($CLI -u $CENTU -p $CENTP -o HOST -a show -v $hostname | wc -l)
			if [ $exist -eq 0 ]
			then
				cecho " > Oracle server $hostname does not exist " red
			else
				#iterate over instances and create virtual oracle server
				#also set parent to hostname and create a macro INSTORA
				OLDIFS=$IFS
				IFS=$':'
				for orakp in $instances
				do	
					otype=$(echo $orakp | awk -F= '{print $1}')
					oinst=$(echo $orakp | awk -F= '{print $2}')
					# check if virtual host instance exist
					orahost=$otype"_DB_"$oinst
					exist=$($CLI -u $CENTU -p $CENTP -o HOST -a show -v $orahost | grep "^\(.*\);$orahost;" | wc -l)
					if [ $exist -eq 0 ]
					then
						# virtual host instance does not exist so we can create it
						$CLI -u $CENTU -p $CENTP -o HOST -a add -v "$orahost;$orahost;$ip;$templates;$poller" > /dev/null 2>&1
						cecho "   > Created virtual host for oracle instance $orahost :" green
					else
						# virtual host instance exist we do nothing
						cecho "   > Virtual host $orahost  allready exist" yellow
					fi
					# set parent hostname to physical server
					$CLI -u $CENTU -p $CENTP -o HOST -a setparent -v "$orahost;$hostname" #> /dev/null 2>&1
					
					# add macro INSTORA
					$CLI -u $CENTU -p $CENTP -o HOST -a SETMACRO -v "$orahost;INSTORA;$oinst" #> /dev/null 2>&1
				done	

				IFS=$OLDIFS
			fi
			

		fi
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
		if [ $fnum -eq 6 ]
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
						$CLI -u $CENTU -p $CENTP -o HOST -a ADDTEMPLATE -v "$hostname;$t" > /dev/null 2>&1
					else
						# do not exist so create host 
						cecho "Creating host $hostname ($ip) with host template $t" green
						$CLI -u $CENTU -p $CENTP -o HOST -a add -v "$hostname;$alias;$ip;$t;$poller" > /dev/null 2>&1
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

function usage(){
echo "Usage : genconf.sh -d file.data -p poller [-t hosttemplate] [-z action] [-n]
        -d	Datafile
        -p      assign hosts to poller
        -t      assign hosts to hosttemplate
	-z	action to do (PARENT|HOST|HOSTGROUP|HOSTHOSTGROUP|ORACLE)
	-n	Do not try to resolve fqdn when inporting (address is an ip)
	-h	Show usage
	-r	Race condition (show what should be done) NOT IMPLEMENTD AT THE MOMENT

	NOTE : genconf need centreon clapi

	NOTE : datafile format is follow
	    1      2       3         4          5        6          7
	hostname;fqdn;description;hostgroups[;parents;templates;oracleinstances]

	* parents is a : separated list
	* templates is a : separated list
	* oracleinstances is a : separated list
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
while getopts "d:p:tm:z:nh" opt; do
        case $opt in
		h)
			usage
			exit 0	
			;;
		z)
			action=$OPTARG
			;;
                d)
                        datafile=$OPTARG
                        ;;
                p)
                        poller=$OPTARG
                        ;;
                t)
			if [ ! -z "$OPTARG" ]
			then
				ptemplate=$OPTARG
			else
				ptemplate=""
			fi
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


if [ -z "$action" ]
then
	action="ALL"
fi

if [ ! -f "$datafile" ]
then
	cecho "datafile $datafile not found" red
	usage
	exit 2
fi

case $action in
	ALL)
		cadre "Processing hostgroups" blue
		createHGS
		cadre "Processing hosts" blue
		createHOSTS
		cadre "Processing hosts/hostgroups association" blue
		associateHGS
		cadre "Set hosts parents" blue
		setParentHosts
		exit 0
		;;
	PARENT)
		cadre "Set hosts parents" blue
		setParentHosts
		exit 0
		;;
	HOST)
		cadre "Import hosts" blue
		createHOSTS	
		exit 0
		;;
	HOSTGROUP)
		cadre "Processing hostgroups" blue
		createHGS
		exit 0
		;;
	HGHOST)
		cadre "Processing hosts/hostgroups association" blue
		associateHGS
		exit 0
		;;
	ORACLE)
		cadre "Processing oracle instances" blue
		ORACLE
		exit 0
		;;
	*)
		usage
		exit 0
		;;
esac
