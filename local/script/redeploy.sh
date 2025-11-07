#!/bin/bash
set -e

TOMCAT_HOME="/opt/tomcat"
WAR_NAME="cas.war"

echo "=== Nettoyage et build de CAS ==="
./gradlew clean build -x test

echo "=== Suppression ancien déploiement ==="
rm -rf $TOMCAT_HOME/webapps/cas
rm -f $TOMCAT_HOME/webapps/$WAR_NAME
sleep 10
echo "=== Copie du nouveau WAR ==="
cp build/libs/$WAR_NAME $TOMCAT_HOME/webapps/
sleep 20
echo "=== Redémarrage de Tomcat ==="
$TOMCAT_HOME/bin/shutdown.sh || true
sleep 60
$TOMCAT_HOME/bin/startup.sh

echo "=== Suivi des logs ==="
tail -f $TOMCAT_HOME/logs/catalina.out

