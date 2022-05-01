---
title: Exactly-Once Semantics
parent: Kafka
last_modified_date: 2021-11-12
nav_order: 0
description: "Confluent의 [Exactly-Once Semantics Are Possible: Here’s How Kafka Does It](https://www.confluent.io/blog/exactly-once-semantics-are-possible-heres-how-apache-kafka-does-it/) 을 번역한 글 입니다."
---
{{ page.description }}

# Exactly-Once Semantics

## What is exactly-once semantics? Messaging semantics explained

distributed publish-subscribe messaging system을 구성하는 node는 언제나 실패할 수 있다. Kafka에서 각 broker는 크래쉬가 발생하거나, producer가 topic으로 message를 전달할때 network failure가 생길 수도 있다. producer가 이런 failure를 처리하는 액션에 따라 여러 semantic이 존재한다

- At-least-once semantics: producer가 Kafka broker로부터 ack를 받는 것은 message가 kafka에 exactly once로 write됐다는 것을 의미한다. 그러나 producer가 ackt timeout이나 error를 받으면 message가 Kafka topic에 write되지 않았다고 인지하고 message를 다시 보낼것이다. 만약 broker가 topic에 message를 쓰고나서 ack를 보내기 직전에 failure가 발생했다면, 재시도는 message가 2번 write되게 만들고, consumer에게 2개의 중복된 message를 전달하게 된다.
- At-most-once semantics: producer가 ack timeout이나 error에서 retry를 하지 않는다면 message는 topic에 write되지 않았을거고 consumer에게 전달되지 않는다.
- Exactly-once semantics: producer가 message를 재전송할지라도 message가 consumer에게 정확히 한번만 전달되게 한다. Exactly-once semantic은 messaging system과, producer, consumer의 동작을 모두 이해해야 한다. 예를들어 message를 consume한 뒤 이전 offset으로 되돌리면, 이전 offset에서 최신 offsset까지의 모든 message를 다시 받을 수 있다. 이것은 exactly-once semantic을 만들기 위해 왜 messaging system과 client application이 cooperate해야하는지 보여준다.

## Failures that must be handled

single processs producer가 message "Hello Kafka"를 single partition topic "EoS"에 보내고, single-instance consumer가 topic으로부터 message를 받아서 print하는것을 생각해보자. 장애가 없다면 "Hello Kafka" message는 EoS topic에 한번만 쓰여진다. consumer가 process하고 message offset은 이 message가 processing되었다는것을 가리킨다. 그래서 consumer가 재시작, 장애상황에서도 같은 message를 두번다시 보지않게 된다.

그러나 아래와 같은 장애생황도 고려해야한다

1. A broker can fail: Kafka는 partition에 write되는 모든 messsage가 persist되고, N회만큼 replicate되는 highly available, persistent, durable system이다. 그래서 Kafka는 N-1 broker failure에도 tolerant하므로 partition은 1개의 broker만 available해도 문제가 없다. Kafka의 replication protocol은 messsage가 leader replica에 한번만 write되는것을 보장하고, 이것은 모든 available replica로 복제된다.
2. The producer-to-broker RPC can fail: Kafka의 durability는 broker로부터 ack를 받는 prodcuer에 따라 결정된다. ack를 받지 못했다고 해서 요청이 실패한것은 아니다. broker는 message를 write한 후, ack를 보내기전에 crash가 날 수 있다. 또한 topic에 message를 write할때 crash가 날 수도 있다. producer가 failure를 감지할 수 없지만, message가 write되는 것이 실패했다고 가정하고 재시도한다. 이것은 일부 message가 Kafka partition log에서 중복되게 만들고, consumer가 같은 message를 여러번 받게 만든다.
3. The client can fail: Exactly-once delivery는 client failure도 고려해야한다. 하지만 어떻게 client가 fail났는지 아닌지 알 수 있는가? permanent failure와 soft failure를 구분해야 한다. correctness를 위해 zombie producer가 보낸 message는 버려야 한다. consumer도 마찬가지다. client instance가 새로 시작되면, failure났던 instance가 남긴 상태에서 복구하고, safe point에서 처리를 시작 할 수 있어야 한다. 이건 consumed offset이 언제나 produced output과 같이 동기화가 지속되어야 함을 의미한다

## Exactly-once semantcis in Apache kafka

Kafka는 3가지 방식을 도입해서 exactly-once semantic을 지원한다

### Idempotence: Exactly-once in order semanitcs per partition

producer send operation을 idempotent하게 만들었다. producer retry를 만드는 publish error는 kafka log에서 한번만 write되도록 만들었다. single partitioon에서 idempotent producer는 producer/broker error에 의해 발생될 수 있는 duplicate message의 가능성을 제거하는 요청을 던진다. 이 feature를 켜고 partition 단위 exactly-once semantic (중복 X, 로스 X, ordering)을 만드려면 producer에 `enable.idempotence=true` 를 설정하면 된다.

이 기능은 TCP와 비슷하게 동작한다. Kafka로 전달되는 message batch는 broker가 deduplicate 할 수 있는 sequence number를 가진다. in-memory connection에서만 보장해주는 TCP와 다르게, sequence number는 leader failure가 발생해도 replicated log에 남고, take over하는 다른 broker가 재전송건이 duplicate이어도 알수 있도록 한다. message batch에 numeric field만 추가했으므로 이 방식의 오버헤드는 작다. 밑에서 이 기능의 performance overhead가 작다는것을 보여줄것이다.

Tutorial: **[How to maintain message ordering and no message duplication](https://kafka-tutorials.confluent.io/message-ordering/kafka.html?_ga=2.167689079.817886826.1636457853-748245660.1635507512&_gac=1.229497070.1635507654.Cj0KCQjwt-6LBhDlARIsAIPRQcIFYNUkH8MZuu8htDUuTZVdxYjtmZ3HKlOoA1MO8C-aj0JyV7KWhDUaAgoeEALw_wcB)**

### Transactions: Atomic writes acrros multiple partitions

Kafka는 transaction API를 통해 multiple partitions에 걸쳐 atomic write를 지원한다. 이건 producer가 message batch를 multiple partition에 전송할 수 있게 해주어 batch의 모든 message는 모든 consumer에게 eventually visible하다(즉 전체다 보이던지, 전체다 안보이던지). 또한 consumer가 한 transaction에서 process한 data와 함께 consumer offset을 commit하게 해주어 end-to-end exactly-once semantic을 달성한다.

- [kafka-transactions.java](https://gist.github.com/nehanarkhede/6dd6f482c2091f36d2d55bd027ca6fc0##file-kafka-transactions-java)

```java
producer.initTransactions();
try {
  producer.beginTransaction();
  producer.send(record1);
  producer.send(record2);
  producer.commitTransaction();
} catch(ProducerFencedException e) {
  producer.close();
} catch(KafkaException e) {
  producer.abortTransaction();
}
```

위의 code는 producer API를 통해 message를 topic partition에 atomic하게 전송하는지 보여준다. Kafka topic partition에는 transaction에 속한 message, transaction에 속하지않은 message 둘다 존재할 수 있다.

consumer에서는 transactional message를 읽을 두가지 옵션이 있다

1. `isolation.level=read_commited`: transaction에 속한 messsage들은 commit되고난 후에 읽기
2. `isolation.level=reads_uncommited`: transaction이 commit되기를 기다리지 않고 message offset 순서에 따라 읽기

Transaction을 쓰기 위해서는 `isolation.level`설정하고, producer API에서 `transactional.id` 를 unique id로 설정해야 한다. unique id는 application restart에서도 transactional state를 지속시키기 위해 필요하다.

### The real deal: Exactly-once stream processing in Apache Kafka

idempotency, atomicity를 만들어서 exactly-once stream processing이 stream API를 통해 가능하게 했다. stream application에서 exactly-once semantic을 키려면 `processing.gurantee=exactly_once` 를 설정하면 된다. 이건 모든 Processing이 exactly-once로 일어나도록 만든다. processing과 Kafka에 의해 다시 만들어지는 모든 materialized state또한 exactly-once로 만들어진다.

exactly-once semantic은 Kafka stream internal processing에서만 보장된다. 만약 streams로 구현된 event streaming app이 다른 remote store에 update를 하거나, Kafka topic을 직접 R/W하는 customized client가 있다면 exactly-once를 보장하지 못한다. 디테일은 아래 블로그에 있다

**[Enabling Exactly-Once in Kafka Streams](https://www.confluent.io/blog/enabling-exactly-once-kafka-streams/)**

streaming processing system에서 "내 streaming processing application이 processing도중에 실패해도 원하는 답이 나오는가?"는 중요하다. failed instance를 복구할때 중요한것은 crash나기 직전과 같은 상태에서 재실행되는것이다.

stream processing은 Kafka topic에 대한 read-process-write밖에 없다. consumer는 Kafka topic으로부터 message를 읽고, message에 대해 processing을 하거나 state를 수정하고, producer는 다른 kafka topic으로 result message를 write한다. exactly-once stream processing은 reda-process-write operation을 정확히 한번만 수행하도록 해준다. "원하는 답"이란건 message loss도 없고, duplicated output도 없는 것이다. 이것이 유저가 exactly-once stream process에게 원하는 것이다.

다른 failure scenario또한 고려해야 된다. (이부분 좀 이해안됨 ㅜ 두개골 부딪혀봐야 알듯)

1. consumer는 multiple source topic으로부터 input을 받을 때.
여러번 재실행할때 source topic에 대한 순서는 non-deterministic하다. multiple source topic을 보는 consumer를 재실행한다면 이전과 다른 result를 만들 수 있다.
2. producer가 여러 topic에 publish할 때.
producer가 multiple topic에 atomic write를 할 수 없다면, 일부 partition에 write하는것을 실패할때 producer output또한 incorrect할 수 있다.
3. consumer가 streams API에서 제공하는 managed state를 이용해서 multiple topic의 data를 aggregate, join을 할 때.
consumer중 한개가 fail하면 state를 롤백할 수 있어야한다. instance를 restart할때 또한 prcoessing을 재시작하고 state를 다시 만들 수 있어야한다..
4. stream processor가 external database를 read하거나, 다른 서비스를 호출할 때.
external service에 때라 stream processor가 non-deteministic해질 수 있다. external service가 재실행 하기 전에 상태를 바꾼다면, incorrect result가 생길것이다. 하지만 external service가 잘 고려해서 동작한다면 모든 result가 incorrect하진 않을것이다.

특히 non deterministic operation과 같이 있고 application에의해 persistent state가 바뀌는경우엔 failure와 restart가 duplicate 뿐만 아니라 incorrect result도 만들 수 있다. 한 stage가 event count를 셀때, upstream stage에서 duplicate이 발생하는경우 incorrect count가 나올 것이다. 따라서 exactly-once stream processing은 모든 연산이 streams API를 쓰는것은 아니다. 일부는 애초부터 non-deterministic할 수 있다(external service를 쓰거나, multiple topic을 보거나..)

*deterministic operation을 보장하는 exactly-once stream processing 이란, "read-process-write operation의 output이 stream processor가 각 message를 failure없이 정확히 한번만 보는 것"과 같다는 것을 보장 하는 것이다.*

### Wait, but what's exactly-once for non-deterministic operations anyway?

non-deterministic operation에 대해서 exactly-once stream processing은 뭘까? event count를 세는 stream processor가 external service가 주는 조건에 만족하는 event count만 세는것으로 바뀌었다고 생각해보자. 이 operation은 external condition이 재실행 이전에 바뀔수 있으므로(external service가 조건을 다르게 바꿔버리면) 당연히 non-deterministic하고 다른 result를 만들 수 있다.

*non-deterministic operation에 대한 exactly-once 보장은, read-process-write stream processing operation의 output이 non-deterministic input에서 가능한 value의 조합에 의해 생성되는 output의 subset에 있음을 보장하는것이다. (수능영어문제같은번역ㅈㅅ)*

external service로부터 받은 condition에 따라 event count를 세는 stream processor에서 현재 count가 31이고, input에 2가 들어왔다면, 장애 상황 이후에 재실행될때 output은 {31, 33} 중 한개여야 한다. 31은 input event가 external condition에 의해 버려졌을 경우인거고, 33은 버려지지 않았을때 이다.

이 문서는 Streams API에서 exactly-once stream processing의 일부만을 다루기때문에 더 많은 디테일을 보고싶으면 아래 문서를 봐라 (두번째 강조중..)

**[Enabling Exactly-Once in Kafka Streams](https://www.confluent.io/blog/enabling-exactly-once-kafka-streams/)**

## Exactly-once guarantees in Kafka: Does it actually work?

Kafak의 exactly-once 보장에 대해 correctness(design, implement, test), performance를 보겠다.

### A meticulous design and review process

correctness, performance는 견고한 디자인에서 시작된다. confluent는 1년동안 idempotence와 transactional requirement를 package에 붙이기위해 노력했다. high-level의 message flow에서부터, 모든 data structure, RPC에 대한 핵심적인 구현디테일까지 모든 면을 설명하는 60페이지 이상의 design doc을 작성했고, 9개월동안 피드백을 받았다. open source discussion에서 transactional read에 대한 consumer-side buffering을 최적화하기도했고, compacted topic이나 security feature등을 추가했다.

그 결과, 견고한 Kafka primitive를 기반에 둔 단순한 디자인을 만들었다.

1. transaction log는 kafka topic이고 durability도 보장해준다
2. producer단위로 transaction state를 관리하는 *Transactional coordinator*는 broker와 같이 실행되고, failover를 위해 Kafka의 leader election algorithm을 사용한다.
3. Kafka Streams API를 사용하는 stream processing application은, state store와 input offset에 대한 source of truth가 kafka topic이라는 것을 활용한다. 따라서 여러 partition에 atomic write하는 transaction에 data를 **transparently fold**(어캐 해석해야할지몰겠다..) 할 수 있으므로, read-process-write operation에 대해 exactly-once를 보장한다

### An iterative development process

는 생략

### The good news: Kafka is still fast!

exactly-once 를 디자인할때 가장 집중했던건 성능이었다. 유저들이 몇 안되는 usecase뿐만아니라 일반적인 케이스에서도 exactly-once를 쓸수있고, default가 exactly-once가 되기를 원했다. 더 단순한 다른 디자인들은 성능 이슈로 제외되었다. 최종적으로 트랜잭션단위의 작은 오버헤드를 만드는 디자인을 결정했다. (partition당 최대 1번의 write, central transaction log에 추가되는 몇개 레코드)

현재 exactly-once 성능은 1KB message와 transaction이 100ms일때,

- at-least-once, in-order delivery(`acks=all, max.in.flight.requests.per.connection=1`) 일때와 비교해서 3%의 성능하락
- no ordering(`acks=1, max.in.flight.requests.per.connection=5`) 대비 20%성능 하락

idempotence도 producer 성능에 아주작은 영향만 보였다. ([results of our benchmarking, our test setup, and our test methodology](https://docs.google.com/spreadsheets/d/1dHY6M7qCiX-NFvsgvaE0YoVdNq26uA8608XIh_DUpI4/edit##gid=282787170))

또한 Streams API를 쓰는 exactly-once stream processing의 오버헤드도 확인했다. commit interval은 100ms (end-to-end latency가 낮아야한다는 가정)일때 성능은 message size에따라 15~30% 하락했다. message size가 작을수록 오버헤드가 크다. commit interval이 길어질수록 overhead는 줄어들었다.