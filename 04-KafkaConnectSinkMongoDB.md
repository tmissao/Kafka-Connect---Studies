# Kafka Connect Sink MongoDB

Once data is in Kafka topic, it is necessary to move it to a new destination, usually to a new database, application or data lake. For this demo, we will move data to an elasticsearch cluster using [Mongo Sink Connector](https://www.confluent.io/hub/mongodb/kafka-connect-mongodb)

So, this is the goal:

![Debezium Source Connector](./artifacts/pictures/04-MongoSinkConnector.png)

In order to setup this environment follow this steps:

1. `Setup the Development Environment` - Run docker-compose to provision the kafka cluster and Mysql Database
```bash
cd ./artifacts/code/

docker-compose up -d kafka-cluster mysql mongo
```

2. `Setup Kafka Debezium Source Connector` - Run all steps from [02-KafkaConnectSourceDebezium](./02-KafkaConnectSourceDebezium.md) 

3. `Create Mongo Kafka Connect Sink Task` - This connector will consume all data from `dbserver1.inventory.customers`, `dbserver1.inventory.products` and `dbserver1.inventory.addresses` topics sending them to Mongo

Here there some important steps to highlight, debezium message extract contains a lot of information since it is a log, and for mongo data it is necessary just the field `after` in the message produced from debezium. So we will configure the Mongo Connector to use the transformation [New Record State Extraction](https://debezium.io/documentation/reference/2.3/transformations/event-flattening.html). Which will modify the message dumped into mongo to contain just the value inside `after` field. Furthermore, mongo requires two aditional fields in order to know in which database and collection to persist the data. So, we also customize the `ExtractNewRecordState` to include de database and table information into the record value through the command `"transforms.unwrap.add.fields":"table,db"`

```bash
# Prior New Record State Extraction
{
  "before": {
    "dbserver1.inventory.customers.Value": {
      "id": 1004,
      "first_name": "Anne",
      "last_name": "Kretchmar",
      "email": "annek@noanswer.org"
    }
  },
  "after": {
    "dbserver1.inventory.customers.Value": {
      "id": 1004,
      "first_name": "Anne Marie",
      "last_name": "Kretchmar",
      "email": "annek@noanswer.org"
    }
  },
  "source": {
    "version": "2.3.2.Final",
    "connector": "mysql",
    "name": "dbserver1",
    "ts_ms": 1691691590000,
    "snapshot": {
      "string": "false"
    },
    "db": "inventory",
    "sequence": null,
    "table": {
      "string": "customers"
    },
    "server_id": 223344,
    "gtid": null,
    "file": "mysql-bin.000003",
    "pos": 401,
    "row": 0,
    "thread": {
      "long": 14
    },
    "query": null
  },
  "op": "u",
  "ts_ms": {
    "long": 1691691590824
  },
  "transaction": null
}

# After New Record State Extraction
{
    "id": 1004,
    "first_name": "Anne Marie",
    "last_name": "Kretchmar",
    "email": "annek@noanswer.org",
    "__deleted": "false",
    "__db" : "inventory",
    "__table": "customer"
}
```

Also, another transformation is required, but this time in the key field. Mongo requires a strategy in order to generate the _id field, So using the transformation [renameField](https://docs.confluent.io/platform/current/connect/transforms/replacefield.html#rename-a-field) it converts the field `id` in the key section of the record to _id

```bash
# Key Prior Extract Field Transformation
{
    "id": 1004
}

# Key After Extract Field Transformation
{
    "_id": 1004
}
```

Finally, create the connector using this configuration [file](./artifacts/code/sink/demo-mongo/sink-mongo-distributed.properties)

```bash
# Basic configuration for our connector
name=sink-mongo-customer-distributed
connector.class=com.mongodb.kafka.connect.MongoSinkConnector
# We could parallel this task to increase performance
tasks.max=1

# Topic to be consumed
topics=dbserver1.inventory.customers,dbserver1.inventory.products,dbserver1.inventory.addresses
# topics.regex=dbserver1\\.\\w+\\.\\w+$

# Transformations
transforms=unwrap,renameField
transforms.unwrap.type=io.debezium.transforms.ExtractNewRecordState
# Include debezium informations about table and database that will be used by
# Mongo connector to decide where to save the data
transforms.unwrap.add.fields=table,db
transforms.unwrap.delete.handling.mode=rewrite
# Mongo Connector needs to generate a _id, so in this case we are renaming
# the id to _id in order to mongo use it
transforms.renameField.type=org.apache.kafka.connect.transforms.ReplaceField$Key
transforms.renameField.renames=id:_id

# Mongo configuration
connection.uri=mongodb://root:mongo@mongo:27017
database=default
collection=default
# Configures mongo to router data based on record data information
namespace.mapper=com.mongodb.kafka.connect.sink.namespace.mapping.FieldPathNamespaceMapper
# Configures mongo to decide the database where data will be saved based on __db value of the record
namespace.mapper.value.database.field=__db
# Configures mongo to decide the database where data will be saved based on __table value of the record
namespace.mapper.value.collection.field=__table
# Configures mongo to use the _id base on the _id of the record key
document.id.strategy=com.mongodb.kafka.connect.sink.processor.id.strategy.ProvidedInKeyStrategy
# Configures mongo to realize a post processor of the message using the BlockListValue stragegy
post.processor.chain=com.mongodb.kafka.connect.sink.processor.BlockListValueProjector
value.projection.type=BlockList
# Prevents the values __db and __table from mongo to be saved on collection 
value.projection.list=__db,__table

```

```bash
curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" localhost:8083/connectors/ -d '{
   "name":"mongo-connector",
   "config":{
      "connector.class":"com.mongodb.kafka.connect.MongoSinkConnector",
      "tasks.max":"1",
      "topics":"dbserver1.inventory.customers,dbserver1.inventory.products,dbserver1.inventory.addresses",
      "transforms":"unwrap,renameField",
      "transforms.unwrap.type":"io.debezium.transforms.ExtractNewRecordState",
      "transforms.unwrap.add.fields":"table,db",
      "transforms.unwrap.delete.handling.mode":"rewrite",
      "transforms.renameField.type":"org.apache.kafka.connect.transforms.ReplaceField$Key",
      "transforms.renameField.renames":"id:_id",
      "connection.uri":"mongodb://root:mongo@mongo:27017",
      "database":"default-database",
      "collection":"default-collection",
      "namespace.mapper":"com.mongodb.kafka.connect.sink.namespace.mapping.FieldPathNamespaceMapper",
      "namespace.mapper.value.database.field":"__db",
      "namespace.mapper.value.collection.field":"__table",
      "document.id.strategy":"com.mongodb.kafka.connect.sink.processor.id.strategy.ProvidedInKeyStrategy",
      "post.processor.chain":"com.mongodb.kafka.connect.sink.processor.BlockListValueProjector",
      "value.projection.type":"BlockList",
      "value.projection.list":"__db,__table"
   }
}'
```

4. `Check the data on Mongo` - You can using Mongosh to connect into mongo and visualize the data

```bash
docker run --rm -it --net=host mongodb/mongodb-community-server mongosh mongodb://root:mongo@127.0.0.1:27017
use inventory
db.customers.find({})
```