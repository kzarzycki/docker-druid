#!/usr/bin/env bash
set -x

DRUID_NODE_TYPE=${1:-"coordinator"}
MEMORY=${JAVA_MEMORY:-"768m"}

EXAMPLE_SPEC=${EXAMPLE:-"wikipedia"}
SPEC="/druid/examples/${EXAMPLE_SPEC}/${EXAMPLE_SPEC}_realtime.spec"
IP=$(ip addr | grep 'eth0' | awk '{print $2}' | cut -f1  -d'/' | tail -1)

druid_config_alter(){
  sed -i "$1" /druid/config/$DRUID_NODE_TYPE/runtime.properties
}

druid_config_add(){
  echo -e "\n$1" >> /druid/config/$DRUID_NODE_TYPE/runtime.properties
}

if env | grep -q MYSQL_PORT_3306_TCP_ADDR; then
  druid_config_alter "s/druid.db.connector.connectURI=.*/druid.db.connector.connectURI=jdbc\\\:mysql\\\:\/\/$MYSQL_PORT_3306_TCP_ADDR\\\:3306\/druid/g"
  druid_config_alter 's/\# druid.db.connector/druid.db.connector/g'
fi

if env | grep -q ZK_PORT_2181_TCP_ADDR; then
  druid_config_alter "s/druid.zk.service.host=localhost/druid.zk.service.host=$ZK_PORT_2181_TCP_ADDR/g"
  druid_config_add "druid.zk.paths.base=druid"
fi


if [ "$DRUID_NODE_TYPE" = "historical" ]; then
  if  env | grep -q s3_access_key && env | grep -q s3_secret_key; then
    druid_config_alter "s@druid.s3.secretKey.*@druid.s3.secretKey=$s3_secret_key@g"
    druid_config_alter "s@druid.s3.accessKey.*@druid.s3.accessKey=$s3_access_key@g"
    druid_config_add "druid.storage.bucket=$s3_bucket"
    druid_config_add "druid.storage.type=s3"
  fi
fi

# Standardize port to 8000
druid_config_alter 's/druid.port=.*/druid.port=8000/g'

# Set specific hostname
druid_config_alter "s/druid.host=.*/druid.host=$IP/g"

if [ "$DRUID_NODE_TYPE" = "realtime" ]; then
  druid_config_alter "s/druid.publish.type=.*/druid.publish.type=db/g"
  druid_config_add "druid.realtime.specFile=$SPEC"

  if  env | grep -q s3_access_key && env | grep -q s3_secret_key; then
    druid_config_alter "s/rabbitmq/s3-extensions/g" # Change the extension
    druid_config_add "druid.storage.type=s3"
    druid_config_add "druid.s3.secretKey=$s3_secret_key"
    druid_config_add "druid.s3.accessKey=$s3_access_key"
    druid_config_add "druid.storage.bucket=$s3_bucket"
  fi


fi

cat /druid/config/$DRUID_NODE_TYPE/runtime.properties

sleep 5

java -server \
     -Xmx$MEMORY \
     -Duser.timezone=UTC \
     -Dfile.encoding=UTF-8 \
     -cp /druid/lib/*:/druid/config/$DRUID_NODE_TYPE \
     io.druid.cli.Main server $DRUID_NODE_TYPE
