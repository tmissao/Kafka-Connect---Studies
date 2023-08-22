# Kafka Connect - Studies

This project intends to summarize all the knowledge earned during my studies of Kafka Connect

It can be divided into the following sections:

- [Introduction](./00-Introduction.md)
- [Kafka Connect Source](./01-KafkaConnectSource.md)
- [Extracting data from Database with Debezium](./02-KafkaConnectSourceDebezium.md)
- [Moving data to ElasticSearch](./03-KafkaConnectSinkElasticsearch.md)


## References

- [Kafka Connect Course](https://www.udemy.com/course/kafka-connect)
- [Confluent Connectors](https://www.confluent.io/hub/)
- [Configuring Connectors](https://kafka.apache.org/documentation.html#connect_configuring)
- [Landoop Include Connectors](https://github.com/lensesio/fast-data-dev#enable-additional-connectors)
- [Kafka Converters and Serialization](https://www.confluent.io/blog/kafka-connect-deep-dive-converters-serialization-explained/#json-schemas)
- [Kafka Transformation](https://www.confluent.io/blog/kafka-connect-single-message-transformation-tutorial-with-examples/)



kafka-console-producer --broker-list localhost:9092 --topic dbserver1-signal --property parse.key=true --property key.separator=@
dbserver1@{"type":"execute-snapshot","data": {"data-collections": ["inventory.products"], "type": "incremental"}}