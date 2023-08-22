# Kafka Connect on Azure Eventhub

In this case, we're going to use an [Azure Event Hub](https://azure.microsoft.com/en-us/products/event-hubs) as a kafka broker, in order to connect Kafka-Connect.

So, follow the steps below:

1. [Create an Azure Eventhub](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-create)
2. Download Kafka Connect Binary
```bash
cd artifacts/code
wget https://downloads.apache.org/kafka/3.5.1/kafka_2.13-3.5.1.tgz
tar -zxf kafka_2.13-3.5.1.tgz
mv kafka_2.13-3.5.1 kafka
rm -rf kafka_2.13-3.5.1.tgz
```
3. Edit file [connected-distributed.properties](./artifacts/code/eventhub/connected-distributed.properties) replacing the values between `{ xxx }` with the appropriated values, remembering that `KAFKA.DIRECTORY` will be the path where kafka was extracted
```bash
# eventhub hub address
bootstrap.servers=missaokafkaconnect.servicebus.windows.net:9093
group.id=connect-cluster-group

# connect internal topic names, auto-created if not exists
config.storage.topic=connect-cluster-configs
offset.storage.topic=connect-cluster-offsets
status.storage.topic=connect-cluster-status

# internal topic replication factors - auto 3x replication in Azure Storage
config.storage.replication.factor=1
offset.storage.replication.factor=1
status.storage.replication.factor=1

rest.advertised.host.name=connect
offset.flush.interval.ms=10000

key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
internal.key.converter=org.apache.kafka.connect.json.JsonConverter
internal.value.converter=org.apache.kafka.connect.json.JsonConverter

internal.key.converter.schemas.enable=false
internal.value.converter.schemas.enable=false

# required EH Kafka security settings
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="$ConnectionString" password="Endpoint=sb://missaokafkaconnect.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=GgdSdFWxDHrDnHLv1Z61ko1PDqATdrpkX+AEhD995cA=";

producer.security.protocol=SASL_SSL
producer.sasl.mechanism=PLAIN
producer.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="$ConnectionString" password="Endpoint=sb://missaokafkaconnect.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=GgdSdFWxDHrDnHLv1Z61ko1PDqATdrpkX+AEhD995cA=";

consumer.security.protocol=SASL_SSL
consumer.sasl.mechanism=PLAIN
consumer.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="$ConnectionString" password="Endpoint=sb://missaokafkaconnect.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=GgdSdFWxDHrDnHLv1Z61ko1PDqATdrpkX+AEhD995cA=";

# path to the libs directory within the Kafka release, use pwd command to get it
plugin.path=/home/tmissao/git/kafka-connect-studies/artifacts/code/kafka/libs 

```

4. Move the modified [connected-distributed.properties](./artifacts/code/eventhub/connected-distributed.properties) to Kafka Config directory replacing the file there.
```bash
cd artifacts/code
rm -rf kafka/config/connected-distributed.properties
```

5. Move the connector libs to kafka/libs directory
```bash
cd artifacts/code
cp -r connectors/* kafka/libs
```

6. Start Kafka Connect
```bash
cd artifacts/code/kafka
./bin/connect-distributed.sh ./config/connect-distributed.properties
```

7. Check Kafka Connect Cluster
```bash
curl localhost:8083
# Response
# {"version":"3.5.1","commit":"2c6fb6c54472e90a","kafka_cluster_id":"misXXXXXnect.servicebus.windows.net"}
```

## Testing with FileStreamConnector

To test the Kafka Connect integration with Azure Eventhub, lets deploy a FileStreamSourceConnector to extract the [input.txt](./artifacts/code/eventhub/input.txt) and send to Azure Eventhub under the topic `demo-input-file`

Thus, execute the following commands:

1. Get your path for [input.txt](./artifacts/code/eventhub/input.txt)
```bash
cd artifacts/code/eventhub
pwd
# Mine returned 
# /home/tmissao/git/kafka-connect-studies/artifacts/code/eventhub
# So file is /home/tmissao/git/kafka-connect-studies/artifacts/code/eventhub/input.txt
```

2. Create the FileStreamSourceConnector
```bash
curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" localhost:8083/connectors/ -d '{"name": "file-source","config": {"connector.class":"org.apache.kafka.connect.file.FileStreamSourceConnector","tasks.max":"1","topic":"demo-input-file","file": "/home/tmissao/git/kafka-connect-studies/artifacts/code/eventhub/input.txt"}}'
```

3. Verify Connector Status
```bash
curl -s http://localhost:8083/connectors/file-source/status
```

4. Create a FileStreamSinkConnector
```bash
curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" localhost:8083/connectors/ -d '{"name": "file-sink","config": {"connector.class":"org.apache.kafka.connect.file.FileStreamSinkConnector","tasks.max":"1","topics":"demo-input-file","file": "/home/tmissao/git/kafka-connect-studies/artifacts/code/eventhub/output.txt"}}'
```

5. Verify Connector Status
```bash
curl -s http://localhost:8083/connectors/file-sink/status
```

6. Check the Output.txt file generate at the same directory of your input.txt file
```bash
cat /home/tmissao/git/kafka-connect-studies/artifacts/code/eventhub/output.txt
```

## Testing with Debezium and ElasticSearch

In order to test this integration in a more realistic world, we will test with debezium plugin, which will extract data from a Mysql Database and send it to a elasticsearch database

> Beware!! At least JAVA 11 is required for Debezium work! 

So, execute the follow steps:

1. Start Mysql and Elasticsearch databases
```bash
cd artifacts/code
docker-compose up -d mysql elasticsearch
```

2. Create Debezium Connector to extract data from MySql database
```bash
curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" localhost:8083/connectors/ -d @- << EOF
{
   "name":"inventory-connector-test-blob",
   "config":{
      "connector.class":"io.debezium.connector.mysql.MySqlConnector",
      "tasks.max":"1",
      "database.hostname":"127.0.0.1",
      "database.port":"3306",
      "database.user":"debezium",
      "database.password":"dbz",
      "database.server.id":"184065",
      "topic.prefix":"dbserver2",
      "database.include.list":"inventory",
      "retries":"10",
      "errors.retry.timeout":"600000",
      "errors.retry.delay.max.ms":"30000",
      "errors.log.enable":"true",
      "errors.log.include.messages":"true",
      "errors.tolerance":"all",
      "topic.creation.default.replication.factor":"1",
      "topic.creation.default.partitions":"1",
      "schema.history.internal":"io.debezium.storage.azure.blob.history.AzureBlobSchemaHistory",
      "schema.history.internal.azure.storage.account.connectionstring":"DefaultEndpointsProtocol=https;AccountName=missaokafkaconnect;AccountKey=nptEVdFwO7GjsG9vK50DSCdT5yIqh1Slaif9xpjWJkK2Tk7hrFxWWH3eSUlJxwWuf95JG3HgXr1B+AStxyOffw==;EndpointSuffix=core.windows.net",
      "schema.history.internal.azure.storage.account.container.name":"debezium",
      "schema.history.internal.azure.storage.blob.name":"schemahistory"
   }
}
EOF
```

3. Verify Connector Status
```bash
curl -s http://localhost:8083/connectors/inventory-connector/status
```

4. Create an Elasticsearch Sink Connector
```bash
curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" localhost:8083/connectors/ -d @- << EOF
{
   "name":"inventory-connector",
   "config":{
      "connector.class":"io.debezium.connector.mysql.MySqlConnector",
      "tasks.max":"1",
      "database.hostname":"localhost",
      "database.port":"3306",
      "database.user":"debezium",
      "database.password":"dbz",
      "database.server.id":"184054",
      "topic.prefix":"dbserver1",
      "database.include.list":"inventory",
      "schema.history.internal.kafka.bootstrap.servers":"missaokafkaconnect.servicebus.windows.net:9093",
      "schema.history.internal.kafka.topic":"schemahistory.inventory",
      "schema.history.consumer.security.protocol": "SASL_SSL",		
	  "schema.history.consumer.sasl.mechanism": "PLAIN",
	  "schema.history.consumer.sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"$ConnectionString\" password=\"Endpoint=sb://missaokafkaconnect.servicebus.windows.net/;SharedAccessKeyName=Manage;SharedAccessKey=GgdSdFWxDHrDnHLv1Z61ko1PDqATdrpkX+AEhD995cA=\";",		
	  "schema.history.producer.security.protocol": "SASL_SSL",		
	  "schema.history.producer.sasl.mechanism": "PLAIN",
	  "schema.history.producer.sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"$ConnectionString\" password=\"Endpoint=sb://missaokafkaconnect.servicebus.windows.net/;SharedAccessKeyName=Manage;SharedAccessKey=GgdSdFWxDHrDnHLv1Z61ko1PDqATdrpkX+AEhD995cA=\";"
   }
}
EOF
```

## References
---

- [Azure Eventhub Support Kafka Connect](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-kafka-connect-debezium)