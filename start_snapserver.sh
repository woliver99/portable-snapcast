#!/bin/bash

#Check If Running As Root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

cd "$(dirname "$0")" || exit

# Set paths to Docker Compose files
compose_file="docker-compose.yml"
template_file="docker-compose.template.yml"

# Get default network interface
interface=$(ip route | grep default | awk '{print $5}')

# Get IP address and subnet mask
ip_info=$(ip -4 addr show $interface | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+/\d+')
subnet=$(echo $ip_info | cut -d/ -f1)
mask=$(echo $ip_info | cut -d/ -f2)
gateway=$(ip route | grep default | awk '{print $3}')

# Calculate the base IP for the subnet
IFS='.' read -r -a addr_parts <<< "$subnet"
base_ip="${addr_parts[0]}.${addr_parts[1]}.${addr_parts[2]}."

# Run arp-scan on the entire subnet
echo "Scanning the network for used IPs..."
scan_results=$(arp-scan --interface=$interface --localnet)

# Function to check if IP is in the arp-scan results
function ip_in_use() {
    if echo "$scan_results" | grep -q $1; then
        echo "$1 is in use"
        return 0
    else
        echo "$1 is available"
        return 1
    fi
}

# Check IP addresses from .100 to .254
found_ip=""
for (( i=100; i<=254; i++ )); do
    ip_to_check="${base_ip}${i}"
    ip_in_use $ip_to_check
    if [ $? -eq 1 ]; then
        found_ip=$ip_to_check
        break
    fi
done

if [ -z "$found_ip" ]; then
    echo "No available IP addresses found in the range ${base_ip}100 to ${base_ip}254."
    exit 1
fi

# Prepare and run Docker Compose
cp $template_file $compose_file
sed -i "s/{ ip_address }/$found_ip/g" $compose_file
sed -i "s/{ interface }/$interface/g" $compose_file
sed -i "s/{ subnet }/$subnet\/$mask/g" $compose_file
sed -i "s/{ gateway }/$gateway/g" $compose_file
sed -i "s/{ ip_range }/$subnet\/24/g" $compose_file  # Assuming you want to use the whole subnet

./stop_snapserver.sh
docker-compose up -d

echo "Service started on IP: $found_ip"