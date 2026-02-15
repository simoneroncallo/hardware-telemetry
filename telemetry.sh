#!/bin/bash
###############################################################################
# Name: telemetry.sh
# Description:
# 	This script monitors hardware metrics, including CPU load, temperature,
#  	RAM, and SWAP (ZRAM) usage, with optional support for NVIDIA GPUs 
#	usage. Data is temporarily stored and shared privately through a 
#	Dockerized Telegram API call written in Python.
#
# Usage: 
#	./telemetry.sh [OPTIONS]
# 	-t, --timestep <seconds>	Set the timestep (default: 30 seconds)
# 	--nogpu                 	Disable GPU monitoring
#
# Dependencies:
#	bash, grep, awk
# 	nvidia-smi (for NVIDIA GPUs usage)
#	Docker (rootless) or Podman
#
# Configuration:
# 	.config 	Hardware specifications
# 			Line 1: CPU thermal zone index number
#	secrets.json 	Telegram API and Chat ID
#			Template: {	
#				    "chatID": "-12345",
#				    "token": "12345:ABCDE" 	   
#				  }
#
# Author: Simone Roncallo
# Date:   2025-12-26
###############################################################################

set -e

# Get options
OPTS=$(getopt -o t: --long timestep:,nogpu -n 'telemetry.sh' -- "$@") 
if [ $? -ne 0 ]; then
  echo "Error"
  exit 1
fi

eval set -- "$OPTS"

timestep=30 # Sampling period (seconds)
readgpu=true # Get GPU usage with nvidia-smi
while true; do
  case "$1" in
    --nogpu)
      readgpu=false
      shift 1
      ;;
    -t | --timestep)
      timestep="$2"
      shift 2
      ;;
    --) # End sequence
      shift
      break
      ;;
    *) # Match errors
      echo "Error"
      exit 1
      ;;
  esac
done

function sharedata() {
	# Send data using Telegram API (running in Docker)
	printf "\r\033[KSample #$1 -> Interrupt\n"
	echo "Opening channel..."
	docker run --rm --cap-drop=ALL --security-opt=no-new-privileges:true \
	--memory=1024m --cpus=2 \
	--user=puppet -v $2:/home/puppet/work/data:ro \
	-v ./secrets.json:/home/puppet/work/secrets.json:ro \
	telegram-bot:latest # Run Docker
	rm -rf $2 # Remove temporary data
	echo "Completed"
}

mapfile -t config < .config # Read configuration file
tzone=${config[0]} # CPU thermal zone number

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TMP="./${TIMESTAMP}.tmp" # Output temporary directory
mkdir -p ./$TMP
> ./$TMP/memFree.txt # Free RAM (kB)
> ./$TMP/swpFree.txt # Free SWAP/ZRAM (kB)
> ./$TMP/cpuLoad.txt # Average CPU load (1 minute)
> ./$TMP/cpuTemp.txt # Temperature (mC)
if $readgpu; then
	> ./$TMP/gpuUsed.txt # Used VRAM (MB)
	> ./$TMP/gpuTotal.txt # Total VRAM (MB)
fi

counter=1

hostnamectl | grep "Operating System:" | awk '{print $3, $4, $5}' > ./$TMP/distroName.txt
hostnamectl | grep "Static hostname:" | awk '{print $3}' > ./$TMP/hostName.txt
	
nproc > ./$TMP/numCores.txt
grep MemTotal: /proc/meminfo | awk '{print $2}' > ./$TMP/memTotal.txt
grep SwapTotal: /proc/meminfo | awk '{print $2}' > ./$TMP/swpTotal.txt

while true; do
	printf "\r\033[KSample #${counter}"
	
	grep MemFree: /proc/meminfo | awk '{print $2}' >> ./$TMP/memFree.txt
	grep SwapFree: /proc/meminfo | awk '{print $2}' >> ./$TMP/swpFree.txt
	cat /proc/loadavg | awk '{print $1}' >> ./$TMP/cpuLoad.txt
	cat /sys/class/thermal/thermal_zone${tzone}/temp >> ./$TMP/cpuTemp.txt
	if $readgpu; then # Read NVIDIA GPU metrics
		nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits >> ./$TMP/gpuUsed.txt
		nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits >> ./$TMP/gpuTotal.txt
	fi

	counter=$(($counter + 1))
	sleep $timestep
	trap "sharedata $counter $TMP" SIGINT
done
