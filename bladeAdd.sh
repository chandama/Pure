#!/bin/bash

### Command line args
declare -i chassisNum=$1
declare -i bladeStart=$2
declare -i bladeEnd=$3

#DONE 		 Get the node ID's and throw them into an array once you parse them and just get the number out and strip the rest.
#DONE 		 Check for master XFM
#DONE 		 Confirm chassis and blade selection is correct
#DONE		 Run checks for clean blades and verify that all elements are empty

populate_array(){

	echo "Getting node IDs for CH.$chassisNum.FB$bladeStart-$bladeEnd..."
	declare -a node_id_array=()

	for ((i=$bladeStart;i<=$bladeEnd;i++))
	do
	        ### Insert into node_id_array
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
	echo "DONE"
	echo ""
}

clean_blade_check(){

	echo "Checking that all blades in CH.$chassisNum.$bladeStart-$bladeEnd are clean..."

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
    	echo "Not all blades are clean, please check the blades and try again"
    	exit;
    else
		echo "DONE"
		echo ""
	fi
}

mastership_check(){

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
		echo "DONE"
		echo ""
	elif [[ $host != $master ]]; then
		echo "$host is not the master XFM. Please rerun on $master"
		exit;
	else
			echo "Unknown error"
			exit;
	fi
}

blade_add(){
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


### In the future you could have function return a TRUE/FALSE and then use if func() and test that from in here and add the echo output here
while true; do
    read -p "You have selected the following blades: CH$chassisNum.FB$bladeStart-$bladeEnd is this correct? [Y]es [N]o: " yn
    case $yn in
        [Yy]* ) 
			populate_array "$chassisNum" "$bladeStart" "$bladeEnd"
			clean_blade_check "$chassisNum" "$bladeStart" "$bladeEnd"
			mastership_check
			blade_add "$chassisNum" "$bladeStart" "$bladeEnd"
			break;;
        [Nn]* ) 
			exit;;
        * ) echo "Please answer yes or no.";;
    esac
done


