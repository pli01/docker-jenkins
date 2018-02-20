#!/bin/bash
set -x

image_name=${1:? $(basename $0) IMAGE_NAME VERSION needed}
version=${2:-latest}
namespace=jenkins

echo "Check docker-compose -p ${namespace} config"
docker-compose -p ${namespace} config

echo "Check Jenkins version"
docker-compose -p ${namespace} run --rm jenkins --version

echo "Check docker version"
docker run -it --rm $image_name /bin/bash -c 'docker version || true'
docker run -it --rm $image_name /bin/bash -c 'docker-compose -p ${namespace} version || true'

#docker-compose -p ${namespace} run --name "test" --rm --entrypoint '/bin/bash' jenkins -x /test/unit/version.sh
#docker-compose -p ${namespace} run --name "test" --rm --entrypoint '/bin/bash' jenkins -c /usr/local/bin/docker-compose
exit 0
