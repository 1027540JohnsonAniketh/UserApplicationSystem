#!/bin/bash
sleep 20s
sudo su
cd /home/ubuntu/webapp/
TENOVAR=$(lsof -i tcp:8080 | grep "java" | awk '{print $2}')

if [ -z "$TENOVAR" ]
then
    echo "\$TENOVAR is empty"
else
    kill -9 $TENOVAR
fi