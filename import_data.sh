#!/bin/bash

# Version Info
echo "Export 2 Garmin Connect v1.4 (import_data.sh)"
echo ""

# Blocking multiple instances of same script process
timenow="date +%d.%m.%Y-%H:%M:%S"
remove_lock()
{
    rm -f "/dev/shm/export.lock"
}
another_instance()
{
	echo "$($timenow) EXPORT * Another instance running"
	exit 1
}
lockfile -r 0 -l 60 "/dev/shm/export.lock" || another_instance
trap remove_lock EXIT

# Create a loop, "-l" parameter executes loop indefinitely
if [ "$1" == "-l" ] ; then
    loop_count=0
else
    loop_count=1
fi
i=0
while [ $loop_count -eq 0 ] || [ $i -lt $loop_count ] ; do
	((i++))

	# Cleaning temp.log file after last startup
	if [ -s /dev/shm/temp.log ] ; then
		> /dev/shm/temp.log
	fi

	# Mi Body Composition Scale 2
	path=`cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd`
	export $(grep import_data_ $path/user/export2garmin.cfg)
	if [ $import_data_miscale_switch == "on" ] ; then
		echo "$($timenow) MISCALE * Module is on"

		# Creating miscale_backup.csv and temp.log file
		if [ ! -f $path/user/miscale_backup.csv ] ; then
			header="Data Status;Unix Time;Date;Time;Weight [kg];Change [kg];BMI;Body Fat [%];Skeletal Muscle Mass [kg];Bone Mass [kg];Body Water [%];Physique Rating;Visceral Fat;Metabolic Age [years];BMR [kCal];LBM [kg];Ideal Wieght [kg];Fat Mass To Ideal [type:mass kg];Protein [%];Impedance;Login e-mail;Upload Date;Upload Time;Difference Time [s]"
			echo "$($timenow) MISCALE * Creating miscale_backup.csv file, check if temp.log exists"
			if [ $import_data_mqtt == "off" ] ; then
				echo "$header" > $path/user/miscale_backup.csv
			else echo "$header;Battery [V];Battery [%]" > $path/user/miscale_backup.csv
			fi
		else echo "$($timenow) MISCALE * miscale_backup.csv file exists, check if temp.log exists"
		fi
		if [ ! -f /dev/shm/temp.log ] ; then
			echo "$($timenow) MISCALE * Creating temp.log file, checking for new data"
			echo > /dev/shm/temp.log
		else echo "$($timenow) MISCALE * temp.log file exists, checking for new data"
		fi

		# Importing raw data from source (BLE or MQTT)
		if [ $import_data_mqtt == "off" ] ; then
			echo "$($timenow) MISCALE * Importing data from a BLE scanner"
			read_all_miscale=`python3 -B $path/miscale/miscale_ble.py`
			read_miscale=`echo $read_all_miscale | awk '{sub(/.*BLE scan/, ""); print substr($1,1)}'`
		else echo "$($timenow) MISCALE * Importing data from an MQTT broker"
			read_miscale=`mosquitto_sub -h localhost -t 'data' -u $import_data_miscale_user -P $import_data_miscale_passwd -C 1 -W 10`
		fi

		# Checking if BLE scanner detects BLE devices, print to temp.log file, restart service, reimport
		unixtime_miscale=`echo $read_miscale | awk -F ";" '{print $1}'`
		if [ -z $unixtime_miscale ] ; then
			if [ $import_data_mqtt == "off" ] ; then
				if echo $read_all_miscale | grep -q "device" ; then
					echo "$($timenow) MISCALE * No BLE data from scale or incomplete, check BLE scanner"
					if grep -q "bluetooth" /dev/shm/temp.log ; then
						sed -i "/bluetooth/d" /dev/shm/temp.log
					fi
				else
					if [ ! -f /dev/shm/temp.log ] ; then
						echo "$($timenow) MISCALE * No BLE devices found to scan, restarting bluetooth service" 2>&1 | tee /dev/shm/temp.log
						sudo systemctl restart bluetooth
						read_miscale=`python3 -B $path/miscale/miscale_ble.py | awk 'END{print}'`
						unixtime_miscale=`echo $read_miscale | awk -F ";" '{print $1}'`
					elif grep -q "bluetooth" /dev/shm/temp.log ; then
						echo "$($timenow) MISCALE * Again, no BLE devices found to scan"
					else echo "$($timenow) MISCALE * No BLE devices found to scan, restarting bluetooth service" 2>&1 | tee /dev/shm/temp.log
						sudo systemctl restart bluetooth
						read_miscale=`python3 -B $path/miscale/miscale_ble.py | awk 'END{print}'`
						unixtime_miscale=`echo $read_miscale | awk -F ";" '{print $1}'`
					fi
				fi
			else echo "$($timenow) MISCALE * No MQTT data, check connection to MQTT broker or ESP32"
			fi
		fi

		# Checking raw data and time, save correct raw data to miscale_backup.csv file
		if [ ! -z $unixtime_miscale ] ; then
			time_zone=`date +%z | awk '{print substr($1,1,3)}'`
			offset_unixtime_miscale=$(( $unixtime_miscale + $time_zone * 3600 + $import_data_miscale_offset ))
			offset_miscale=${read_miscale/${unixtime_miscale}/to_import;${offset_unixtime_miscale}}
			cut_miscale=`echo $offset_unixtime_miscale | awk '{print substr($1,1,8)}'`
			unixtime_os=`date +%s`
			time_shift_miscale=$(( $unixtime_os - $offset_unixtime_miscale ))
			if grep -q $cut_miscale $path/user/miscale_backup.csv ; then
				time_tag_miscale=`grep -m 1 $cut_miscale $path/user/miscale_backup.csv | awk -F ";" '{print $2}'`
				time_dif_miscale=$(( $offset_unixtime_miscale - $time_tag_miscale ))
				absolute_dif_miscale=`echo ${time_dif_miscale#-}`
				if (( $absolute_dif_miscale < 30 )) ; then
					echo "$($timenow) MISCALE * $time_dif_miscale s time difference, same or similar data already exists in miscale_backup.csv file"
				else absolute_shift_miscale=`echo ${time_shift_miscale#-}`
					if (( $absolute_shift_miscale > 1200 )) ; then
						echo "$($timenow) MISCALE * $time_shift_miscale s time difference, synchronize date and time scale"
						echo "$($timenow) MISCALE * Time offset is set to $offset s"
						echo "$($timenow) MISCALE * Deleting import $offset_unixtime_miscale from miscale_backup.csv file"
						sed -i "/$offset_unixtime_miscale/d" $path/user/miscale_backup.csv
					else echo "$($timenow) MISCALE * Saving import $offset_unixtime_miscale to miscale_backup.csv file"
						echo $offset_miscale >> $path/user/miscale_backup.csv
					fi
				fi
			else absolute_shift_miscale=`echo ${time_shift_miscale#-}`
				if (( $absolute_shift_miscale > 1200 )) ; then
					echo "$($timenow) MISCALE * $time_shift_miscale s time difference, synchronize date and time scale"
					echo "$($timenow) MISCALE * Time offset is set to $offset s"
				else echo "$($timenow) MISCALE * Saving import $offset_unixtime_miscale to miscale_backup.csv file"
					echo $offset_miscale >> $path/user/miscale_backup.csv
				fi
			fi
		fi

		# Calculating data and upload to Garmin Connect, print to temp.log file
		if grep -q "failed\|to_import" $path/user/miscale_backup.csv ; then
			if grep -q "bluetooth" /dev/shm/temp.log ; then
				echo "$($timenow) MISCALE * No BLE devices found to scan, restarting bluetooth service" > /dev/shm/temp.log
				python3 -B $path/miscale/miscale_export.py >> /dev/shm/temp.log 2>&1
				import_miscale=`awk -F ": " '/MISCALE /*/ Import data:/{print substr($2,1,10)}' /dev/shm/temp.log`
			else python3 -B $path/miscale/miscale_export.py > /dev/shm/temp.log 2>&1
				import_miscale=`awk -F ": " '/MISCALE /*/ Import data:/{print substr($2,1,10)}' /dev/shm/temp.log`
			fi
		fi

		# Handling errors, save calculated data to miscale_backup.csv file
		if [ -z $import_miscale ] ; then
			echo "$($timenow) MISCALE * There is no new data to upload to Garmin Connect"
		else echo "$($timenow) MISCALE * Calculating data from import $import_miscale, upload to Garmin Connect"
			if grep -q "MISCALE \* There" /dev/shm/temp.log ; then
				echo "$($timenow) MISCALE * There is no user with given weight or undefined user email@email.com, check users section in export2garmin.cfg"
				echo "$($timenow) MISCALE * Deleting import $import_miscale from miscale_backup.csv file"
				sed -i "/$import_miscale/d" $path/user/miscale_backup.csv
			elif grep -q "Err" /dev/shm/temp.log ; then
				echo "$($timenow) MISCALE * Upload to Garmin Connect has failed, check temp.log for error details"
				sed -i "s/to_import;$import_miscale/failed;$import_miscale/" $path/user/miscale_backup.csv
			else echo "$($timenow) MISCALE * Data upload to Garmin Connect is complete"
				echo "$($timenow) MISCALE * Saving calculated data from import $import_miscale to miscale_backup.csv file"
				calc_data_miscale=`awk -F ": " '/MISCALE /*/ Calculated data:/{print $2}' /dev/shm/temp.log`
				import_data_miscale=`awk -F ": " '/MISCALE /*/ Import data:/{print $2}' /dev/shm/temp.log`
				sed -i "s/failed;$import_data_miscale/uploaded;$import_miscale;$calc_data_miscale;$time_shift_miscale/; s/to_import;$import_data_miscale/uploaded;$import_miscale;$calc_data_miscale;$time_shift_miscale/" $path/user/miscale_backup.csv
				import_diff_miscale=`echo $calc_data_miscale | awk -F ";" '{print $1 ";" $2 ";" $3}'`
				check_line=`wc -l < $path/user/miscale_backup.csv`
				if [ $check_line == "2" ] ; then
					sed -i "s/$import_miscale;$import_diff_miscale/$import_miscale;$import_diff_miscale;0.0/" $path/user/miscale_backup.csv
				else email_user=`echo $calc_data_miscale | awk -F ";" '{print $18}'`
					weight_last=`grep $email_user $path/user/miscale_backup.csv | sed -n 'x;$p' | awk -F ";" '{print $5}'`
					weight_import=`echo $calc_data_miscale | awk -F ";" '{print $3}'`
					weight_diff=`echo $weight_import - $weight_last | bc | sed "s/^-\./-0./; s/^\./0./"`
					sed -i "s/$import_miscale;$import_diff_miscale/$import_miscale;$import_diff_miscale;$weight_diff/; s/;0;/;0.0;/" $path/user/miscale_backup.csv
				fi
			fi
		fi
		unset unixtime_miscale time_zone offset_miscale cut_miscale unixtime_os time_shift_miscale time_tag_miscale time_dif_miscale absolute_dif_miscale absolute_shift_miscale import_miscale calc_data_miscale import_data_miscale import_diff_miscale check_line email_user weight_last weight_import weight_diff
	else echo "$($timenow) MISCALE * Module is off"
	fi

	# Omron blood pressure
	if [ $import_data_omron_switch == "on" ] ; then
		export $(grep omron_omblepy_ $path/user/export2garmin.cfg)

		# Creating omron_backup.csv and temp.log file
		if [ ! -f $path/user/omron_backup.csv ] ; then
			echo "Data Status;Unix Time;Email User;Date;Time;DIA;SYS;BPM;MOV;IHB;Upload Date;Upload Time;Difference Time [s]" > $path/user/omron_backup.csv
			echo "$($timenow) OMRON * Creating omron_backup.csv file, check if temp.log exists"
		else echo "$($timenow) OMRON * omron_backup.csv file exists, check if temp.log exists"
		fi
		if [ ! -f /dev/shm/temp.log ] ; then
			echo "$($timenow) OMRON * Creating temp.log file, checking for new data"
			echo > /dev/shm/temp.log
		else echo "$($timenow) OMRON * temp.log file exists, checking for new data"
		fi
		if [ -z `hcitool dev | awk 'NR>1 {print $2}'` ] ; then
			echo "$($timenow) OMRON * No BLE device detected, skip scanning"

		# Importing raw data from source (BLE)
		else echo "$($timenow) OMRON * Importing data from a BLE scanner"
			coproc ble { bluetoothctl; }
			while true ; do
				timeout 10s python3 -B $path/omron/omblepy.py -p -d $omron_omblepy_model > /dev/shm/omron_users.csv 2>&1
				if grep -q $omron_omblepy_mac /dev/shm/omron_users.csv ; then
					if [ $omron_omblepy_debug == "on" ] ; then
						python3 -B $path/omron/omblepy.py -n -t -d $omron_omblepy_model --loggerDebug -m $omron_omblepy_mac
					elif [ $omron_omblepy_all == "on" ] ; then
						python3 -B $path/omron/omblepy.py -t -d $omron_omblepy_model -m $omron_omblepy_mac > /dev/null 2>&1
					else
						python3 -B $path/omron/omblepy.py -n -t -d $omron_omblepy_model -m $omron_omblepy_mac > /dev/null 2>&1
					fi
				else exec {ble[0]}>&-
					exec {ble[1]}>&-
					wait $ble_PID
					break
				fi
			done
			if [ -f "/dev/shm/omron_user1.csv" ] || [ -f "/dev/shm/omron_user2.csv" ]; then
				echo "$($timenow) OMRON * Prepare data for omron_backup.csv file"
				awk -F ';' 'NR==FNR{a[$2];next}!($2 in a)' $path/user/omron_backup.csv /dev/shm/omron_user1.csv > /dev/shm/omron_users.csv
				awk -F ';' 'NR==FNR{a[$2];next}!($2 in a)' $path/user/omron_backup.csv /dev/shm/omron_user2.csv >> /dev/shm/omron_users.csv
				sed -i "s/ /;/g; s/user1/$import_data_user1/; s/user2/$import_data_user2/" /dev/shm/omron_users.csv
				if grep -q "email@email.com" /dev/shm/omron_users.csv ; then
					echo "$($timenow) OMRON * Deleting records with undefined user email@email.com, check users section in export2garmin.cfg"
					sed -i "/email@email\.com/d" /dev/shm/omron_users.csv
				fi
				cat /dev/shm/omron_users.csv >> $path/user/omron_backup.csv
				rm /dev/shm/omron_user*.csv
			else echo "$($timenow) OMRON * No BLE data from Omron, check BLE scanner"
				rm /dev/shm/omron_users.csv
			fi
		fi

		# Upload to Garmin Connect, print to temp.log file
		if grep -q "failed\|to_import" $path/user/omron_backup.csv ; then

			if [ $import_data_miscale_switch == "on" ] ; then
				python3 -B $path/omron/omron_export.py >> /dev/shm/temp.log 2>&1
				import_omron=`awk -F ": " '/OMRON /*/ Import data:/{print substr($2,1,10)}' /dev/shm/temp.log`
			else python3 -B $path/omron/omron_export.py > /dev/shm/temp.log 2>&1
				import_omron=`awk -F ": " '/OMRON /*/ Import data:/{print substr($2,1,10)}' /dev/shm/temp.log`
			fi
		fi

		# Handling errors, save data to miscale_backup.csv file
		if [ -z $import_omron ] ; then
			echo "$($timenow) OMRON * There is no new data Omron to upload to Garmin Connect"
		else echo "$($timenow) OMRON * Data from import $import_omron upload to Garmin Connect"
			if grep -q "Err" /dev/shm/temp.log ; then
				if grep -q "MISCALE \* Upload" /dev/shm/temp.log ; then
					echo "$($timenow) OMRON * Upload to Garmin Connect has failed, check temp.log for error details"
					sed -i "s/to_import;$import_omron/failed;$import_omron/" $path/user/omron_backup.csv
				elif grep -q "OMRON \* Upload" /dev/shm/temp.log ; then
					echo "$($timenow) OMRON * Data upload to Garmin Connect is complete"
					echo "$($timenow) OMRON * Saving calculated data from import $import_omron to omron_backup.csv file"
					import_data_omron=`awk -F ": " '/OMRON /*/ Import data:/{print $2}' /dev/shm/temp.log`
					data_time_omron=`awk -F ": " '/OMRON /*/ Export date time:/{print $2}' /dev/shm/temp.log`
					unixtime_os=`date +%s`
					time_shift_omron=$(( $unixtime_os - $import_omron ))
					sed -i "s/failed;$import_data_omron/uploaded;import_data_omron;$data_time_omron;$time_shift_omron/; s/to_import;$import_data_omron/uploaded;$import_data_omron;$data_time_omron;$time_shift_omron/" $path/user/omron_backup.csv
				else
					echo "$($timenow) OMRON * Upload to Garmin Connect has failed, check temp.log for error details"
					sed -i "s/to_import;$import_omron/failed;$import_omron/" $path/user/omron_backup.csv
				fi
			else echo "$($timenow) OMRON * Data upload to Garmin Connect is complete"
				echo "$($timenow) OMRON * Saving calculated data from import $import_omron to omron_backup.csv file"
				import_data_omron=`awk -F ": " '/OMRON /*/ Import data:/{print $2}' /dev/shm/temp.log`
				data_time_omron=`awk -F ": " '/OMRON /*/ Export date time:/{print $2}' /dev/shm/temp.log`
				unixtime_os=`date +%s`
				time_shift_omron=$(( $unixtime_os - $import_omron ))
				sed -i "s/failed;$import_data_omron/uploaded;import_data_omron;$data_time_omron;$time_shift_omron/; s/to_import;$import_data_omron/uploaded;$import_data_omron;$data_time_omron;$time_shift_omron/" $path/user/omron_backup.csv
			fi
		fi
		unset import_omron import_data_omron data_time_omron unixtime_os time_shift_omron
	else echo "$($timenow) OMRON * Module is off"
	fi
	if [ $loop_count -eq 1 ] ; then
		break
    fi
done