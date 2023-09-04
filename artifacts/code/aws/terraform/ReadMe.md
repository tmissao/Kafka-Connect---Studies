# Provision AWS Kafka Cluster MSK

# kafka.properties
allow.everyone.if.no.acl.found = true

# terraform variables
kafka.broker_node_group_info.connectivity_info.public_access.type = "DISABLED"

docker container run --rm -it -v $(pwd)/manager.properties:/bitnami/kafka/config/manager.properties -v $(pwd)/connect.properties:/bitnami/kafka/config/connect.properties -v $(pwd)/monitoring.properties:/bitnami/kafka/config/monitoring.properties bitnami/kafka:2.8.1 bash


kafka-topics.sh --bootstrap-server b-2-public.kafkademo.057rm2.c3.kafka.us-east-1.amazonaws.com:9196,b-1-public.kafkademo.057rm2.c3.kafka.us-east-1.amazonaws.com:9196,b-3-public.kafkademo.057rm2.c3.kafka.us-east-1.amazonaws.com:9196 --list --command-config /bitnami/kafka/config/manager.properties


kafka-console-consumer.sh --bootstrap-server b-2-public.kafkademo.057rm2.c3.kafka.us-east-1.amazonaws.com:9196,b-1-public.kafkademo.057rm2.c3.kafka.us-east-1.amazonaws.com:9196,b-3-public.kafkademo.057rm2.c3.kafka.us-east-1.amazonaws.com:9196 --topic test-topic-auth --consumer.config /bitnami/kafka/config/connect.properties --from-beginning


kafka-console-producer.sh --topic test-topic-auth-2 --broker-list b-2-public.kafkademo.057rm2.c3.kafka.us-east-1.amazonaws.com:9196,b-1-public.kafkademo.057rm2.c3.kafka.us-east-1.amazonaws.com:9196,b-3-public.kafkademo.057rm2.c3.kafka.us-east-1.amazonaws.com:9196 --producer.config /bitnami/kafka/config/connect.properties

kafka-console-producer.sh --topic test-topic-auth-2 --broker-list b-2-public.kafkademo.057rm2.c3.kafka.us-east-1.amazonaws.com:9196,b-1-public.kafkademo.057rm2.c3.kafka.us-east-1.amazonaws.com:9196,b-3-public.kafkademo.057rm2.c3.kafka.us-east-1.amazonaws.com:9196 --producer.config /bitnami/kafka/config/monitoring.properties