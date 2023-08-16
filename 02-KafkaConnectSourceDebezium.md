# Kafka Connect Source Debezium

One of the common task when working with kafka is extract data and load them in Kafka. Usually this data is located in databases, [Debezium](https://debezium.io/) allows to extract the data using `change data capture` strategy. In order words, kafka connect debezium extract the data looking at the logs file and stream it to kafka

So, this is the goal:

![Debezium Source Connector](./artifacts/pictures/02-DebeziumSourceConnector.png)


In order to setup this environment follow this steps:

1- `Setup the Development Environment` - Run docker-compose to provision the kafka cluster and Mysql Database
```bash
cd ./artifacts/code/

docker-compose up -d
```

2- `Explore the MySQL Data` - The Mysql database has some demo data explore it
```bash
# Deploys MySQL Client
docker run -it --net=host --rm --name mysqlterm --rm mysql:5.7 sh -c 'exec mysql -h 0.0.0.0 -uroot -pdebezium'
# Select a database
use inventory;
# List all tables in database
show tables;
# Show the customers database data
SELECT * FROM customers;
```

3- `Create Debezium Kafka Connect Task` - This connector task will be responsible to extract all data from `inventory database` and load them into kafka topics

- Create using this configuration [file](./artifacts/code/source/demo-3/mysql-debezium-distributed.properties)
```bash
name=inventory-connector
connector.class=io.debezium.connector.mysql.MySqlConnector
tasks.max=1
# Database Information
database.hostname=mysql 
database.port=3306
database.user=debezium
database.password=dbz
database.server.id=184054

# Topic Prefix for each database loaded
topic.prefix=dbserver1
# database to include
database.include.list=inventory

# Kafka Information
schema.history.internal.kafka.bootstrap.servers=kafka-cluster:9092 
schema.history.internal.kafka.topic=schema-changes.inventory 
```

```bash
curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" localhost:8083/connectors/ -d '{ "name": "inventory-connector", "config": { "connector.class": "io.debezium.connector.mysql.MySqlConnector", "tasks.max": "1", "database.hostname": "mysql", "database.port": "3306", "database.user": "debezium", "database.password": "dbz", "database.server.id": "184054", "topic.prefix": "dbserver1", "database.include.list": "inventory", "schema.history.internal.kafka.bootstrap.servers": "kafka-cluster:9092", "schema.history.internal.kafka.topic": "schemahistory.inventory" } }'
```

4- `Consume the Topic dbserver1.inventory.customers`
```bash
docker run --rm -it --net=host landoop/fast-data-dev:cp3.3.0 bash
apk update && apk add jq

# keep this consumer running to see all events
kafka-avro-console-consumer --topic dbserver1.inventory.customers  --from-beginning --bootstrap-server 127.0.0.1:9092 | jq


# Event from Snapshot - First Run from Kafka Connect
{
  "before": null,
  "after": {
    "dbserver1.inventory.customers.Value": {
      "id": 1003,
      "first_name": "Edward",
      "last_name": "Walker",
      "email": "ed@walker.com"
    }
  },
  "source": {
    "version": "2.3.2.Final",
    "connector": "mysql",
    "name": "dbserver1",
    "ts_ms": 1691690928000,
    "snapshot": {
      "string": "true"
    },
    "db": "inventory",
    "sequence": null,
    "table": {
      "string": "customers"
    },
    "server_id": 0,
    "gtid": null,
    "file": "mysql-bin.000003",
    "pos": 157,
    "row": 0,
    "thread": null,
    "query": null
  },
  "op": "r",
  "ts_ms": {
    "long": 1691690928204
  },
  "transaction": null
}

```

5- `Change data in mysql and look the events comming` - Use the Mysql Client to change data in `inventory.customers` database

```bash
# Deploys MySQL Client
docker run -it --net=host --rm --name mysqlterm --rm mysql:5.7 sh -c 'exec mysql -h 0.0.0.0 -uroot -pdebezium'
# Select a database
use inventory;

# Update Customers
UPDATE customers SET first_name='Anne Marie' WHERE id=1004;

# Delete Customers
DELETE FROM addresses WHERE customer_id=1004;
DELETE FROM customers WHERE id=1004;
```

6- `Results`
```bash
# Event from Update
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


# Event from Delete
{
  "before": {
    "dbserver1.inventory.customers.Value": {
      "id": 1004,
      "first_name": "Anne Marie",
      "last_name": "Kretchmar",
      "email": "annek@noanswer.org"
    }
  },
  "after": null,
  "source": {
    "version": "2.3.2.Final",
    "connector": "mysql",
    "name": "dbserver1",
    "ts_ms": 1691691661000,
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
    "pos": 1163,
    "row": 0,
    "thread": {
      "long": 14
    },
    "query": null
  },
  "op": "d",
  "ts_ms": {
    "long": 1691691661699
  },
  "transaction": null
}
```

## Advanced Operations with Debezium

When extracting data from a database is not unusual to face some challenges like:

- `Sensitive Data that should be masked`
- `Sensitive Data that should be encripted`
- `Data that should not be extracted`
- `Table that should be included after the connector is running`

The good news is that Debezium could help facing these challenges. Look the configurations below:

```bash
name=inventory-connector
connector.class=io.debezium.connector.mysql.MySqlConnector
tasks.max=1
database.hostname=mysql 
database.port=3306
database.user=debezium
database.password=dbz
database.server.id=184054 
topic.prefix=dbserver1
database.include.list=inventory

# Include just a few tables to be extracted
table.include.list=inventory.customers,inventory.addresses
# table.include.list=inventory.customers,inventory.addresses,inventory.products

# Exclude the column `type` from inventory.addresses table
column.exclude.list=inventory.addresses.type
# Mask the column `street` from inventory.addresses table because contains sensitive value
column.mask.with.10.chars=inventory.addresses.street
# Encript the column `email` from inventory.customers table using `SHA-256` algorithm with salt `TLYSk9mjTABD2B`
column.mask.hash.v2.SHA-256.with.salt.TLYSk9mjTABD2B=inventory.customers.email
schema.history.internal.kafka.bootstrap.servers=kafka-cluster:9092 
schema.history.internal.kafka.topic=schema-changes.inventory
schema.history.internal.store.only.captured.tables.ddl=false

snapshot.mode=initial

# Configures Communication with Debezium using Database
signal.enabled.channels=source
# Configures `inventory.debezium_signal` as the database to trigger manual actions on Debezium
signal.data.collection=inventory.debezium_signal
```

Keep in mind that is possible to include a new table to be extracted by the connector, however it is necessary to configure some points:

- [Enabling Sending Signals to Debezium Connector](https://debezium.io/documentation/reference/2.3/configuration/signalling.html) - Allows to communicate with debezium through data tables. For that, set the property `signal.data.collection` with the name of the table used to communication. Ex: inventory.debezium_signal. And follow this steps.

1. Create the Table in mysql
```bash
docker run -it --net=host --rm --name mysqlterm --rm mysql:5.7 sh -c 'exec mysql -h 0.0.0.0 -uroot -pdebezium'

CREATE TABLE inventory.debezium_signal (id VARCHAR(42) PRIMARY KEY, type VARCHAR(32) NOT NULL, data VARCHAR(2048) NULL);

# Allow permission to debezium Select and Insert data on created tables
# debezium is the user used by the connector
GRANT INSERT,SELECT ON inventory.debezium_signal to debezium;

```

2. Create the Connector
```bash
curl -X POST \
  localhost:8083/connectors \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -d '{
  "name": "inventory-connector",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "tasks.max": "1",
    "database.hostname": "mysql",
    "database.port": "3306",
    "database.user": "debezium",
    "database.password": "dbz",
    "database.server.id": "184054",
    "topic.prefix": "dbserver1",
    "database.include.list": "inventory",
    "table.include.list": "inventory.customers,inventory.addresses",
    "column.exclude.list": "inventory.addresses.type",
    "column.mask.with.10.chars": "inventory.addresses.street",
    "column.mask.hash.v2.SHA-256.with.salt.TLYSk9mjTABD2B": "inventory.customers.email",
    "schema.history.internal.kafka.bootstrap.servers": "kafka-cluster:9092",
    "schema.history.internal.kafka.topic": "schema-changes.inventory",
    "schema.history.internal.store.only.captured.tables.ddl": "false",
    "snapshot.mode": "initial",
    "signal.enabled.channels": "source",
    "signal.data.collection": "inventory.debezium_signal"
  }
}'
```

After that, in order to include a new table to be extracted, follow this [steps](https://debezium.io/documentation/reference/2.3/connectors/mysql.html#mysql-capturing-data-from-tables-not-captured-by-the-initial-snapshot-no-schema-change)

1. Stop the connector
```bash
curl -X PUT \
  localhost:8083/connectors/inventory-connector/pause \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json'
```

2. Include the table desired in the `table.include.list` and update the connector
```bash
curl -X PUT \
  localhost:8083/connectors/inventory-connector/config \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -d '{
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "tasks.max": "1",
    "database.hostname": "mysql",
    "database.port": "3306",
    "database.user": "debezium",
    "database.password": "dbz",
    "database.server.id": "184054",
    "topic.prefix": "dbserver1",
    "database.include.list": "inventory",
    "table.include.list": "inventory.customers,inventory.addresses,inventory.products",
    "column.exclude.list": "inventory.addresses.type",
    "column.mask.with.10.chars": "inventory.addresses.street",
    "column.mask.hash.v2.SHA-256.with.salt.TLYSk9mjTABD2B": "inventory.customers.email",
    "schema.history.internal.kafka.bootstrap.servers": "kafka-cluster:9092",
    "schema.history.internal.kafka.topic": "schema-changes.inventory",
    "schema.history.internal.store.only.captured.tables.ddl": "false",
    "snapshot.mode": "initial",
    "signal.enabled.channels": "source",
    "signal.data.collection": "inventory.debezium_signal"
}'
```

3. Restart the Connector
```bash
curl -X PUT \
  localhost:8083/connectors/inventory-connector/resume \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json'
```

4. [Initiate the Incremental Snapshot using Debezium signal](https://debezium.io/documentation/reference/2.3/connectors/mysql.html#mysql-incremental-snapshots)
```bash
docker run -it --net=host --rm --name mysqlterm --rm mysql:5.7 sh -c 'exec mysql -h 0.0.0.0 -uroot -pdebezium'

INSERT INTO inventory.debezium_signal
(id, `type`, `data`)
VALUES('ad-hoc-1', 'execute-snapshot', '{"data-collections": ["inventory.products"], "type":"incremental"}');
```

5. Check the new data being extracted
```bash
docker run --rm -it --net=host landoop/fast-data-dev:cp3.3.0 bash
apk update && apk add jq

# keep this consumer running to see all events
kafka-avro-console-consumer --topic dbserver1.inventory.products  --from-beginning --bootstrap-server 127.0.0.1:9092 | jq
```