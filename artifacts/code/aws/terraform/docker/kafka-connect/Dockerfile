FROM quay.io/strimzi/kafka:0.36.1-kafka-3.4.0
USER root:root
RUN mkdir -p /opt/kafka/plugins
RUN mkdir /opt/kafka/plugins/connect-file && \
    curl -s -o /opt/kafka/plugins/connect-file/connect-file-3.4.0.jar https://repo1.maven.org/maven2/org/apache/kafka/connect-file/3.4.0/connect-file-3.4.0.jar
USER 1001