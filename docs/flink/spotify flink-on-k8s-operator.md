---
title: spotify/flink-on-k8s-operator
parent: Flink
last_modified_date: 2022-01-28
---
# spotify/flink-on-k8s-operator

[https://github.com/spotify/flink-on-k8s-operator](https://github.com/spotify/flink-on-k8s-operator)

# Flink k8s operator

Flink k8s operator는 k8s control plane으로 Flink app의 deployment lifecycle을 관리한다. Flink Cluster CRD([docs/crd.md](https://github.com/spotify/flink-on-k8s-operator/blob/master/docs/crd.md)) 를 쓰고, controller pod ([controllers/controller_pod.go](https://github.com/spotify/flink-on-k8s-operator/blob/master/controllers/flinkcluster_controller.go))을 실행시켜 custom resource를 눈팅한다. custom resource가 생성되고 controller가 detect하면, 스펙에 맞춰 controller가 k8s resource를 생성한다.

## Installation ([user_guide.md](https://github.com/spotify/flink-on-k8s-operator/blob/master/docs/user_guide.md))

- devloper_guide.md는 CRD를 수정할경우 필요한 것 같다.

### cert-manager 설치

`kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.3/cert-manager.yaml`

### flink operator 설치

- [release version](https://github.com/spotify/flink-on-k8s-operator/releases)

```java
$ git clone https://github.com/spotify/flink-on-k8s-operator
...
$ cd flink-on-k8s-operator
flink-on-k8s-operator $ make deploy IMG=gos16052/flink-operator:latest

```

위 커맨드를 통해 생성되는것

1. CRD `flinkclusters.flinkoperator.k8s.io`
2. namespace `flink-operator-system`
3. pod `flink-operator-controller-manager`

## Run a sample cluster (job cluster, java)

```bash
# clone the flink operator repo
# git clone https://github.com/spotify/flink-on-k8s-operator

$ kubectl apply -f config/samples/flinkoperator_v1beta1_flinkjobcluster.yaml
```

## [crd.md](https://github.com/spotify/flink-on-k8s-operator/blob/master/docs/crd.md)

## Run a job cluster with python program

sample java FlinkCluster yaml

```yaml
apiVersion: flinkoperator.k8s.io/v1beta1
kind: FlinkCluster
metadata:
  name: flinkjobcluster-sample
spec:
  flinkVersion: 1.14.0
  image:
    name: flink:1.14.0
  jobManager:
    accessScope: Cluster
    ports:
      ui: 8081
    resources:
      limits:
        memory: "1024Mi"
        cpu: "200m"
  taskManager:
    replicas: 2
    resources:
      limits:
        memory: "1024Mi"
        cpu: "200m"
  job:
    jarFile: ./examples/streaming/WordCount.jar
    className: org.apache.flink.streaming.examples.wordcount.WordCount
    args: ["--input", "./README.txt"]
    parallelism: 2
    restartPolicy: "FromSavepointOnFailure"
    maxStateAgeToRestoreSeconds: 60
  flinkProperties:
    taskmanager.numberOfTaskSlots: "1"
```

`spec.job.jarFile`, `spec.job.className` 이 java executable 관련인데 모두 required이다. 실행시키는경우 flink image args에 `--detacted ./examples/streaming/WordCount.jar --class org.apache.flink.streaming.examples.wordcount.WordCount` 가 추가로 들어간다.

`spec.job.args`는 flink image args에 그대로 추가된다. 위 예시에서는 `--input ./README.txt` 가 추가된다.

- python executable args 넘기기
`--python ./apps/example/word_count.py` 과 같은 args를 추가해줘야한다.
단순하게 `args: ["--python", "./apps/example/word_count.py"]` 를 넣으면 O
- CRD 변경없이 `spec.job.jarFile, spec.job.className` 무효화 (bypass)
값은 required이지만, empty string같은 값들이 들어간다면 args를 보고 무시하게 된다
`standalone-job --python ./apps/example/word_count.py --detached ' ' --class ' '`

그런데 또 아래와 args 순서에서 detached, class가 먼저 나오면 안됨 ..
`standalone-job --detached ' ' --class ' ' --python ./apps/example/word_count.py`

[https://github.com/GoogleCloudPlatform/flink-on-k8s-operator/issues/213](https://github.com/GoogleCloudPlatform/flink-on-k8s-operator/issues/213)