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
echo "#                             Running Kafka UI                                          #"
echo "#########################################################################################"

echo "${DOCKER_COMPOSE_CONF}" | base64 --decode > ./docker-compose.yml
docker-compose -p demo up -d

echo "#########################################################################################"
echo "#                             Running Kafka Client                                      #"
echo "#########################################################################################"

echo "${KAFKA_CLIENT_PROPERTIES}" | base64 --decode > ./manager.properties

echo "#########################################################################################"
echo "#                                 Setting ACLs                                          #"
echo "#########################################################################################"

docker container run -v $(pwd)/manager.properties:/bitnami/kafka/config/manager.properties bitnami/kafka:2.8.1 bash -c "kafka-acls.sh --bootstrap-server ${BOOTSTRAP_BROKERS} --add --allow-principal User:${KAFKA_MANAGER_USER} --operation All --allow-host '*' --cluster --topic '*' --group '*' --command-config /bitnami/kafka/config/manager.properties"
docker container run -v $(pwd)/manager.properties:/bitnami/kafka/config/manager.properties bitnami/kafka:2.8.1 bash -c "kafka-acls.sh --bootstrap-server ${BOOTSTRAP_BROKERS} --add --allow-principal User:${KAFKA_CONNECT_USER} --consumer --producer --allow-host '*' --topic '*' --group '*' --command-config /bitnami/kafka/config/manager.properties"
docker container run -v $(pwd)/manager.properties:/bitnami/kafka/config/manager.properties bitnami/kafka:2.8.1 bash -c "kafka-acls.sh --bootstrap-server ${BOOTSTRAP_BROKERS} --add --allow-principal User:${KAFKA_MONITORING_USER} --consumer --allow-host '*' --topic '*' --group '*' --command-config /bitnami/kafka/config/manager.properties"