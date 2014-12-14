#!/usr/bin/env bash
set -x

DRUID_NODE_TYPE=${1:-"coordinator"}
MEMORY=${JAVA_MEMORY:-"768m"}

EXAMPLE_SPEC=${EXAMPLE:-"wikipedia"}
SPEC="/druid/examples/${EXAMPLE_SPEC}/${EXAMPLE_SPEC}_realtime.spec"
IP=$(ip addr | grep 'eth0' | awk '{print $2}' | cut -f1  -d'/' | tail -1)

druid_config(){
  sed -i "$1" /druid/config/$DRUID_NODE_TYPE/runtime.properties
}

if env | grep -q MYSQL_PORT_3306_TCP_ADDR; then
  druid_config "s/druid.db.connector.connectURI=.*/druid.db.connector.connectURI=jdbc\\\:mysql\\\:\/\/$MYSQL_PORT_3306_TCP_ADDR\\\:3306\/druid/g"
  druid_config 's/\# druid.db.connector/druid.db.connector/g'
fi

if env | grep -q ZK_PORT_2181_TCP_ADDR; then
  druid_config "s/druid.zk.service.host=localhost/druid.zk.service.host=$ZK_PORT_2181_TCP_ADDR/g"
fi

# Standardize port to 8000
druid_config 's/druid.port=.*/druid.port=8000/g'

# Set specific hostname
druid_config "s/druid.host=.*/druid.host=$IP/g"

if [ "$DRUID_NODE_TYPE" = "realtime" ]; then
  druid_config "s/druid.publish.type=.*/druid.publish.type=db/g"
  echo "druid.realtime.specFile=$SPEC" >> /druid/config/$DRUID_NODE_TYPE/runtime.properties
fi

cat /druid/config/$DRUID_NODE_TYPE/runtime.properties

sleep 5

java -server \
     -Xmx$MEMORY \
     -Duser.timezone=UTC \
     -Dfile.encoding=UTF-8 \
     -cp /druid/lib/*:/druid/config/$DRUID_NODE_TYPE \
     io.druid.cli.Main server $DRUID_NODE_TYPE
