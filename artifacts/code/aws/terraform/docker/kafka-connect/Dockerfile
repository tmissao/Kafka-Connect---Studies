FROM confluentinc/cp-kafka-connect:7.5.0 as cp
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-s3:10.5.4
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-elasticsearch:14.0.9
RUN confluent-hub install --no-prompt mongodb/kafka-connect-mongodb:1.11.0
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:10.7.4

FROM quay.io/strimzi/kafka:0.36.1-kafka-3.4.0 
USER root:root

ARG PLUGINS_PATH=/opt/kafka/plugins

RUN mkdir -p ${PLUGINS_PATH}/kafka-connect-s3
COPY --from=cp /usr/share/confluent-hub-components/confluentinc-kafka-connect-s3/lib /opt/kafka/plugins/kafka-connect-s3/

RUN mkdir -p ${PLUGINS_PATH}/kafka-connect-elasticsearch
COPY --from=cp /usr/share/confluent-hub-components/confluentinc-kafka-connect-elasticsearch/lib /opt/kafka/plugins/kafka-connect-elasticsearch/

RUN mkdir -p ${PLUGINS_PATH}/kafka-connect-mongodb
COPY --from=cp /usr/share/confluent-hub-components/mongodb-kafka-connect-mongodb/lib /opt/kafka/plugins/kafka-connect-mongodb/

RUN mkdir -p ${PLUGINS_PATH}/kafka-connect-jdbc
COPY --from=cp /usr/share/confluent-hub-components/confluentinc-kafka-connect-jdbc/lib /opt/kafka/plugins/kafka-connect-jdbc/


RUN mkdir {PLUGINS_PATH}/

RUN mkdir ${PLUGINS_PATH}/connect-file && \
    curl -s -o ${PLUGINS_PATH}/connect-file/connect-file-3.4.0.jar https://repo1.maven.org/maven2/org/apache/kafka/connect-file/3.4.0/connect-file-3.4.0.jar

RUN curl -s -o /tmp/debezium-connector-mysql.tar.gz https://repo1.maven.org/maven2/io/debezium/debezium-connector-mysql/2.3.3.Final/debezium-connector-mysql-2.3.3.Final-plugin.tar.gz && \
        tar -zxf /tmp/debezium-connector-mysql.tar.gz -C ${PLUGINS_PATH} && \
        rm /tmp/debezium-connector-mysql.tar.gz

RUN curl -s -o /tmp/debezium-connector-postgres.tar.gz https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/2.3.3.Final/debezium-connector-postgres-2.3.3.Final-plugin.tar.gz && \
        tar -zxf /tmp/debezium-connector-postgres.tar.gz -C ${PLUGINS_PATH} && \
        rm /tmp/debezium-connector-postgres.tar.gz

RUN curl -s -o /tmp/debezium-connector-sqlserver.tar.gz https://repo1.maven.org/maven2/io/debezium/debezium-connector-sqlserver/2.3.3.Final/debezium-connector-sqlserver-2.3.3.Final-plugin.tar.gz && \
        tar -zxf /tmp/debezium-connector-sqlserver.tar.gz -C ${PLUGINS_PATH} && \
        rm /tmp/debezium-connector-sqlserver.tar.gz

RUN curl -s -o /tmp/debezium-connector-mongodb.tar.gz https://repo1.maven.org/maven2/io/debezium/debezium-connector-mongodb/2.3.3.Final/debezium-connector-mongodb-2.3.3.Final-plugin.tar.gz && \
        tar -zxf /tmp/debezium-connector-mongodb.tar.gz -C ${PLUGINS_PATH} && \
        rm /tmp/debezium-connector-mongodb.tar.gz

RUN curl -s -o /tmp/apicurio-registry-distro-connect-converter.tar.gz https://repo1.maven.org/maven2/io/apicurio/apicurio-registry-distro-connect-converter/2.4.7.Final/apicurio-registry-distro-connect-converter-2.4.7.Final.tar.gz && \
        mkdir ${PLUGINS_PATH}/apicurio-registry-distro-connect-converter && \
        tar -zxf /tmp/apicurio-registry-distro-connect-converter.tar.gz -C ${PLUGINS_PATH}/apicurio-registry-distro-connect-converter && \
        rm /tmp/apicurio-registry-distro-connect-converter.tar.gz

USER 1001
