#!/bin/bash
set -e

function sharedata() {
	printf "\r\033[KSample #$1 -> Completed\n"
	echo "Starting Docker..."
	sudo docker run --rm --cap-drop=ALL --security-opt=no-new-privileges \
	--user=puppet -v $2:/home/puppet/work/data:ro \
	-v ./secrets.json:/home/puppet/work/secrets.json:ro \
	telegram-bot # Run Docker
	rm -rf $2 # Remove temporary data
}

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TMP="./${TIMESTAMP}.tmp" # Output temporary directory
mkdir -p ./$TMP
> ./$TMP/memFree.txt # Free RAM (kB)
> ./$TMP/cpuLoad.txt # Average CPU load (1 minute)
> ./$TMP/cpuTemp.txt # Temperature (mC)

TIMESTEP=30 # Sampling period (seconds)
counter=1
hostnamectl | grep "Operating System:" | awk '{print $3}' > ./$TMP/distroName.txt # Distribution
nproc > ./$TMP/numCores.txt
grep MemTotal: /proc/meminfo | awk '{print $2}' > ./$TMP/memTotal.txt # Total RAM (kB)
echo "Getting data..."
while true; do
	printf "\r\033[KSample #${counter}"
	grep MemFree: /proc/meminfo | awk '{print $2}' >> ./$TMP/memFree.txt
	cat /proc/loadavg | awk '{print $1}' >> ./$TMP/cpuLoad.txt
	cat /sys/class/thermal/thermal_zone11/temp >> ./$TMP/cpuTemp.txt

	counter=$(($counter + 1))
	sleep $TIMESTEP
	trap "sharedata $counter $TMP" SIGINT
done
