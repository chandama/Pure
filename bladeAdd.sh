#!/bin/bash

#####################################################################################
#                                                                                   #
#        Script designed to perform health checks and add unclaimed blades          #
#                                                                                   #
#		 Author: Chandler Taylor									                #
#		Version: 1.1																#
#		Updated: 2021-04-21															#
#                                                                                   #
#####################################################################################



### Command line args
	declare -i chassisNum=$1
	declare -i bladeStart=$2
	declare -i bladeEnd=$3

### Color codes for use in ERROR and PASS messages
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

populate_array()
{
	echo "Getting node IDs for CH$chassisNum.FB$bladeStart-$bladeEnd"

	declare -a node_id_array=()

	for ((i=$bladeStart;i<=$bladeEnd;i++))
	do
	        ### Insert output of hal-show into node_id_array
	        node_id_array+=("$(exec.py -n$chassisNum.$i -- 'hal-show -e /local/ | jq .node_id')")
	done

	printf '%s\n' "${node_id_array[@]}"
	### ELEMENT = $ of elements in array
	declare -i ELEMENT=${#node_id_array[@]}

	### Iterate over the elements in the array and trim the elements so only the node id is remaining
	for ((i=0;i<ELEMENT;i++))
	do
	        substring=$(echo ${node_id_array[$i]} | cut -d'"' -f 2)
	        node_id_array[$i]=$substring
	done
	return 0
}

clean_blade_check()
{
	echo "Checking blades: CH$chassisNum.$bladeStart-$bladeEnd are clean"

	declare -a clean_array=()
	clean=true

	for ((i=$bladeStart;i<=$bladeEnd;i++))
	do
		### Fill clean_array with the output from the hal-eeprom cmd to check if blade is clean or not
		clean_array+=("$(exec.py -n$chassisNum.$i 'hal-eeprom -e /local/eeprom/id --read --partition 1')")
	done

    ### Check if all blades are clean
    ### If any blade is inducted, note the blade number and notify before exiting script
    for i in "${clean_array[@]}"
    do
            if [[ $i =~ .*"array_id".* ]]; then
                    clean=false
                    echo "$i is not clean, please check that all blades are clean before continuing"
            else
                    echo "$i ... OK"
            fi
    done
        ### Check clean variable to see if any unclean blades were found. Exit if so, return true if not.
    if [[ $clean == false ]]; then
    	return 1
    else
		return 0
	fi
}

mastership_check()
{
	echo "Checking XFM Mastership"

	host=$(hostname)
	mastership=$(puremastership list)

	### return just the xfm or fm number of the host this script is being executed from
	host=$(echo $host | cut -d'-' -f 4)
	
	### Search mastership string for 'master' and return the lowercase version of the XFM number before it
	### Using grep -oP and the lookahead to find the word master and return the value before it which is the master XFM
	master=$(echo $mastership | grep -oP '\w+(?= master)')
	master=$(echo $master | tr '[:upper:]' '[:lower:]')

	### Check if host=master, if not, then exit w/ prompt to rerun on master (X)FM
	if [[ $host == $master ]]; then
		echo "Running on Master XFM"
		return 0
	elif [[ $host != $master ]]; then
		return 1
	else
			echo -e "${RED}ERROR${NC}: Unknown error"
			return 1
	fi
}

blade_add()
{
	for ((i=$bladeStart;i<=$bladeEnd;i++))
	do
	    echo "Adding blade CH$chassisNum.FB$i using node ID"
	    date
	    exec.py -n$chassisNum.$i "hal-show -e /local/ | jq .node_id" | perl -ne '/(?<=\")(.*?)(?=\")/ && print $1' | xargs -I % rpc.py add_blade '{"node_id": %}' --timeout 0
	    echo ""
	    fbdiag wait-helper -n$chassisNum.$i -v
	    sleep 5
	    pureblade list CH$chassisNum.FB$i 
	    echo ""
	    sleep 10
	done
}

### Comment all of this stuff out until its ready to be hashed out.

help()
{
	echo "HELP"
}

scan()
{
	### Scan for unclaimed blades and also check for clean blades. Grab Node ID
	echo "SCANNING"
}

parse_params()
{
	range=$1
	echo $1 | grep -oP '.*?(?<=\.)' ##-n2.1-13
}

### idiomatic parameter and option handling in sh
#while test $# -gt 0
#do
#    case "$1" in
#        -h) ### Display help message
#			help
#            ;;
#        -n*) ## Use -n format for fbupgrade script
#			parse_params
#            ;;
#        --scan)
#			scan
#            ;;
#        *) echo "argument $1"
#            ;;
#    esac
#    shift
#done



### In the future you could have function return a TRUE/FALSE and then use if func() and test that from in here and add the echo output here
while true; do
    read -p "You have selected the following blades: CH$chassisNum.FB$bladeStart-$bladeEnd is this correct? [Y]es [N]o: " yn
    case $yn in
        [Yy]* ) 
			if populate_array "$chassisNum" "$bladeStart" "$bladeEnd"; then
				echo -e "${GREEN}DONE${NC}"
				echo ""
			else
				echo -e "${RED}ERROR${NC}: Could not populate array"
				echo ""
				failure=true
			fi

			if clean_blade_check "$chassisNum" "$bladeStart" "$bladeEnd"; then
				echo -e "${GREEN}DONE${NC}"
				echo ""
			else
			    echo -e "${RED}ERROR${NC}: Not all blades are clean, please check the blades and try again"
    			echo ""	
    			failure=true
			fi

			if mastership_check; then
				echo -e "${GREEN}DONE${NC}"
				echo ""
			else
				echo -e "${RED}ERROR${NC}: $host is not the master XFM. Please rerun on $master"
				echo ""
				failure=true
			fi

			if [[ -z $failure ]]; then
				blade_add "$chassisNum" "$bladeStart" "$bladeEnd"
			else
				echo -e "Could not add blades. Please fix the ${RED}ERROR${NC}(s) above."
			fi
			break;;
        [Nn]* ) 
			exit;;
        * ) echo "Please answer yes or no.";;
    esac
done


