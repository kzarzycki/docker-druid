#!/usr/bin/env bash
set -x

DRUID_ROLE=${1:-"coordinator"}
MEMORY=${JAVA_MEMORY:-"768m"}

if env | grep -q MSQL_PORT_3306_TCP_ADDR; then
  sed -i "s/localhost\:3306/$MSQL_PORT_3306_TCP_ADDR\:3306/g" /druid/config/$DRUID_ROLE/runtime.properties
  sed -i "s/localhost\\\:3306/$MSQL_PORT_3306_TCP_ADDR\\\:3306/g" /druid/config/$DRUID_ROLE/runtime.properties
  sed -i 's/\# druid.db.connector/druid.db.connector/g' /druid/config/$DRUID_ROLE/runtime.properties
fi

if env | grep -q ZK_PORT_2181_TCP_ADDR; then
  sed -i "s/druid.zk.service.host=localhost/druid.zk.service.host=$ZK_PORT_2181_TCP_ADDR/g" /druid/config/$DRUID_ROLE/runtime.properties
fi

# Standardize port to 8000
sed -i 's/druid.port=.*/druid.port=8000/g' /druid/config/$DRUID_ROLE/runtime.properties

# Set specific hostname
sed -i "s/druid.host=.*/druid.host=$HOSTNAME/g" /druid/config/$DRUID_ROLE/runtime.properties

if [ "$DRUID_ROLE" = "realtime" ]; then
  sed -i "s/druid.publish.type=.*/druid.publish.type=db/g" /druid/config/$DRUID_ROLE/runtime.properties
  echo "druid.realtime.specFile=/druid/examples/wikipedia/wikipedia_realtime.spec" >> /druid/config/$DRUID_ROLE/runtime.properties
fi

cat /druid/config/$DRUID_ROLE/runtime.properties

sleep 5

java -server \
     -Xmx$MEMORY \
     -Duser.timezone=UTC \
     -Dfile.encoding=UTF-8 \
     -cp /druid/lib/*:/druid/config/$DRUID_ROLE \
     io.druid.cli.Main server $DRUID_ROLE
