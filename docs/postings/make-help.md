---
title: make help 줍줍
parent: 글
last_modified_date: 2022-08-22
has_children: false
nav_order: 2
---

# make help 줍줍

작년에 Flink 써보려고 노력하던시절 (python 지원이 약해서 접음..) [spotlify/flink-on-k8s-operator](https://github.com/spotify/flink-on-k8s-operator) 에서 신기한 커맨드 발견

```sh
##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)


##@ Build

build: ## Build the image.
  @docker build .

##@ Run

run: ## Run the image with bash shell. $ make run cmd=ls
  @docker-compose run --name app $(cmd)

```

섹션을 나눌땐 `##@ Section` 으로 선언하고, command help를 쓸땐 command에 `##` 로 comment를 달아두면된다.

이전엔 `help` command에 echo로 스페이스 줄 맞춰가면서 막 지지고 볶고 귀찮아서 까먹고 그랬었는데 저 라인 한줄만 추가하면 매우 간단해짐. 다만 multiline은 안되는듯함.

```sh
$ make help

Usage:
  make <target>

General
  help             Display this help.

Build
  build            Build the image.
  run              Run the image with bash shell. $ make run cmd=ls
```
