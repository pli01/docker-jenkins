#!/bin/bash

image_name=${1:? $(basename $0) IMAGE_NAME VERSION needed}
version=${2:-latest}

echo "Check docker-compose config"
docker-compose config

echo "Check Jenkins version"
docker-compose run --rm jenkins --version

echo "Check docker version"
docker run -it --rm $image_name /bin/bash -c 'docker version || true'
docker run -it --rm $image_name /bin/bash -c 'docker-compose version || true'

#docker-compose run --name "test" --rm --entrypoint '/bin/bash' jenkins -x /test/unit/version.sh
#docker-compose run --name "test" --rm --entrypoint '/bin/bash' jenkins -c /usr/local/bin/docker-compose
exit 0
