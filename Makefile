#
include Makefile.version
VERSION ?= $(shell [ -f VERSION ] && cat VERSION)
BUILD_VERSION ?= # BUILD_VERSION=$(cat VERSION)-$(git rev-parse --short HEAD)

project ?=
env ?= # dev
sudo ?= # sudo -E

compose_args += -f docker-compose.yml
compose_args += $(shell [ -f  docker-compose.$(env).yml ] && echo "-f docker-compose.$(env).yml")

.PHONY: clean-image config
all: stop rm up
clean:
	rm -rf Dockerfile.template Dockerfile.$(VERSION)
	$(sudo) docker system prune -f
.PHONY: config
config:
	$(sudo) VERSION=$(VERSION) docker-compose $(compose_args) config

.PHONY: build
prepare:
	cp Dockerfile Dockerfile.template
	sed -e 's|\(FROM .*\):\(.*\)|\1:$(VERSION)|' Dockerfile.template > Dockerfile.$(VERSION)
build: prepare config
	$(sudo) VERSION=$(VERSION) docker-compose $(compose_args) build

pull:  pull-docker pull-docker-compose

pull-docker: Dockerfile.$(VERSION)
	docker_image=$$(grep ^FROM Dockerfile.$(VERSION) | awk ' { print $$2 }') ; \
		     docker pull $$docker_image
pull-docker-compose:
	$(sudo) VERSION=$(VERSION) docker-compose $(compose_args) pull

save-docker: Dockerfile.$(VERSION)
	docker_image=$$(grep ^FROM Dockerfile.$(VERSION) | awk ' { print $$2 }') ; \
	  docker_image_file=$$(echo $$docker_image| sed -e 's|/|_|g ; s|:|__|g') ; \
	  docker image save $$docker_image | gzip -9c > $(DESTDIR)$${docker_image_file}.tar.gz ; \
	  md5sum $(DESTDIR)$${docker_image_file}.tar.gz

save-docker-compose: Dockerfile.$(VERSION)
	docker_image=$$(docker-compose $(compose_args) config | python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)'  | jq -r '.services[].image') ; \
	  docker_image_file=$$(echo $$docker_image| sed -e 's|/|_|g ; s|:|__|g') ; \
	  docker image save $$docker_image | gzip -9c > $(DESTDIR)$${docker_image_file}.tar.gz ; \
	  md5sum $(DESTDIR)$${docker_image_file}.tar.gz

up:
	$(sudo) docker-compose $(compose_args) up -d
restart:
	$(sudo) docker-compose $(compose_args) restart
rm:
	$(sudo) docker-compose $(compose_args) rm -f
stop:
	$(sudo) docker-compose $(compose_args) stop
logs:
	$(sudo) docker-compose $(compose_args) logs

rmi:
	$(sudo) docker rmi $(IMAGE_NAME):$(VERSION) || true

### packaging ###
# 
#
version:
	@echo $(PACKAGENAME) $(VERSION)
package:
	@echo '# $@ STARTING'
	@bash ./tools/package.sh $(PACKAGENAME) $(VERSION)
	@echo '# $@ SUCCESS'
clean-package:
	rm -rf dist ||true

.PHONY: test
test: build unit-test
	@echo '# $@ SUCCESS'


unit-test:
	@echo '# $@ STARTING'
	( cd tests && bash unit-test.sh $(IMAGE_NAME) $(VERSION) )
	@echo '# $@ SUCCESS'

publish: package dist/$(PACKAGENAME)-$(VERSION).tar.gz
	@echo "# $@ STARTING"
	bash ./tools/publish.sh $(PACKAGENAME) $(VERSION)
	@echo '# $@ SUCCESS'

push:
	@echo "# $@ STARTING"
	bash ./tools/push.sh $(IMAGE_NAME) $(VERSION) $(BUILD_VERSION)
	@echo '# $@ SUCCESS'

push-docker:
	@echo "# $@ STARTING"
	docker_image=$$(grep ^FROM Dockerfile.$(VERSION) | awk ' { print $$2 }') ; \
		     docker_image_name=$$(echo $$docker_image| awk -F: '{ print $$1}') ; \
	bash ./tools/push.sh $${docker_image_name} $(VERSION)
clean-image:
	$(sudo) docker rmi $(IMAGE_NAME):$(VERSION) || true
