#!/bin/bash -v
echo "userdata-start"
sudo su -
yum update -y
yum groupinstall "Development Tools" -y
yum install -y yum-utils device-mapper-persistent-data lvm2 wget python3 wget ruby
pip3 install boto3 --user
yum remove docker docker-common docker-selinux docker-engine-selinux docker-engine docker-ce -y
yum install -y yum-utils device-mapper-persistent-data lvm2
yum install docker -y
yum install systemd -y
service docker start
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
chmod +x ./install
./install auto
service codedeploy-agent start
echo "End of UserData"
echo "End of UserData"

