#!/bin/bash

#Check If Running As Root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

cd "$(dirname "$0")" || exit

docker-compose down