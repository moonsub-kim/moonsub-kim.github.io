---
title: Minikube
parent: posts
last_modified_date: 2021-09-21
has_children: false
nav_order: 2
---
# Minikube


라즈베리파이에서 k8s띄우는건 램없어서 포기 ㅜ

## Install

내 minikube cluster를 재생성할수있는 스크립트..

- 뇌절 home-ops
[https://news.hada.io/topic?id=5809&utm_source=slack&utm_medium=bot&utm_campaign=T02T3N2VD](https://news.hada.io/topic?id=5809&utm_source=slack&utm_medium=bot&utm_campaign=T02T3N2VD)

### Rasp 4 setup

[https://lance.tistory.com/5](https://lance.tistory.com/5)

```bash
sudo swapoff -a
systemctl disable dphys-swapfile.service
vi /etc/hosts
```

### Docker

[https://docs.docker.com/engine/install/ubuntu/##install-using-the-repository](https://docs.docker.com/engine/install/ubuntu/##install-using-the-repository)

재부팅할떄 언제나 실행

```bash
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
```

### minikube, k9s tools and start minikube

[https://minikube.sigs.k8s.io/docs/handbook/accessing/](https://minikube.sigs.k8s.io/docs/handbook/accessing/)

- `minikube`: 로컬 k8s cluster
- `k9s`: cli로 쓰는 kubectl
- `kubectx`: 쉽게 context, ns 전환 (minikube에선 `kubens <namespace>` 만 씀
- `helm`: k8s chart 설치를 위한 툴

```bash
$ brew install minikube k9s kubectx helm stern

$ minikube start --extra-config=apiserver.service-node-port-range=1-65535
$ minikube tunnel
```

### Ingress ([reference](https://kubernetes.io/ko/docs/tasks/access-application-cluster/ingress-minikube/))

minikube에서 ingress 설치

```bash
$ minikube addons enable ingress
$ HOST=MY_HOST
$ sudo sh -c "echo $(minikube ip) $HOST >> /etc/hosts"
```

### Redash with postgresql ([helm](https://github.com/getredash/contrib-helm-chart))

> Redash is designed to enable anyone, regardless of the level of technical sophistication, to harness the power of data big and small. SQL users leverage Redash to explore, query, visualize, and share data from any data sources. Their work in turn enables anybody in their organization to use the data. Every day, millions of users at thousands of organizations around the world use Redash to develop insights and make data-driven decisions.
>

```bash
## ns 생성
$ kubectl create namespace redash
$ kubens redash

$ helm repo add redash https://getredash.github.io/contrib-helm-chart/

$ cd cruise-values ## my local values directory
$ helm upgrade --install -f redash/values.yaml redash ../../getredash/contrib-helm-chart

### invite user url
redash-pod $ USER_ID=1 ## from DB
redash-pod $ python -c "from itsdangerous import URLSafeTimedSerializer; serializer = URLSafeTimedSerializer('$REDASH_SECRET_KEY'); print(f'$REDASH_HOST/invite/{serializer.dumps($USER_ID)}')"
```

### Reverse Proxy (Node to Minikube)([reference](https://phoenixnap.com/kb/nginx-reverse-proxy))

> If you have multiple servers, a reverse proxy can help balance loads between servers and improve performance. As a reverse proxy provides a single point of contact for clients, it can centralize logging and report across multiple servers.
>

```bash
$ sudo apt-get install nginx -y
$ sudo unlink /etc/nginx/sites-enabled/default
$ sudo sh -c 'echo "
server {
  listen 80;
  server_name redash.googleanalytics.ga;
  location / {
    proxy_pass http://minikube:5000;
  }
}
" > /etc/nginx/sites-available/custom_server.conf'
$ sudo ln -s /etc/nginx/sites-available/custom_server.conf /etc/nginx/sites-enabled/custom_server.conf
$ sudo service nginx configtest && sudo service nginx restart
```

### Create Database in postgresql

```bash
$ kubectl exec -it redash-postgresql-0 -nredash bash

redash-postgresql-0:/$ psql -U redash
Password for user redash: ### typing password

redash=> CREATE DATABASE crawler;
CREATE DATABASE

redash=> select * from pg_database;
## db 생성됐는지 쳌
```

### Install Crawler

[GitHub - moonsub-kim/crawl-data-slack](https://github.com/moonsub-kim/crawl-data-slack/)

```bash
$ kubectl create namespace crawler
$ kubens crawler

$ cd moonsub-kim/crawl-data-slack
crawl-data-slack $ helm upgrade crawler helm/crawl-data-slack -f ../cruise-values/crawler/values.yaml -i
```

freenom


## Minikube ingress with reverse proxy

```bash
## install the nginx ingress addon
$ minikube addons enable ingress

## route "minikube" to the minikube cluster
$ HOST=minikube
$ sudo sh -c "echo $(minikube ip) $HOST >> /etc/hosts"

## test
$ curl minikube

## install nginx to use reverse proxy
$ sudo apt-get install nginx -y
$ sudo unlink /etc/nginx/sites-enabled/default

#### route localhost:80 to "minikube"
## server {
##   listen 80;
##   server_name anstjq.ml;
##
##   location / {
##     return 301 https://gos16052.notion.site/Blog-6dba24938a63473788e7866acbe38526;
##   }
## }
##
## server {
##   listen 80;
##   server_name redash.anstjq.ml;
##
##   location / {
##     proxy_pass http://redash;
##   }
## }
$ sudo cp nginx/custom_server.conf > /etc/nginx/sites-available/custom_server.conf'
$ sudo ln -s /etc/nginx/sites-available/custom_server.conf /etc/nginx/sites-enabled/custom_server.conf
$ sudo service nginx configtest && sudo service nginx restart
```

[freenom.com](http://freenom.com) - free domain