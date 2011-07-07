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

function cadre(){
	cecho "+--------------------------------------------------------------------------------" $2
	cecho "| $1" $2
	cecho "+--------------------------------------------------------------------------------" $2
}

function mcadre(){

	if [ "$1" = "mcline" ]
	then
		cecho "+--------------------------------------------------------------------------------" $2
		return
	fi

	OLDIFS=$IFS
	IFS=$'\n'
	for l in $1
	do
		cecho "| $l" $2
	done
	IFS=OLDIFS
}

function check_distro(){
	trap 'trap_handler ${LINENO} $? check_distro' ERR
	cadre "Verifying compatible distros" green

	if [ ! -e /usr/bin/lsb_release ]
	then	
		cecho " > No compatible distribution found" red
		exit 2
	fi

	if [ -z $CODE ]
	then
		cecho " > No compatible distribution found" red
		exit 2
	else
		cecho " > Found $DIST $VERS" yellow 
	fi
}

function remove(){
	trap 'trap_handler ${LINENO} $? remove' ERR
	cadre "Removing shinken" green
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
                        REDHAT)
				cecho " > Removing startup script" green
                                chkconfig shinken off
                                chkconfig --del shinken
                                ;;
                        DEBIAN)
				cecho " > Removing startup script" green
                                update-rc.d -f shinken remove > /dev/null 2>&1
                                ;;
                esac    
        fi
	rm -f /etc/init.d/shinken*

	return 0
}

function skill(){
	#cecho "Try to stop shinken the right way" green
	/etc/init.d/shinken stop > /dev/null 2>&1
	#cecho "Killing shinken" green
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
	cadre "Getting shinken" green
	cd $TMP
	if [ -e "shinken" ]
	then
		rm -Rf shinken
	fi
	env GIT_SSL_NO_VERIFY=true git clone $GIT > /dev/null 2>&1
	cd shinken
	cecho " > Switching to version $VERSION" green
	git checkout $VERSION > /dev/null 2>&1
	# clean up .git folder
	rm -Rf .git
}

function setdirectives(){
	trap 'trap_handler ${LINENO} $? setdirectives' ERR
	directives=$1
	fic=$2
	mpath=$3
	
	#cecho ">>>>going to $mpath" green
	cd $mpath

	for pair in $directives
	do
		directive=$(echo $pair | awk -F= '{print $1}')
		value=$(echo $pair | awk -F= '{print $2}')
		#cecho ">>>>setting $directive to $value in $fic" green
		sed -i 's#^\# \?'$directive'=\(.*\)$#'$directive'='$value'#g' $mpath/etc/$(basename $fic)
	done
}

function relocate(){
	trap 'trap_handler ${LINENO} $? relocate' ERR
	cadre "Relocate source tree to $TARGET" green
	# relocate source tree
	for fic in $(find . | xargs grep -snH "/usr/local/shinken" --color | cut -f1 -d' ' | awk -F : '{print $1}' | sort | uniq)
	do 
		cecho " > Processing $fic" green
		cp $fic $fic.orig 
		sed -i 's#/usr/local/shinken#'$TARGET'#g' $fic 
	done
	# set some directives 
	directives="workdir=$TARGET/var user=$SKUSER group=$SKGROUP"
	for fic in ./etc/*.ini; 
	do 
		cecho " > Processing $fic" green;
		setdirectives "$directives" $fic $TMP/shinken
		cp -f $fic $TARGET/etc/; 
	done
	# relocate default file
	cd $TARGET/bin/default
	cat $TARGET/bin/default/shinken.in | sed -e  's#ETC\=\(.*\)$#ETC='$TARGET'/etc#g' -e  's#VAR\=\(.*\)$#VAR='$TARGET'/var#g' -e  's#BIN\=\(.*\)$#BIN='$TARGET'/bin#g' > $TARGET/bin/default/shinken
	# relocate init file
	cd $TARGET/bin/init.d
	mv shinken shinken.in
	cat shinken.in | sed -e "s#\#export PYTHONPATH=.*#export PYTHONPATH="$TARGET"#g" > $TARGET/bin/init.d/shinken
}

function fix(){
	trap 'trap_handler ${LINENO} $? fix' ERR
	cadre "Applying various fixes" green
	chmod +x /etc/init.d/shinken
	chmod +x /etc/default/shinken
	chmod +x $TARGET/bin/init.d/shinken
	chown -R $SKUSER:$SKGROUP $TARGET
}

function enable(){
	trap 'trap_handler ${LINENO} $? enable' ERR
	cadre "Enabling startup scripts" green
	cp $TARGET/bin/init.d/shinken* /etc/init.d/
	case $DISTRO in
		REDHAT)
			cecho " > Enabling $DIST startup script" green
			chkconfig --add shinken
			chkconfig shinken on
			;;
		DEBIAN)
			cecho " > Enabling $DIST startup script" green
			update-rc.d shinken defaults > /dev/null 2>&1
			;;
	esac    
}

function sinstall(){
	trap 'trap_handler ${LINENO} $? install' ERR
	#cecho "Installing shinken" green
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

function rheldvd(){
	# this is only for my personal needs
	# dvd mounted ?
	if [ "$CODE" != "REDHAT" ]
	then
		cecho " > Only for REDHAT" red
		exit 2
	fi
	cadre "Setup rhel dvd for yum (this is only for my development purpose)" green
	dvdm=$(cat /proc/mounts | grep "^\/dev\/cdrom")
	if [ -z "$dvdm" ]
	then
		if [ ! -d "/media/cdrom" ]
		then
			mkdir -p "/media/cdrom"
		fi
		cecho " > Insert RHEL/CENTOS DVD and press ENTER" yellow
		read enter
		mount -t iso9660 -o ro /dev/cdrom /media/cdrom > /dev/null 2>&1
		if [ $? -eq 0 ]
		then
			dvdm=$(cat /proc/mounts | grep "^\/dev\/cdrom")
			if [ -z "$dvdm" ]
			then
				cecho " > Unable to mount RHEL/CENTOS DVD !" red
				exit 2
			else
				if [ ! -d "/media/cdrom/Server" ]
				then
					cecho "Invalid DVD" red
					exit 2
				else
					if [ ! -f "/etc/yum.repos.d/rheldvd.repo" ]
					then
						echo "[dvd]" > /etc/yum.repos.d/rheldvd.repo
						echo "name=rhel dvd" >> /etc/yum.repos.d/rheldvd.repo
						echo "baseurl=file:///media/cdrom/Server" >> /etc/yum.repos.d/rheldvd.repo
						echo "enabled=1" >> /etc/yum.repos.d/rheldvd.repo
						echo "gpgcheck=0" >> /etc/yum.repos.d/rheldvd.repo
					fi
				fi
			fi
		else 
			cecho " > Error while mounting DVD" red
		fi	
	fi	
}

function backup(){
	trap 'trap_handler ${LINENO} $? backup' ERR
	cadre "Backup shinken configuration, plugins and data" green
	skill
	if [ ! -e $BACKUPDIR ]
	then
		mkdir $BACKUPDIR
	fi
	mkdir -p $BACKUPDIR/bck-shinken.$DATE
	cp -Rfp $TARGET/etc $BACKUPDIR/bck-shinken.$DATE/
	cp -Rfp $TARGET/libexec $BACKUPDIR/bck-shinken.$DATE/
	cp -Rfp $TARGET/var $BACKUPDIR/bck-shinken.$DATE/
	cecho " > Backup done. Id is $DATE"
}

function backuplist(){
	trap 'trap_handler ${LINENO} $? backuplist' ERR
	cadre "List of available backups in $BACKUPDIR" green
	for d in $(ls -1 $BACKUPDIR | grep "bck-shinken" | awk -F. '{print $2}')
	do
		cecho " > $d" green
	done

}

function restore(){
	trap 'trap_handler ${LINENO} $? restore' ERR
	cadre "Restore shinken configuration, plugins and data" green
	skill
	if [ ! -e $BACKUPDIR ]
	then
		cecho " > Backup folder not found" red
		exit 2
	fi
	if [ -z $1 ]
	then
		cecho " > No backup timestamp specified" red
		backuplist
		exit 2
	fi
	if [ ! -e $BACKUPDIR/bck-shinken.$1 ]
	then
		cecho " > Backup not found : $BACKUPDIR/bck-shinken.$1 " red
		backuplist
		exit 2
	fi
	rm -Rf $TARGET/etc
	rm -Rf $TARGET/libexec 
	rm -Rf $TARGET/var 
	cp -Rfp $BACKUPDIR/bck-shinken.$1/* $TARGET/
	cecho " > Restauration done" green
}

function supdate(){
	trap 'trap_handler ${LINENO} $? update' ERR
	cadre "Updating shinken" green
	skill
	backup
	remove
	sinstall
	restore $DATE
}

function create_user(){
	trap 'trap_handler ${LINENO} $? create_user' ERR
	cadre "Creating user" green
	if [ ! -z "$(cat /etc/passwd | grep $SKUSER)" ] 
	then
		cecho " > User $SKUSER allready exist" yellow 
	else
	    	useradd -s /bin/bash $SKUSER 
	fi
    	usermod -G $SKGROUP $SKUSER 
}

function check_exist(){
	trap 'trap_handler ${LINENO} $? check_exist' ERR
	cadre "Checking for existing installation" green
	if [ -d "$TARGET" ]
	then
		cecho " > Target folder allready exist" red
		exit 2
	fi
	if [ -e "/etc/init.d/shinken" ]
	then
		cecho " > Init scripts allready exist" red
		exit 2
	fi
	if [ -L "/etc/default/shinken" ]
	then
		cecho " > shinken default allready exist" red
		exit 2
	fi

}

function installpkg(){
	type=$1
	package=$2

	if [ "$type" == "python" ]
	then
		easy_install $package > /dev/null 2>&1
		return $?
	fi

	case $CODE in 
		REDHAT)
			yum install -yq $package > /dev/null 2>&1
			if [ $? -ne 0 ]
			then
				return 2
			fi
			;;
		DEBIAN)
			apt-get install -y $package > /dev/null 2>&1
			if [ $? -ne 0 ]
			then
				return 2
			fi
			;;
	esac	
	return 0
}

function prerequisites(){
	cadre "Checking prerequisite" green
	# common prereq
	bins="wget sed awk grep python bash"

	for b in $bins
	do
		rb=$(which $b > /dev/null 2>&1)
		if [ $? -eq 0 ]
		then
			cecho " > Checking for $b : OK" green 
		else
			cecho " > Checking for $b : NOT FOUND" red
			exit 2 
		fi	
	done

	# distro prereq
	case $CODE in
		REDHAT)
			PACKAGES=$YUMPKGS
			QUERY="rpm -q "
			cd $TMP
			$QUERY $RPMFORGENAME > /dev/null 2>&1
			if [ $? -ne 0 ]
			then
				cecho " > Installing $RPMFORGEPKG" yellow
				wget $RPMFORGE > /dev/null 2>&1 
				if [ $? -ne 0 ]
				then
					cecho " > Error while trying to download rpm forge repositories" red 
					exit 2
				fi
				rpm -Uvh ./$RPMFORGEPKG > /dev/null 2>&1
			else
				cecho " > $RPMFORGEPKG allready installed" green 
			fi
			;;
		DEBIAN)
			PACKAGES=$APTPKGS
			QUERY="dpkg -l "
			;;
	esac
	for p in $PACKAGES
	do
		$QUERY $p > /dev/null 2>&1
		if [ $? -ne 0 ]
		then
			cecho " > Installing $p " yellow
			installpkg pkg $p 
			if [ $? -ne 0 ]
			then 
				cecho " > Error while trying to install $p" red 
				exit 2 	
			fi
		else
			cecho " > Package $p allready installed " green 
		fi
	done
	# python prereq
	if [ "$CODE" = "REDHAT" ]
	then
		for p in $PYLIBSRHEL
		do
			module=$(echo $p | awk -F: '{print $1'})
			import=$(echo $p | awk -F: '{print $2'})

			$myscripts/tools/checkmodule.py -m $import > /dev/null 2>&1
			if [ $? -eq 2 ]
			then
				cecho " > Module $module ($import) not found. Installing..." yellow
				easy_install $module > /dev/null 2>&1
			else
				cecho " > Module $module found." green 
			fi

			
		done	
		module="pyro"
		import="Pyro.core"

		$myscripts/checkmodule.py -m $import > /dev/null 2>&1
		
		if [ $? -eq 2 ]
		then
			cecho " > Module $module ($import) not found. Installing..." yellow
			cd $TMP
			easy_install $PYRO > /dev/null 2>&1
		else
			cecho " > Module $module found." green 
		fi
	fi
	
}

function compresslogs(){
	trap 'trap_handler ${LINENO} $? compresslogs' ERR
	cadre "Compress rotated logs" green
	if [ ! -d $TARGET/var/archives ]
	then
		cecho " > Archives directory not found" yellow
		exit 0
	fi
	cd $TARGET/var/archives
	for l in $(ls -1 ./*.log)
	do
		file=$(basename $l)
		if [ -e $file ]
		then
			cecho " > Processing $file" green
			tar czf $file.tar.gz $file
			rm -f $file
		fi
	done
}

function shelp(){
	cat $myscripts/README
}

function install_thruk(){
	cd $TMP
	
	cecho "What do you want to do ? " green
	cecho "[i]nstall or [r]emove"
	read action

	case $(uname -i) in
		x86_64)
			suffix="64"
			;;
		*)
			suffix=""
			;;
	esac


	if [ ! -z $action ]
	then
		case $action in
			# remove thruk
			r)
				cadre " > Removing addon Thruk" green	
	
				userdel -f -r $THRUKUSER > /dev/null 2>&1
				groupdel $THRUKGRP > /dev/null 2>&1
				case $CODE in
					REDHAT)
						chkconfig --level thruk off
						chkconfig --del thruk
						rm -f /etc/httpd/conf.d/thruk.conf 
						rm -Rf $THRUKDIR
						;;
					*)
						update-rc.d -f thruk remove
						;;
				esac
				exit 0
				;;
			i)
				cadre " > Installing thruk (this should take a long time if you choosed to build thruk from sources)" green
				;;
				
			*)
				cecho "Invalid action for module" red
				exit 2
				;;
		esac
	fi
	
	# clean up tmp folder
	rm -Rf $TMP/Thruk*
	rm -Rf $TMP/mod_fastcgi*

	# check exist
	if [ -d "$THRUKDIR" ]
	then
		cecho "Thruk allready exist" red
		exit 2
	fi
	
	# platform
	if [ "$CODE" != "REDHAT" ]
	then
		cecho " > Curently not implemented" red
		exit 2
	fi
	arch=$(perl -e 'use Config; print $Config{archname}')
	vers=$(perl -e 'use Config; print $Config{version}')
	# prerequisites
	case $CODE in
		REDHAT)
			PACKAGES=$TYUMPKGS
			QUERY="rpm -q "
			;;
		DEBIAN)
			PACKAGES=$TAPTPKGS
			QUERY="dpkg -l "
			;;
	esac
	for p in $PACKAGES
	do
		$QUERY $p > /dev/null 2>&1
		if [ $? -ne 0 ]
		then
			cecho " > Installing $p " yellow
			installpkg pkg $p 
			if [ $? -ne 0 ]
			then 
				cecho " > Error while trying to install $p" red 
				exit 2 	
			fi
		else
			cecho " > Package $p allready installed " green 
		fi
	done
	
	# user/group
	if [ -z "$(cat /etc/passwd | grep $THRUKUSER)" ]
	then
		cecho " > Creating user $THRUKUSER" green
		#groupadd $THRUKGRP > /dev/null 2>&1
		useradd -d $THRUKDIR -m -s /bin/bash $THRUKUSER > /dev/null 2>&1

	fi
	
	# thruk
	if [ "$THRUKVERS" = "SRC" ]
	then
		cecho " > Getting thruk sources " green
		cecho " > Not implemented " red
		exit 2 
	else
		cecho " > Getting thruk version $THRUKVERS" green
		wget http://www.thruk.org/files/Thruk-$THRUKVERS-$arch-$vers.tar.gz > /dev/null 2>&1
		if [ $? -ne 0 ]
		then
			cecho " > Error while getting thruk package version $THRUKVERS" red
			exit 2
		fi
		cecho " > Extract thruk archive" green
		tar zxvf Thruk-$THRUKVERS-$arch-$vers.tar.gz > /dev/null 2>&1
		cecho " > Deploy thruk to $THRUKDIR" green
		cp -Rf Thruk-$THRUKVERS/* $THRUKDIR
		cecho " > Activate local config" green
		sed -i "s/^<Component Thruk::Backend>/&\n\t<peer>\n\t\tname = Local shinken\n\t\ttype = livestatus\n\t\t<options>\n\t\t\tpeer = localhost:50000\n\t\t<\/options>\n\t<\/peer>/g" $THRUKDIR/thruk.conf
		if [ "$CODE" = "REDHAT" ]
		then
			case $(uname -i) in
				x86_64)
					suffix="64"
					;;
				*)
					suffix=""
					;;
			esac
			# check mod fastcgi for apache
			if [ -f /usr/lib$suffix/httpd/modules/mod_fastcgi.so ]
			then
				cecho " > mod_fastcgi module allready exist" green
			else
				# build module fastcgi !
				cd $TMP 
				cecho " > Downloading mod_fastcgi sources" yellow
				wget http://www.fastcgi.com/dist/mod_fastcgi-current.tar.gz > /dev/null 2>&1
				tar zxvf mod_fastcgi-current.tar.gz > /dev/null 2>&1
				cd $(ls -1 | grep "^mod_fastcgi")
				cecho " > Building mod_fastcgi sources" yellow
				apxs -i -a -o mod_fastcgi.so -c *.c > /dev/null 2>&1
			fi
		fi
		
		# configure with mode fastcgi
		cecho " > deploy apache fast_cgi configuration" green
		case $CODE in
			REDHAT)
				httpd_conf_dir=/etc/httpd/conf.d
				enable="chkconfig --add thruk && chkconfig thruk on"
				;;
			*)
				httpd_conf_dir=/etc/apache2/conf.d
				enable="update-rc.d thruk defaults"
				;;
		esac
		cat $myscripts/addons/thruk/apache_thruk_fast_cgi_vhost.dist | sed   "s#THRUKDIR#"$THRUKDIR"#g" > $httpd_conf_dir/thruk.conf
		cat $myscripts/addons/thruk/thruk.dist | sed   "s#THRUKDIR#"$THRUKDIR"#g" > /etc/init.d/thruk
		sed -i "s/# Short-Description:\(.*\)/# Short-Description: &\n#Description: &/" /etc/init.d/thruk 
		foo=$(enable)


		cecho " > Fix permissions" green
		chown -R $THRUKUSER:$THRUKGRP $THRUKDIR
		
	fi
	mcadre "mcline" green
	mcadre "Shinken is now installed" green
	mcadre "mcline" green
	mcadre "Target folder is : $THRUKDIR
Start thruk with $THRUKDIR/scripts/thruk_server.pl
You can access thruk at the followinf url : http://localhost:3000" green
	mcadre "mcline" green
}

function usage(){
echo "Usage : shinken -k | -i | -d | -u | -b | -r | -l | -c | -h | -a 
	-k	Kill shinken
	-i	Install shinkeni
	-d 	Remove shinken
	-u	Update an existing shinken installation
	-b	Backup shinken configuration plugins and data
	-r 	Restore shinken configuration plugins and data
	-l	List shinken backups
	-c	Compress rotated logs
	-a	addon name (curently thruk)
	-h	Show help
"

}


# Check if we launch the script with root privileges (aka sudo)
if [ "$UID" != "0" ]
then
        cecho "You should start the script with sudo!" red
        exit 1
fi
while getopts "kidubcr:lzhsa:" opt; do
        case $opt in
		a)
			case $OPTARG in
				thruk)
					install_thruk
					exit 0
					;;
				*)
					cecho "Invalid addon ($OPTARG)"
					exit 2
					;;
			esac
			exit 0
			;;
		s)
			rheldvd	
			exit 0
			;;
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

