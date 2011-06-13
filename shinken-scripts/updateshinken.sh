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


function killshinken(){
	trap 'trap_handler ${LINENO} $? killshinken' ERR
	OLDIFS=$IFS
	IFS=$'\n'

	cecho "Killing shinken" green

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
	if [ -e shinken ]
	then
		rm -Rf shinken
	fi
	git clone $GIT
	cd shinken
	for fic in $(find . | xargs grep -snH "/usr/local/shinken" --color | cut -f1 -d' ' | awk -F : '{print $1}' | sort | uniq); do echo "Processing $fic"; cp $fic $fic.orig ; sed -i "s/\/usr\/local\/shinken/\/opt\/shinken/g" $fic ; done
}

function backup(){
	if [ ! -e $BACKUPDIR ]
	then
		mkdir -p $BACKUPDIR
	fi
	echo $DATE
	cd $BACKUPDIR
	tar czvf shinken.$DATE.tar.gz $TARGET
	cd $TMP
}

function deploy(){
	if [ ! -e $TARGET ]
	then
		mkdir -p $TARGET
	fi
	cd $TMP/shinken
	mv $TMP/shinken/* $TARGET
	chown -R $SKUSER:$SKPASSWD $TARGET
}

function usage(){
echo "Usage : shinken -k
	-k	kill shinken"
}


# Check if we launch the script with root privileges (aka sudo)
if [ "$UID" != "0" ]
then
        cecho "You should start the script with sudo!" red
        exit 1
fi

cecho "Parsing arguments" green

while getopts "k:" opt; do
        case $opt in
                k)
                        killshinken
                        exit 0
                        ;;
        esac
done
usage
exit 0



#killshinken
#get_from_git
#backup
#deploy
