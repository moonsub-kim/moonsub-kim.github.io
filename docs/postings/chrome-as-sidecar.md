---
title: "crawler pod에 sidecar로 chromedriver를 띄우자"
parent: posts
last_modified_date: 2022-12-20
nav_order: 5
description: "crawler pod에 sidecar로 chromedriver를 띄우자"
---

- shareProcessNamespace로 main container와 chromedriver container간 pid를 공유하도록 만들기
- main process가 완료되면 sidecar가 죽도록 만들기

pod spec
```yaml
spec:
    shareProcessNamespace: true
    containers:
    - name: main
      image: {{ $.Values.image }}:{{ $.Values.imageTag }}
      command:
      - "./main"
      env:
      - name: CHROME_HOST
          value: localhost:9222
    - name: sidecar-chrome
      image: chromedp/headless-shell:stable
      command:
      - "sh"
      - "-c"
      - |
          /headless-shell/headless-shell --no-sandbox --remote-debugging-address=0.0.0.0 --remote-debugging-port=9222 --disable-dev-shm-usage &
          CHILD_PID=$!
          sleep 5
          (while true; do if pidof main > /dev/null; then echo''; else kill $CHILD_PID; exit 0; fi; sleep 1; done) # main process 눈팅하면서 죽으면 headless-shell 종료
      ports:
      - containerPort: 9222
```
