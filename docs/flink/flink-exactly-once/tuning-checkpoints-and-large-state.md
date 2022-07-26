---
title: Tuning Checkpoints and Large State
parent: Flink Exactly-Once
grand_parent: Flink
last_modified_date: 2021-12-28
nav_order: 3
description: "[Tuning Checkpoints and Large State](https://nightlies.apache.org/flink/flink-docs-release-1.14/docs/ops/state/large_state_tuning/) 를 번역한 글 입니다."
---
**{{ page.description }}**

# Tuning Checkpoints and Large State

## Overview

Flink는 large scale에서 안정적으로 동작하기 위해 2개의 조건을 만족해야한다.

- Application이 checkpoint를 안정적으로 수행할 수 있어야 한다
- failure이후에 input data stream을 따라잡을 수 있을정도로 충분한 리소스를 확보해야 한다.

첫번째 섹션은 어떻게 checkpointing을 scalable하게 수행하는지 설명하고, 마지막 세션은 얼마만큼의 resource를 할당해야 하는지 best practice를 제시할것이다

## Monitoring State and Checkpoints

checkpoint를 모니터하기 쉬운 방법은 UI의 checkpoint section을 보는것이다. [**checkpoint monitoring**](https://nightlies.apache.org/flink/flink-docs-release-1.14/docs/ops/monitoring/checkpoint_monitoring/) 문서에 checkpoint metric이 있다.

checkpoint를 scale up하기 위해 봐야하는것은

- operator가 first checkpoint barrier를 받을때까지의 시간.
checkpoint를 트리거하는시간이 지속적으로 높을때 checkpoint barrier는 source에서부터 operator들까지 전달되는데 시간이 많이 필요함을 의미한다. 이것은 일반적으로 constant backpressure 상황에 놓여있음을 의미한다.
- Alignment duration: first와 last checkpoint barrier를 받은 시간 간격.
unaligned `exactly-once` checkpoint와 unaligned `at-least-once checkpoint` 도중에 subtask는 interruption 없이 upstream subtask에서 온 모든 data를 처리한다. (unaligned는 어떤 의미?). 하지만 aligned `exactly-once` checkpoint에선 checkpoint barrier를 이미 받은 channel은 모든 remaining channel이 checkpoint barrier를 받을 때 까지 data 전송이 block된다 (alignment time).

위 두개의 값은 낮게 유지되어야한다. 높다면 checkpoint barrier가 back pressure때문에(incoming record를 프로세싱할 리소스가 충분하지 않기때문) job graph를 느리게 travel하고 있다는 것이다. 또한 이 상황은 process된 Record의 end-to-end latency를 증가시키게 된다. 이 메트릭들은 일시적인 backpressure, data skew, network issue등으로 높게 나타날 수 있다.

Unaligned checkpoint