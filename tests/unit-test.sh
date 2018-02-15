#!/bin/bash

packagename=${1:? $(basename $0) PACKAGENAME VERSION needed}
version=${2:-latest}

echo "Check docker-compose config"
docker-compose config

echo "Check path"
docker-compose run --name "test-$packagename" --rm --entrypoint "/bin/bash -c"  jenkins pwd

exit 0
