#!/bin/bash -ex

pwd=`pwd`

export JAVA_HOME=$HOME/tools/jdk
export M2_HOME=$HOME/tools/mvn

mvn=${M2_HOME}/bin/mvn
apm_ver=1.13.0

#${mvn} clean package install assembly:single dependency:copy-dependencies exec:java
#rm -rf log/* && ${mvn} clean package exec:java
#${mvn} exec:java
#${mvn} clean javadoc:fix javadoc:javadoc

[ -d apm ] || mkdir -p apm

# ${mvn} clean package install assembly:single
${mvn} compile

[ -f $pwd/apm/elastic-apm-agent.jar ] || \
    wget https://repo1.maven.org/maven2/co/elastic/apm/elastic-apm-agent/$apm_ver/elastic-apm-agent-$apm_ver.jar
[ -f $pwd/elastic-apm-agent-$apm_ver.jar ] && \
    mv $pwd/elastic-apm-agent-$apm_ver.jar $pwd/apm/elastic-apm-agent.jar

java -javaagent:$pwd/apm/elastic-apm-agent.jar \
    -Delastic.apm.service_name=gcpplayground \
    -Delastic.apm.server_urls=http://10.140.0.3:8200 \
    -Delastic.apm.application_packages=com.bindiego \
    -Dlog4j.configurationFile=$pwd/conf/log4j2.xml \
    -jar target/gcp-1.0-SNAPSHOT-jar-with-dependencies.jar
    # -Delastic.apm.secret_token= \
