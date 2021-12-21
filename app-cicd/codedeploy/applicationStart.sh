#!/bin/bash
sleep 4m
cd /home/ubuntu/webapp/
sudo su
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/home/ubuntu/webapp/cloudwatch-config.json -s
cd logs
touch csye6225.log
sudo chmod 777 csye6225.log
cd ..
sudo mvn clean
sudo mvn clean install
#sudo java -jar target/*.jar . &
(sudo java -jar target/*.jar . &) > logs/csye6225.log 2>&1
sleep 1m