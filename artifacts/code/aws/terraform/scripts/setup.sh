#!/bin/bash

set -x
echo "#########################################################################################"
echo "#                       Starting Installing Docker                                      #"
echo "#########################################################################################"
yum install docker -y
usermod -a -G docker ec2-user

wget https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) 
mv docker-compose-$(uname -s)-$(uname -m) /usr/local/bin/docker-compose
chmod -v +x /usr/local/bin/docker-compose

systemctl enable docker.service
systemctl start docker.service

echo "#########################################################################################"
echo "#                           Installing Kafka Client                                     #"
echo "#########################################################################################"
yum -y install java-11
wget https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_2.13-${KAFKA_VERSION}.tgz
tar -xzf kafka_2.13-${KAFKA_VERSION}.tgz
mv kafka_2.13-${KAFKA_VERSION} kafka
cd kafka/libs
wget https://github.com/aws/aws-msk-iam-auth/releases/download/v1.1.9/aws-msk-iam-auth-1.1.9-all.jar 
cd ../bin
echo "${KAFKA_CLIENT_PROPERTIES}" | base64 --decode > ./client.properties

echo "#########################################################################################"
echo "#                             Running Kafka Client                                      #"
echo "#########################################################################################"

echo "${KAFKA_CLIENT_PROPERTIES}" | base64 --decode > ./client.properties

echo "#########################################################################################"
echo "#                                 Setting ACLs                                          #"
echo "#########################################################################################"

./kafka-acls.sh --bootstrap-server ${BOOTSTRAP_BROKERS} --add \
  --allow-principal User:${KAFKA_MANAGER_USER} --operation All --allow-host '*' \
  --cluster --topic '*' --group '*' --command-config ./client.properties

./kafka-acls.sh --bootstrap-server ${BOOTSTRAP_BROKERS} --add \
  --allow-principal User:${KAFKA_CONNECT_USER} --consumer --producer --allow-host '*' \
  --topic '*' --group '*' --command-config ./client.properties

./kafka-acls.sh --bootstrap-server ${BOOTSTRAP_BROKERS} --add \
  --allow-principal User:${KAFKA_MONITORING_USER} --consumer --allow-host '*' \
  --topic '*' --group '*' --command-config ./client.properties
