#!/bin/bash
cd ~
sudo su
sudo apt update
sudo apt install -y openjdk-8-jdk
java -version
sudo apt update
sudo apt install ruby-full -y
wget https://aws-codedeploy-us-west-2.s3.us-west-2.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto > /tmp/logfile
sudo service codedeploy-agent start
sudo service codedeploy-agent status
sudo apt update
sudo apt install maven -y
cd ~
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb