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
## References
---

- [Azure Eventhub Support Kafka Connect](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-kafka-connect-debezium)
- [Azure Eventhub and Kafka Connect](https://hevodata.com/learn/kafka-to-azure/)