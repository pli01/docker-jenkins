#!/bin/bash
#set -x

image_name=${1:? $(basename $0) IMAGE_NAME VERSION needed}
VERSION=${2:-latest}
namespace=jenkins
test_service=jenkins
test_compose=docker-compose.yml
export VERSION

ret=0
echo "Check tests/docker-compose.yml config"
docker-compose -p ${namespace} config
test_result=$?
if [ "$test_result" -eq 0 ] ; then
  echo "[PASSED] docker-compose -p ${namespace} config"
else
  echo "[FAILED] docker-compose -p ${namespace} config"
  ret=1
fi
echo "Check Jenkins version"
if [ "$VERSION" == "latest" -o "$VERSION" == "lts" ] ;then
docker-compose -p ${namespace} run --name "test-$test_service" --rm $test_service --version
test_result=$?
else
docker-compose -p ${namespace} run --name "test-$test_service" --rm $test_service --version | grep "${VERSION}"
test_result=$?
fi

if [ "$test_result" -eq 0 ] ; then
  echo "[PASSED] jenkins --version $VERSION"
else
  echo "[FAILED] jenkins --version $VERSION"
  ret=1
fi

test -t 1 && USE_TTY="-t"
echo "Check docker version"
docker run -i ${USE_TTY} --rm $image_name:$VERSION /bin/bash -c 'docker version || true'
test_result=$?
if [ "$test_result" -eq 0 ] ; then
  echo "[PASSED] docker version"
else
  echo "[FAILED] docker version"
  ret=1
fi

echo "Check docker-compose version"
docker run -i ${USE_TTY} --rm $image_name:$VERSION /bin/bash -c 'docker-compose version || true'
test_result=$?
if [ "$test_result" -eq 0 ] ; then
  echo "[PASSED] docker-compose version"
else
  echo "[FAILED] docker-compose version"
  ret=1
fi

echo "Check ansible-lint version"
docker run -i ${USE_TTY} --rm $image_name:$VERSION /bin/bash -c 'ansible-lint --version'
test_result=$?
if [ "$test_result" -eq 0 ] ; then
  echo "[PASSED] ansible-lint version"
else
  echo "[FAILED] ansible-lint version"
  ret=1
fi

echo "Check jenkins-jobs version"
docker run -i ${USE_TTY} --rm $image_name:$VERSION /bin/bash -c 'jenkins-jobs --version'
test_result=$?
if [ "$test_result" -eq 0 ] ; then
  echo "[PASSED] jenkins-jobs version"
else
  echo "[FAILED] jenkins-jobs version"
  ret=1
fi

echo "Check openstack version"
docker run -i ${USE_TTY} --rm $image_name:$VERSION /bin/bash -c 'openstack --version'
test_result=$?
if [ "$test_result" -eq 0 ] ; then
  echo "[PASSED] openstack version"
else
  echo "[FAILED] openstack version"
  ret=1
fi

echo "Check yamllint version"
docker run -i ${USE_TTY} --rm $image_name:$VERSION /bin/bash -c 'yamllint --version'
test_result=$?
if [ "$test_result" -eq 0 ] ; then
  echo "[PASSED] yamllint version"
else
  echo "[FAILED] yamllint version"
  ret=1
fi

echo "Check jq version"
docker run -i ${USE_TTY} --rm $image_name:$VERSION /bin/bash -c 'jq --version'
test_result=$?
if [ "$test_result" -eq 0 ] ; then
  echo "[PASSED] jq version"
else
  echo "[FAILED] jq version"
  ret=1
fi



echo "Check LDAP config"
docker-compose -p ${namespace} -f $test_compose up -d --no-build $test_service

# Wait service up and running
RETRY_NB=240
RETRY_DELAY_IN_SEC=1
n=0
state=1
echo "Wait $RETRY_NB second for $test_service ready ?"
until [ $n -ge $RETRY_NB ] || [ $state -eq 0 ]; do
 if docker-compose -p ${namespace} -f $test_compose logs --tail=10  |grep -q  'INFO: Jenkins is fully up and running' ; then
   echo "$test_service ready"
   state=$?
 else
   echo "Test failed at $n try"
   sleep $RETRY_DELAY_IN_SEC
   sleep 1
 fi
 ((n++))
done

docker-compose -p ${namespace} -f $test_compose exec -T $test_service /bin/bash -c 'ls -l $HOME/'
docker-compose -p ${namespace} -f $test_compose exec -T $test_service /bin/bash -c 'grep ignoreIfUnavailable $HOME/config.xml'
test_result=$?
if [ "$test_result" -eq 0 ] ; then
  echo "[PASSED] Check LDAP conf"
else
  echo "[FAILED] Check LDAP conf"
  ret=1
fi

# teardown
echo "# teardown:"
docker-compose -p ${namespace} -f $test_compose stop
docker-compose -p ${namespace} -f $test_compose rm -fv

#docker-compose -p ${namespace} run --name "test" --rm --entrypoint '/bin/bash' jenkins -x /test/unit/version.sh
#docker-compose -p ${namespace} run --name "test" --rm --entrypoint '/bin/bash' jenkins -c /usr/local/bin/docker-compose
exit $ret
