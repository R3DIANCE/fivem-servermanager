#!/bin/bash
clear
if [ "$(whoami)" != "root" ]; then
	echo "Please run this script as sudo."
	exit 1
fi


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR


OPTION=$(whiptail --title "Slluxx Server manager" --menu "Choose your option" 15 60 5 \
"1" "Manage existing servers" \
"2" "Add server" \
"3" "Delete server" \
"4" "Update FXdata" \
"5" "Update manager" 3>&1 1>&2 2>&3)

case "$OPTION" in
        1)
            manage=true
            ;;      
        2)
            add=true
            ;;
        3)
            delete=true
            ;;
        4)
            update=true
            ;;
        5)
            updatemanager=true
            ;;
        *)
            exit 1
esac



#
#
# ADD A SERVER
#
#

if [[ $add == "true" ]]; then

	question=$(whiptail --title "Internal servername" --inputbox "Choose a new, unique server name. NO SPACES! This wont be the servername shown online." 10 60 3>&1 1>&2 2>&3)
	exitstatus=$?
	if [ $exitstatus = 0 ]; then
	
	    if [ -d "./servers/$question" ]; then
	    	whiptail --title "ERROR" --msgbox "That name is already in use." 10 60
		./manager.sh
	    fi
	    
	    if echo $question | grep -q " "; then
	    	whiptail --title "ERROR" --msgbox "Please dont use spaces." 10 60
			./manager.sh
		fi
	    
	    git clone https://github.com/citizenfx/cfx-server-data.git ./servers/$question

		# creating config file
		port=30120
		while grep "$port" ./managerfiles/used-ports.txt
	    do
	    	port=$(($port+10))
	    done
	    clear
	    
	    port=$(whiptail --title "Choose Gameserver port" --inputbox "This port is already checked and not in use by a gameserver. Please change only if you know what you are doing!" 10 60 $port 3>&1 1>&2 2>&3)
		exitstatus=$?
		if [ $exitstatus = 0 ]; then
			port=$port
		else
			echo "You chose Cancel."
			exit 1
		fi
		
		servername=$(whiptail --title "Choose Gameserver Name" --inputbox "Choose a servername. Your server will be listed in the serverbrowser with that." 10 60 3>&1 1>&2 2>&3)
		exitstatus=$?
		if [ $exitstatus = 0 ]; then
			servername=$servername
		else
			echo "You chose Cancel."
			exit 1
		fi
		
		rcon=$(whiptail --title "Choose RCON password" --inputbox "This password is random." 10 60 $(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 10 | head -n 1) 3>&1 1>&2 2>&3)
		exitstatus=$?
		if [ $exitstatus = 0 ]; then
			rcon=$rcon
		else
			echo "You chose Cancel."
			exit 1
		fi
		
		
		
		cat ./managerfiles/default-config.cfg | \
		sed "s/VAR_PORT/$port/" | \
		sed "s/VAR_RCON_PASSWORD/$rcon/" | \
		sed "s/VAR_HOSTNAME/$servername/">>./servers/$question/config.cfg
		
	    echo "$port">>./managerfiles/used-ports.txt
	    whiptail --title "SUCCESS" --msgbox "Your server should be sucessfully installed." 10 60
	    ./manager.sh
	else
	    ./manager.sh
	fi

fi

#
#
# DELETE A SERVER
#
#

if [[ $delete == "true" ]]; then


	COUNT=1
	AUX=0;
	serverpath="./servers"
	for server in $serverpath/*; do
	    if ! [ -d $server ]; then
		if [ $server == "./servers/*" ]; then
			whiptail --title "ERROR" --msgbox "There is no server that can be deleted" 10 60
			./manager.sh
		else
			echo "$server is not a directory, what the hell is it doing here?"
			rm -v -f $server
		fi
	    else
		server=${server:${#serverpath}}
		STR[AUX]="${server:1} <-"
		COUNT+=1
		AUX+=1
	    fi
	done
	delserver=$(whiptail --title "DELETE a server" --menu "Choose a server to delete" 15 60 6 ${STR[@]} 3>&1 1>&2 2>&3)
	exitstatus=$?
	if ! [ $exitstatus = 0 ]; then
		./manager.sh
	else
		# read out the port
		port="$(grep 'endpoint_add_tcp' ./servers/$delserver/config.cfg | sed 's/endpoint_add_tcp //' | tr -d \" | sed 's/.*://')"
		sed -i "/$port/d" ./managerfiles/used-ports.txt
		cd ./servers
		rm -f -r ./$delserver
		cd ..

		whiptail --title "SUCCESS" --msgbox "Your server should be sucessfully deleted." 10 60
		./manager.sh
	fi
fi

#
#
# UPDATE FXDATA
#
#

if [[ $update == "true" ]]; then

for server in ./servers/*; do
		server="$(echo $server | sed 's,.*/,,')"
		if screen -list | grep -q "$server"; then
		    echo "BEFORE YOU CAN UPDATE: SHUTDOWN -> $server"
		fi
done
for server in ./servers/*; do
		server="$(echo $server | sed 's,.*/,,')"
		if screen -list | grep -q "$server"; then
		    exit 1
		fi
done


masterfolder="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/"
newestfxdata="$(curl $masterfolder | grep '<a href' | tail -1 | awk -F[\>\<] '{print $3}')"
# filter valid urls and take last one.

rm -R ./fxdata
mkdir fxdata
cd fxdata
wget ${masterfolder}${newestfxdata}fx.tar.xz 
tar xf fx.tar.xz
rm ./fx.tar.xz
cd ..
chmod -R 777 ./*
whiptail --title "SUCCESS" --msgbox "FX update complete" 10 60
./manager.sh
fi


#
#
# UPDATE MANAGER
#
#


if [[ $updatemanager == "true" ]]; then
/master/init.sh
managerurl="https://raw.githubusercontent.com/R3DIANCE/fivem-servermanager/master/manager.sh"
configurl="https://raw.githubusercontent.com/R3DIANCE/fivem-servermanager/master/managerfiles/default-config.cfg"

rm ./manager.sh
wget $managerurl
chmod +x ./manager.sh

cd ./managerfiles
rm ./default-config.cfg
wget $configurl
chmod +x ./default-config.cfg
cd ..
whiptail --title "SUCCESS" --msgbox "Manager update complete" 10 60
./manager.sh
fi

#
#
# MANAGE SERVERS
#
#

if [[ $manage == "true" ]]; then


OPTION=$(whiptail --title "Manage your Server" --menu "Choose an option" 15 60 5 \
"1" "Start" \
"2" "Stop" \
"3" "Restart" \
"4" "Show Console" 3>&1 1>&2 2>&3)

case "$OPTION" in
        1)
            start=true
            ;;      
        2)
            stop=true
            ;;
        3)
            restart=true
            ;;
        4)
            console=true
            ;;
        *)
            exit 1
esac

if [[ $start == "true" ]]; then

	COUNT=1
	AUX=0;
	serverpath="./servers"
	for server in $serverpath/*; do
	    if ! [ -d $server ]; then
		echo "$server is not a directory, what the hell is it doing here?"
		rm -v -f $server
	    else
		server=${server:${#serverpath}}
		STR[AUX]="${server:1} <-"
		COUNT+=1
		AUX+=1
	    fi
	done
	startserver=$(whiptail --title "Choose a server" --menu "Choose a server" 15 60 6 ${STR[@]} 3>&1 1>&2 2>&3)
	exitstatus=$?
	if ! [ $exitstatus = 0 ]; then
		./manager.sh
	else
		if ! screen -list | grep -q "$startserver"; then
			cd ./servers/$startserver
			screen -dmS $startserver ../../fxdata/run.sh +exec config.cfg
			cd ../../
			whiptail --title "SUCCESS" --msgbox "Server started." 10 60
			./manager.sh
		else
			whiptail --title "ERROR" --msgbox "This server is already running." 10 60
			./manager.sh
		fi
	fi

fi


if [[ $stop == "true" ]]; then

	COUNT=1
	AUX=0;
	serverpath="./servers"
	for server in $serverpath/*; do
	    if ! [ -d $server ]; then
		echo "$server is not a directory, what the hell is it doing here?"
		rm -v -f $server
	    else
		server=${server:${#serverpath}}
		STR[AUX]="${server:1} <-"
		COUNT+=1
		AUX+=1
	    fi
	done
	stopserver=$(whiptail --title "Choose a server" --menu "Choose a server" 15 60 6 ${STR[@]} 3>&1 1>&2 2>&3)
	exitstatus=$?
	if ! [ $exitstatus = 0 ]; then
		./manager.sh
	else
		if screen -list | grep -q "$stopserver"; then
		    	screen -S $stopserver -X at "#" stuff ^C
			whiptail --title "SUCCESS" --msgbox "Server stopped." 10 60
			./manager.sh
		else
			whiptail --title "ERROR" --msgbox "This server is not running." 10 60
			./manager.sh
		fi
	fi


fi


if [[ $restart == "true" ]]; then

	COUNT=1
	AUX=0;
	serverpath="./servers"
	for server in $serverpath/*; do
	    if ! [ -d $server ]; then
		echo "$server is not a directory, what the hell is it doing here?"
		rm -v -f $server
	    else
		server=${server:${#serverpath}}
		STR[AUX]="${server:1} <-"
		COUNT+=1
		AUX+=1
	    fi
	done
	
	restart=$(whiptail --title "Choose a server" --menu "Choose a server" 15 60 6 ${STR[@]} 3>&1 1>&2 2>&3)
	exitstatus=$?
	if ! [ $exitstatus = 0 ]; then
		./manager.sh
	else
		if screen -list | grep -q "$restart"; then
			screen -S $restart -X at "#" stuff ^C
			cd ./servers/$restart
			screen -dmS $restart ../../fxdata/run.sh +exec config.cfg
			cd ../../
			whiptail --title "SUCCESS" --msgbox "Server restarted." 10 60
			./manager.sh
		else
			whiptail --title "ERROR" --msgbox "This server is not running." 10 60
			./manager.sh
		fi
	fi
fi


if [[ $console == "true" ]]; then

	COUNT=1
	AUX=0;
	serverpath="./servers"
	for server in $serverpath/*; do
	    if ! [ -d $server ]; then
		echo "$server is not a directory, what the hell is it doing here?"
		rm -v -f $server
	    else
		server=${server:${#serverpath}}
		STR[AUX]="${server:1} <-"
		COUNT+=1
		AUX+=1
	    fi
	done
	console=$(whiptail --title "Choose a server" --menu "Choose a server" 15 60 6 ${STR[@]} 3>&1 1>&2 2>&3)
	exitstatus=$?
	if ! [ $exitstatus = 0 ]; then
		./manager.sh
	else
		if screen -list | grep -q "$console"; then
		    whiptail --title "REMEMBER" --msgbox "To quit console, never exit or use CTRL + C. It will close the server! Instead hold down CTRL and press A,D!" 10 60
		    screen -r $console
		    ./manager.sh
		else
			whiptail --title "ERROR" --msgbox "That server is not running." 10 60
			./manager.sh
		fi
	fi

fi


fi

