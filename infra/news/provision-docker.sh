#!/bin/bash -e
if hash docker 2>/dev/null; then
  echo "Docker aleady installed"
else
  sudo apt-get update -y
  sudo apt install docker.io -y  
fi
