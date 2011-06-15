#!/bin/bash -e

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
	DIST=$(cat /etc/issue | awk '{print $1}')
	DISTRO=""
	for d in $DISTROS
	do
		if [ "$d" = "$DIST" ]
		then
			cecho ">>Found $DIST" green
			export DISTRO=$DIST
		fi
	done
	if [ -z "$DISTRO" ]
	then
		cecho ">>No compatible distro found" red
		exit 2
	fi
}

function remove(){
	trap 'trap_handler ${LINENO} $? remove' ERR
	cecho "Removing shinken" green
	skill
	rm -Rf $TARGET
	rm -Rf /etc/default/shinken
	sudo update-rc.d -f shinken remove > /dev/null 2>&1
	rm -Rf /etc/init.d/shinken
}

function skill(){
	trap 'trap_handler ${LINENO} $? skill' ERR
	cecho "Killing shinken" green
	
	OLDIFS=$IFS
	IFS=$'\n'


	for p in $(ps -aef | grep "^shinken" | grep -v "npcd"|awk '{print $2}')
	do
		kill -9 $p
	done

	for p in $(ps -aef | grep "shinken-arbiter -d" | grep -v "grep"| awk '{print $2}')
	do
		kill -9 $p
	done


	IFS=$OLDIFS
	rm -Rf /tmp/bad_start*
	rm -Rf $TARGET/var/*.pid
}

function get_from_git(){
	trap 'trap_handler ${LINENO} $? get_from_git' ERR
	cecho "Getting shinken" green
	cd $TMP
	if [ -e shinken ]
	then
		rm -Rf shinken
	fi
	git clone $GIT > /dev/null 2>&1
	cd shinken
	cecho "Switching to version $VERSION" green
	git checkout $VERSION > /dev/null 2>&1
}

function relocate(){
	trap 'trap_handler ${LINENO} $? relocate' ERR
	cecho "Relocate source tree to $TARGET" green
	# relocate source tree
	for fic in $(find . | xargs grep -snH "/usr/local/shinken" --color | cut -f1 -d' ' | awk -F : '{print $1}' | sort | uniq); do cecho ">>Processing $fic" green; cp $fic $fic.orig ; sed -i 's#/usr/local/shinken#'$TARGET'#g' $fic ; done
	# relocate also all module.ini files
	for fic in ./etc/*.ini; 
	do 
		cecho ">>Processing $fic" green;
		sed -i "s#workdir=.*#workdir=/opt/shinken/var#g" $fic  ; 
		sed -i "1 s/^.*$/&\nworkdir=\/opt\/shinken\/var/g" $fic  ; 
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
                Ubuntu)
			update-rc.d shinken defaults 
                        exit 0
                        ;;
                Debian)
			update-rc.d shinken defaults 
                        exit 0
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

function update(){
	trap 'trap_handler ${LINENO} $? update' ERR
	cecho "Updating shinken" green
	cecho "Not implemented yet" red
}

function backup(){
	trap 'trap_handler ${LINENO} $? backup' ERR
	cecho "Backup shinken" green
	cecho "Not implemented yet" red
}

function usage(){
echo "Usage : shinken -k | -i | -d
	-k	Kill shinken
	-i	Install shinken
	-d 	Remove shinken
	-u	Update an existing shinken installation
	-b	Backup shinken configuration
"

}


# Check if we launch the script with root privileges (aka sudo)
if [ "$UID" != "0" ]
then
        cecho "You should start the script with sudo!" red
        exit 1
fi

cecho "Parsing arguments" green

while getopts "kidub" opt; do
        case $opt in
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
                       	update 
                        exit 0
                        ;;
                b)
                       	backup 
                        exit 0
                        ;;

        esac
done
usage
exit 0

