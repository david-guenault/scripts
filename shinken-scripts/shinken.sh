#!/bin/bash 

# environnement
myscripts=$(dirname $0)
cd $myscripts
myscripts=$(pwd)
. ./shinken.conf

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

function check_distro(){
	trap 'trap_handler ${LINENO} $? check_distro' ERR
	cecho "Verifying compatible distros" green

	if [ ! -e /usr/bin/lsb_release ]
	then	
		echo "No compatible distribution found"
		exit 2
	fi

	export CODE=""

	DIST=$(/usr/bin/lsb_release -i | awk '{print $NF}')
	VERS=$(/usr/bin/lsb_release -r | awk '{print $NF}' | awk -F. '{print $1}')


	for s in $DISTROS
	do
		# try distribution and release
		if [ "$DIST$VERS"="$s" ]
		then
			export CODE=$DIST
			cecho " Found : $DIST $VERS" yellow
			return 
		else
			# try on distribution only
			if [ "$DIST"="$s" ]
			then
				export CODE=$DIST
				cecho " Found $DIST" yellow
				return
			fi
		fi
	done

	cecho "No compatible distribution found" red
	exit 2
}

function remove(){
	trap 'trap_handler ${LINENO} $? remove' ERR
	cecho "Removing shinken" green
	skill
	
	if [ -d "$TARGET" ]
	then 
		rm -Rf $TARGET 
	fi
	if [ -h "/etc/default/shinken" ]
	then 
		rm -Rf /etc/default/shinken 
	fi
	if [ -f "/etc/init.d/shinken" ]
        then
                case $CODE in
                        CentOS)
				cecho "Removing startup script" green
                                chkconfig shinken off
                                chkconfig --del shinken
                                ;;
                        RedHatEnterpriseServer)
				cecho "Removing startup script" green
                                chkconfig shinken off
                                chkconfig --del shinken
                                ;;
                        Debian)
				cecho "Removing startup script" green
                                update-rc.d -f shinken remove > /dev/null 2>&1
                                ;;
                        Ubuntu)
				cecho "Removing startup script" green
                                update-rc.d -f shinken remove > /dev/null 2>&1
                                ;;
                esac    
        fi
	rm -f /etc/init.d/shinken*

	return 0
}

function skill(){
	cecho "Try to stop shinken the right way" green
	/etc/init.d/shinken stop > /dev/null 2>&1
	cecho "Killing shinken" green
	pc=$(ps -aef | grep "$TARGET" | grep -v "grep" | wc -l )
	if [ $pc -ne 0 ]
	then	
		OLDIFS=$IFS
		IFS=$'\n'
		
		for p in $(ps -aef | grep -q "$TARGET" | grep -vq "grep" | awk '{print $2}')
		do
			kill -9 $p
		done

		IFS=$OLDIFS
	fi
	rm -Rf /tmp/bad_start*
	rm -Rf $TARGET/var/*.pid
	return 0
}

function get_from_git(){
	trap 'trap_handler ${LINENO} $? get_from_git' ERR
	cecho "Getting shinken" green
	cd $TMP
	if [ -e "shinken" ]
	then
		rm -Rf shinken
	fi
	env GIT_SSL_NO_VERIFY=true git clone $GIT > /dev/null 2>&1
	cd shinken
	cecho "Switching to version $VERSION" green
	git checkout $VERSION > /dev/null 2>&1
	# clean up .git folder
	rm -Rf .git
}

function setdirectives(){
	trap 'trap_handler ${LINENO} $? setdirectives' ERR
	directives=$1
	fic=$2
	mpath=$3
	
	cecho ">>>>going to $mpath" green
	cd $mpath

	for pair in $directives
	do
		directive=$(echo $pair | awk -F= '{print $1}')
		value=$(echo $pair | awk -F= '{print $2}')
		cecho ">>>>setting $directive to $value in $fic" green
		sed -i 's#^\# \?'$directive'=\(.*\)$#'$directive'='$value'#g' $mpath/etc/$(basename $fic)
	done
}

function relocate(){
	trap 'trap_handler ${LINENO} $? relocate' ERR
	cecho "Relocate source tree to $TARGET" green
	# relocate source tree
	for fic in $(find . | xargs grep -snH "/usr/local/shinken" --color | cut -f1 -d' ' | awk -F : '{print $1}' | sort | uniq)
	do 
		cecho ">>Processing $fic" green
		cp $fic $fic.orig 
		sed -i 's#/usr/local/shinken#'$TARGET'#g' $fic 
	done
	# set some directives 
	directives="workdir=$TARGET/var user=$SKUSER group=$SKGROUP"
	for fic in ./etc/*.ini; 
	do 
		cecho ">>Processing $fic" green;
		setdirectives "$directives" $fic $TMP/shinken
		cp -f $fic $TARGET/etc/; 
	done
	# relocate default file
	cd $TARGET/bin/default
	cat $TARGET/bin/default/shinken.in | sed -e  's#ETC\=\(.*\)$#ETC='$TARGET'/etc#g' -e  's#VAR\=\(.*\)$#VAR='$TARGET'/var#g' -e  's#BIN\=\(.*\)$#BIN='$TARGET'/bin#g' > $TARGET/bin/default/shinken
	# relocate init file
	cd $TARGET/bin/init.d
	mv shinken shinken.in
	cat shinken.in | sed -e "s#\#export PYTHONPATH=#export PYTHONPATH=#g" > $TARGET/bin/init.d/shinken
}

function fix(){
	trap 'trap_handler ${LINENO} $? fix' ERR
	cecho "Applying various fixes" green
	chmod +x /etc/init.d/shinken
	chmod +x /etc/default/shinken
	chmod +x $TARGET/bin/init.d/shinken
	chown -R $SKUSER:$SKGROUP $TARGET
}

function enable(){
	trap 'trap_handler ${LINENO} $? enable' ERR
	cecho "Enabling startup scripts" green
	cp $TARGET/bin/init.d/shinken* /etc/init.d/
	case $DISTRO in
		Centos)
			cecho "Enabling centos startup script" green
			chkconfig shinken on
			chkconfig --add shinken
			;;
		Debian)
			cecho "Enabling debian startup script" green
			update-rc.d shinken defaults > /dev/null 2>&1
			;;
		Ubuntu)
			cecho "Enabling ubuntu startup script" green
			update-rc.d shinken defaults > /dev/null 2>&1
			;;
	esac    
}

function sinstall(){
	trap 'trap_handler ${LINENO} $? install' ERR
	cecho "Installing shinken" green
	check_distro
	check_exist
	prerequisites
	create_user
	get_from_git
	cp -Rf $TMP/shinken $TARGET
	relocate
	ln -s $TARGET/bin/default/shinken /etc/default/shinken
	cp $TARGET/bin/init.d/shinken* /etc/init.d/
	fix
}
function backup(){
	trap 'trap_handler ${LINENO} $? backup' ERR
	cecho "Backup shinken configuration, plugins and data" green
	skill
	if [ ! -e $BACKUPDIR ]
	then
		mkdir $BACKUPDIR
	fi
	mkdir -p $BACKUPDIR/bck-shinken.$DATE
	cp -Rfp $TARGET/etc $BACKUPDIR/bck-shinken.$DATE/
	cp -Rfp $TARGET/libexec $BACKUPDIR/bck-shinken.$DATE/
	cp -Rfp $TARGET/var $BACKUPDIR/bck-shinken.$DATE/
}

function backuplist(){
	trap 'trap_handler ${LINENO} $? backuplist' ERR
	cecho "List of available backups in $BACKUPDIR" green
	for d in $(ls -1 $BACKUPDIR | grep "bck-shinken" | awk -F. '{print $2}')
	do
		echo " > $d"
	done

}

function restore(){
	trap 'trap_handler ${LINENO} $? restore' ERR
	cecho "Restore shinken configuration, plugins and data" green
	skill
	if [ ! -e $BACKUPDIR ]
	then
		cecho "Backup folder not found" red
		exit 2
	fi
	if [ -z $1 ]
	then
		cecho "No backup timestamp specified" red
		backuplist
		exit 2
	fi
	if [ ! -e $BACKUPDIR/bck-shinken.$1 ]
	then
		cecho "Backup not found : $BACKUPDIR/bck-shinken.$1 " red
		backuplist
		exit 2
	fi
	rm -Rf $TARGET/etc
	rm -Rf $TARGET/libexec 
	rm -Rf $TARGET/var 
	cp -Rfp $BACKUPDIR/bck-shinken.$1/* $TARGET/
}

function supdate(){
	trap 'trap_handler ${LINENO} $? update' ERR
	cecho "Updating shinken" green
	skill
	backup
	remove
	sinstall
	restore $DATE
}

function create_user(){
	trap 'trap_handler ${LINENO} $? create_user' ERR
	cecho "Creating user" green
	if [ ! -z "$(cat /etc/passwd | grep $SKUSER)" ] 
	then
		cecho ">>User $SKUSER allready exist" yellow 
	else
	    	useradd -s /bin/bash $SKUSER 
	fi
    	usermod -G $SKGROUP $SKUSER 
}

function check_exist(){
	trap 'trap_handler ${LINENO} $? check_exist' ERR
	cecho "Checking for existing installation" green
	if [ -d "$TARGET" ]
	then
		cecho ">>Target folder allready exist" red
		exit 2
	fi
	if [ -e "/etc/init.d/shinken" ]
	then
		cecho ">>Init scripts allready exist" red
		exit 2
	fi
	if [ -L "/etc/default/shinken" ]
	then
		cecho ">>shinken default allready exist" red
		exit 2
	fi

}

function prerequisites(){
	trap 'trap_handler ${LINENO} $? prerequisite' ERR
	cecho "Checking prerequisite" green
	prereq="python pyro-nsc wget git"
	for p in $prereq
	do
		if [ -z "$(which $p)" ]
		then
			cecho ">>prerequisite $p not found !" red
			cecho ">>prerequisites are : $prereq" red
			exit 2	
		fi
	done
}

function compresslogs(){
	trap 'trap_handler ${LINENO} $? compresslogs' ERR
	cecho "Compress rotated logs" green
	if [ ! -d $TARGET/var/archives ]
	then
		cecho ">>Archives directory not found" yellow
		exit 0
	fi
	cd $TARGET/var/archives
	for l in $(ls -1 ./*.log)
	do
		file=$(basename $l)
		if [ -e $file ]
		then
			cecho ">> Processing $file" green
			tar czf $file.tar.gz $file
			rm -f $file
		fi
	done
}

function shelp(){
	cat $myscripts/README
}

function usage(){
echo "Usage : shinken -k | -i | -d | -u | -b | -r | -l | -c | -h 
	-k	Kill shinken
	-i	Install shinken
	-d 	Remove shinken
	-u	Update an existing shinken installation
	-b	Backup shinken configuration plugins and data
	-r 	Restore shinken configuration plugins and data
	-l	List shinken backups
	-c	Compress rotated logs
	-h	Show help
"

}


# Check if we launch the script with root privileges (aka sudo)
if [ "$UID" != "0" ]
then
        cecho "You should start the script with sudo!" red
        exit 1
fi

while getopts "kidubcr:lzh" opt; do
        case $opt in
		z)
			check_distro
			exit 0
			;;
                k)
                        skill
                        exit 0
                        ;;
                i)
                       	sinstall 
                        exit 0
                        ;;
                d)
                       	remove 
                        exit 0
                        ;;
                u)
                       	supdate 
                        exit 0
                        ;;
                b)
                       	backup 
                        exit 0
                        ;;
                r)
                       	restore $OPTARG 
                        exit 0
                        ;;
                l)
                       	backuplist 
                        exit 0
                        ;;
		c)
			compresslogs
			exit 0
			;;
		h)
			shelp	
			exit 0
			;;
        esac
done
usage
exit 0

