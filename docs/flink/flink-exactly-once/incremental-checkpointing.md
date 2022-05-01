---
title: Incremental Checkpointing
parent: Flink Exactly-Once
grand_parent: Flink
last_modified_date: 2021-12-26
nav_order: 2
description: "[Managing Large State in Apache Flink: An Intro to Incremental Checkpointing](https://flink.apache.org/features/2018/01/30/incremental-checkpointing.html) 을 번역한 글 입니다."
---
{{ page.description }}

# Incremental Checkpointing

state는 복잡한 usecase에서 필요하다. 하지만 stateful stream processing은 state가 faul-tolerant할때만 production에서 쓸 수 있다. Fault tolerance는 software,machine failure에서도 end result는 정확히 나오고, data loss와 duplicate이 없음을 의미한다.

일부 Flink user는 GB,TB 크기의 application state를 가진다. 이 유저들은 large state에서 checkpointing이 느리고, resource-intesive operation이라고 리포트했다. 이 리포팅은 Flink가 incremental checkpointing을 만드는 계기가 됐다.

incremental checkpointing 이전에 모든 single Flink checkpoint는 application의 모든 state를 가지고 있었다. 하지만 한 checkpoint에서 다음 checkpoint로 상태변화가 큰 경우가 드물기 때문에, 모든 checkpoint에 대한 full state를 생성하는것이 불필요하다는것을 알게되었고, incremental checkpoint를 만들게 되었다. incremental checkpointing은 각 checkpoint 사이의 delta를 유지하는것 대신 마지막 checkpoint와 현재 state를 저장한다.

incremental checkpoint는 large state를 가지는 job에서 큰 퍼포먼스 향상을 보였다. TB 크기의 state를 테스트한 결과 3분이 걸리는 checkpointing 시간이 incremental checkpoint에서는 30초로 줄어들었다.

## How to Start

Flink는 RocksDB의 internal bakcup mechanism을 활용하므로 RockDB state backend에서만 incremenal checkpointing을 지원한다. 따라서 Flink의 incremetnal checkpoint history는 무한정 커지진 않고 eventual하게 checkpoint들을 consume/prune한다.

## How it Works

RocksDB는 모든 변경사항을 memtable이라 불리는 mutable(changeable) in-memory buffer에 수집하는 LSM tree를 기반으로하는 KV store이다. memtable에서 같은 key에 대한 update는 이전값을 replace하고, memtable이 꽉차면 RocksDB는 key로 정렬, compression 이후 disk로 모든 entry를 write한다. RocksDB가 memtable에서 disk로 write하면 immutable(unchangeable) 해지고, sorted-string-table(sstable) 이라고 부른다.

**compaction** background task는 각 key에 대한 potential duplicates를 통합하기 위해 여러 sstable을 합치고, 시간이 지나면서 RocksDB는 original sstable을 제거하고, merged sstable에 다른 모든 sstable의 정보가 포함되게 된다(한개로 merge).

Flink는 이전 checkpoint 이후로 어떤 sstable file이 생성/삭제 됐는지 추적하고, sstable을 통해 state change를 알아낸다. 이를 위해 Flink는 RocksDB에 flush를 호출하여 모든 memtable이 sstable로 write되도록 강제하며, local temporal directory와 hard-linked된다. 이 과정은 stream processing pipeline과 synchronous하고, Flink는 모든 추가적인 스텝을 asynchronous하게 수행하고 stream processing을 블로킹하지 않는다. (여기서 추가적인 스텝은 뭔가..)

그 다음 Flink는 새로운 checkpoint에서 참조할수 있도록, 새로 생긴 sstable들을 stable storage로 복사한다. Flink는 이전 checkpoint에서 이미 존재하던 sstable은 copy하지 않는다(물론 이전 checkpoint에서 write했으므로 참조할수는 있다). 새로운 checkpoint는 삭제된 file (RocksDB에서 compaction과정에서 삭제된 old sstable)을 더이상 참조하지 않아 eventual하게 sstable은 교체된다. 이 것이 Flink incremental checkpoint가 checkpoint history를 제거하는지에 대한 설명이다.

checkpoint간 변경사항을 tracking하기 위해, consolidated table을 upload하는건 redundant하다(new sstable이 이미 올라가있으므로?). Flink는 이 process를 incremental하게 수행하고, 작은 오버헤드가 생긴다.

## An Example

![incremental checkpointing](https://flink.apache.org/img/blog/incremental_cp_impl_example.svg)

keyed state를 가지는 한 operator의 subtask와, \# of retained checkpoint를 2로 설정한 예시이다.

checkpoint `CP 1` 에서 local RocksDB directory는 2개의 sstable을 가지고, 이 파일을 새 파일로 보고, checkpoint name을 directory name으로 쓰고 distributed file system에 업로드한다. checkpoint가 끝나게 되면 Flink는 shared state registry에 2개 entry를 만들고 count를 1로 설정한다. shared state entry의 key는 operator, subtask, sstable file name의 조합이고, registry에서는 key로 DFS file path를 매핑하고 있다.

checkpoint `CP 2` 에서 RocksDB는 2개의 새 sstable을 생성하고 기존에 있던 2개는 계속 존재한다. Flink는 새 파일들을 DFS에 업로드한다(또한 이전2개 파일을 참조할 수 있다). checkpoint가 끝나면 shared state registry에서 count를 올린다.

checkpoint `CP 3` 에서 RocksDB compaction은 `sstable-(1), sstable-(2), sstable-(3)` 을 `sstable-(1,2,3)` 으로 합친 후, 이전 파일을 삭제한다. merged file은 이전 파일에서 중복제거된(KV store이므로) 파일이 된다. 또한 `CP 3` 에서 `sstable-(4)` 는 계속 존재하고, `sstable-(5)` 가 새로 생기고 DFS로 올라간다. `sstable-(4)` 는 `CP 2` 에서 참조하고, referenced file의 count를 증가시킨다. \# of retained checkpoint 값이 2이므로 `CP 2, CP 3` 만 유지할수 있기 때문에 `CP 1` checkpoint는 삭제된다. 삭제과정에서 Flink는 `CP 1`에서 참조한 reference count를 decrease한다.

`CP 4`에서 RocksDB는 `sstable-(4), sstable-(5), sstable-(6)` 을 `sstable-(4,5,6)` 으로 합친다. `sstable-(6)` 은 `CP 4` 에서 새로 생긴 sstable이다. Flink는 이 새 table을 DFS에 올리고, `sstable-(1,2,3)`과 함께 reference한다 (DFS에 한다는건가..?). 또한 reference count를 올리고, \# of retained checkpoint에 따라 `CP 2` 를 제거한다. `sstable-(1), sstable-(2), sstable-(3)` 의 count는 0이 되었으므로 DFS에서 제거한다.

## Race Conditions and Concurrent Checkpoints

Flink는 여러 checkpoint를 parallel하게 실행할 수 있으므로, 이전 checkpoint가 완료되기 전에 새 checkpoint가 시작 될 수 있다. 이것때문에 새 incremental checkpoint의 basis로 사용할 previous checkpoint를 고려해야 한다 (즉 CP4를하려는데 CP3은 없을 수 있음). Flink는 실수로 삭제된 shared file을 참조하지 않도록 checkpoint coordinator가 confirm한 checkpoint가 가진 state만 참조한다.

## Restoring Checkpoints and Performance Considerations

incremental checkpoint를 키면 failure시에 state recovery에 대해 추가적인 configuration이 필요없다. failure가 발생하면 Flink의 JobManager는 마지막으로 완료된 checkpoint에서 restore하도록 모든 task에 요청을 보낸다. 각 TaskManager는 DFS의 checkpoint에서 state를 받아오게 된다.

이 feature는 large state를 가지는 user의 checkpoint time을 개선할 수 있지만, tradeoff가 있다. 이 process는 정상적인 상황에서는 checkpoint 시간을 줄이지만, state size에 따라 recovery time이 증가할 수 있다. 만약 cluster failure가 있고, Flink TaskManager가 여러 checkpoint에서 읽어야 하는경우 full checkpointing보다 recovery time이 오래 걸릴 수 있다. 또한 새 checkpoint가 old checkpoint를 참조하게되면 old checkpoint를 지우게 될 수 없어 checkpoint간 diff history는 시간이 지나면서 무한하게 커질 수 있다. checkpoint를 유지하기 위해 더 큰 distributed storage를 필요로 하고, network overhead도 고려해야 한다.

이와같은 tradeoff를 맞추는 전략은 flink doc에 디테일하게 써져있다

[Checkpoints](https://nightlies.apache.org/flink/flink-docs-release-1.14/docs/ops/state/checkpoints/)

[Tuning Checkpoints and Large State](https://nightlies.apache.org/flink/flink-docs-release-1.14/docs/ops/state/large_state_tuning/)
