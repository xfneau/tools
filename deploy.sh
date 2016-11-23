#!/bin/sh

function getPro(){
if [ $1 = "dubbo" ]; then 
	echo "dubbo";
elif [ $1 = "cms-webapp" ]; then
	echo "maintenance";
elif [ $1 = "webapp" ]; then
	echo "website";
else [ $1 = "wap-webapp" ];
	echo "wap";
fi;
}
LOCAL_DIR=/data/deploy
  
CURRENT_TIME=`date +%Y%m%d%H%M%S`       

SERVER_NAME=$1
if [ ! $1 ];then
	SERVER_NAME='root@test01'
fi
source /etc/profile
echo ${SERVER_NAME}
cd /data/code

git stash
git stash drop
git pull
echo "code updated=================================================="
sleep 2
mvn -U cn.edianzu:maven-version-plugin:0.0.1-SNAPSHOT:replace
if [ ${SERVER_NAME} = "root@test" -o ${SERVER_NAME} = "root@stage01" ]; then
    echo "s/stage.resources.edianzu.cn/resources.edianzu.cn"
    sed -i "s/http:\/\/resources.baidu.cn/http:\/\/stage.resources.baidu.cn/g" `grep resources.baidu.cn -rl /data/code`
fi
mvn clean package -Dmaven.test.skip=true
echo "code packaged================================================="      
sleep 2
#backup
PROJECT_NAME="dubbo cms-webapp webapp wap-webapp"
for i in $PROJECT_NAME;do
	read -p "deploy $i and cut flow? y/n" r
	if [ $r = "y" ]; then
		echo "mkdir ${LOCAL_DIR}/${CURRENT_TIME}/$i"
		ssh ${SERVER_NAME} mkdir -p ${LOCAL_DIR}/${CURRENT_TIME}/$i
		PATH_ONLINE=${LOCAL_DIR}/${CURRENT_TIME}/$i
		TMP=`getPro $i`
		
		if [ ${TMP} = "dubbo" ]; then
			scp -r `find /data/code/mall -iname "mall-dubbo.war"|grep ${TMP}` ${SERVER_NAME}:${PATH_ONLINE}
			ssh ${SERVER_NAME} "rm -rf /data/tomcat-dubbo/webapps;ln -s ${PATH_ONLINE} /data/tomcat-dubbo/webapps"
			echo "scp tomcat-mall-$i success"
		else
			scp -r mall-${TMP}/mall-${TMP}-webapp/target/mall-${TMP}-webapp/*  ${SERVER_NAME}:${PATH_ONLINE}
			ssh ${SERVER_NAME} "rm -rf /data/tomcat-$i/webapps/ROOT;ln -s ${PATH_ONLINE} /data/tomcat-$i/webapps/ROOT"
			echo "scp tomcat-mall-$i success"
		fi
		ssh ${SERVER_NAME} "source /etc/profile;ps -ef | grep 'tomcat-mall-'$i | grep -v 'grep' | awk '{print \$2}' | xargs kill -9"
        	ssh ${SERVER_NAME} "sleep 2"
        	echo 'killed tomcat-'$i;
		ssh ${SERVER_NAME} "/data/tomcat-$i/bin/startup.sh"
		echo "----start server tomcat-$i success---"
	fi
done

echo "--------${SERVER_NAME} deploy success--------"

