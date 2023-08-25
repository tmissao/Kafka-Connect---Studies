# Kafka Connect Sink JDBC

Once data is in Kafka topic, it is necessary to move it to a new destination, usually to a new database, application or data lake. For this demo, we will move data to a postgres database cluster using [JDBC Sink Connector](https://www.confluent.io/hub/confluentinc/kafka-connect-jdbc)

So, this is the goal:

![JDBC Sink Connector](./artifacts/pictures/05-PostgresSQLSinkConnector.png)

In order to setup this environment follow this steps:

1. `Setup the Development Environment` - Run docker-compose to provision the kafka cluster and Mysql Database
```bash
cd ./artifacts/code/

docker-compose up --force-recreate -d kafka-cluster mysql postgres
```

2. `Setup Kafka Debezium Source Connector` - Run all steps from [02-KafkaConnectSourceDebezium](./02-KafkaConnectSourceDebezium.md) 

3. `Create JDBC Kafka Connect Sink Task` - This connector will consume all data from `dbserver1.inventory.customers`, `dbserver1.inventory.products` and `dbserver1.inventory.addresses` topics sending them to Postgres

There are some important steps to highlight, debezium message extracted contains a lot of information since it is a log, and for postgres data it is necessary just the field `after` in the message produced from debezium. 

So we will configure the JDBC Connector to use the transformation [New Record State Extraction](https://debezium.io/documentation/reference/2.3/transformations/event-flattening.html). Which will modify the message dumped into Postgres to contain just the value inside `after` field.

Furthermore, Postgres Connector will use the topic name to create the table and to avoid errors it is necessary to format the topic name in the record before the connector use it to create the table. So, the [RegexRouter](https://docs.confluent.io/platform/current/connect/transforms/regexrouter.html#regexrouter) transformation is use in order to extract just the table name. 

Also, the [ReplaceField](https://docs.confluent.io/platform/current/connect/transforms/replacefield.html) and [Cast](https://docs.confluent.io/platform/current/connect/transforms/cast.html#cast) transformations are use to modified the field `__deleted` include in the debezium transformation to `deleted` and also changes its type from string to boolean in order to not waste space in the database.

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
    "email": "annek@noanswer.org"
    "__deleted": "false"
}

# After ReplaceField Transformation
{
    "id": 1004,
    "first_name": "Anne Marie",
    "last_name": "Kretchmar",
    "email": "annek@noanswer.org"
    "deleted": "false"
}

# After Cast Transformation
{
    "id": 1004,
    "first_name": "Anne Marie",
    "last_name": "Kretchmar",
    "email": "annek@noanswer.org"
    "deleted": false
}
```

Thus, create the connector using this configuration [file](./artifacts/code/sink/demo-postgres/sink-postgres-distributed.properties)

```bash
# Basic configuration for our connector
name=sink-postgres-customer-distributed
connector.class=io.confluent.connect.jdbc.JdbcSinkConnector
# We could parallel this task to increase performance
tasks.max=1

# Topic to be consumed
topics=dbserver1.inventory.customers,dbserver1.inventory.products,dbserver1.inventory.addresses

# Transformations
transforms=unwrap,changeTopicName,replaceField,castDelete
# Simplify Debezium Record extracting just the after field
transforms.unwrap.type=io.debezium.transforms.ExtractNewRecordState
# Include the delete information into record's value
transforms.unwrap.delete.handling.mode=rewrite
# Modifies Record's Topic name getting just the string value after the last dot(.)
# In order to mysql use it to create the table
transforms.changeTopicName.type=org.apache.kafka.connect.transforms.RegexRouter
transforms.changeTopicName.regex=dbserver1.inventory.(.*)
transforms.changeTopicName.replacement=$1
# Modify the record value field from __deleted to delete
transforms.replaceField.type=org.apache.kafka.connect.transforms.ReplaceField$Value
transforms.replaceField.renames=__deleted:deleted
# Modify the record value type from string to boolean
transforms.castDelete.type=org.apache.kafka.connect.transforms.Cast$Value
transforms.castDelete.spec=deleted:boolean

# Postgres configuration
connection.url=jdbc:postgresql://postgres:5432/postgres
connection.user=postgres
connection.password=postgres
dialect.name=PostgreSqlDatabaseDialect
# Perform Upsert to add records into the table
insert.mode=upsert
# Use the record's key value to create primary key
pk.mode=record_key
pk.fields=id
# Auto Create Table if not exists
auto.create=true
# Apply Alter table if a new column is detected
auto.evolve=true
table.name.format=${topic}

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


4. `Check the data on Postgres` - You can using psql to connect into postgres and visualize the data

```bash
docker run --rm -it --net=host postgres psql postgresql://postgres:postgres@127.0.0.1:5432/postgresdb
select * from customers;
```