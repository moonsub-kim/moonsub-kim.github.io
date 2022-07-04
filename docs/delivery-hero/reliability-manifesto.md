---
title: "The Delivery Hero Reliability Manifesto"
parent: Delivery Hero
last_modified_date: 2022-07-03
nav_order: 0
description: "Delivery Hero CTO가 작성한 [The Delivery Hero Reliability Manifesto](https://tech.deliveryhero.com/our-reliability-manifesto/) 를 번역한 글 입니다."
---
{{ page.description }}

# The Delivery Hero Reliability Manifesto

![thumbnail](https://techdhstaging.wpengine.com/wp-content/uploads/2021/10/Delivery-hero-manifesto-dg.jpeg)

Delivery Hero는 초당 1000건의 transaction을 처리하는 payment system을 만드는 것 등의 복잡한 문제를 대규모로 해결한다.

Delivery Hero는 아래 세가지가  매일 천만개에 가까운 주문을 처리하는데 어려움을 만든다.

1. Delivery Hero의 피크 타임은 일요일 저녁인데, 당연히 tech team도 노트북을 만지지 않고 저녁을 먹기를 좋아한다. (문제생기면 어쩔수없이 일하겠지만 기본적으로는 밥먹는 시간임)
2. 음식이 빨리 식기때문에 문제를 해결하기 위해 주어지는 시간은 몇분정도 밖에 되지 않는다.
3. 만약 예측한대로 동작하지 않는다면, Delivery Hero는 수백만개의 가게가 손실을 얻고, 수많은 소비자가 배고프게 된다.

이에 더해 Delivery Hero는 지난 몇년동안 엄청나게 성장해서(일부 국가에서는 전년대비 10배이상 성장), 시스템의 대부분을 no-sql, async, 새 서비스로 rearchitect할 수밖에 없었다.

Delivery Hero는 이 모든것을 infra team 없이 분산된 방식으로 일했다. 그대신 올바른 일을 하기 위해 squad나 domain, tribe등에 걸쳐 수백명의 tech leader에 의존했다. 근데 올바른 일을 하는 것이 뭘까? C++ programmer로 일하던 나의(CTO 본인) 주니어 시절이 생각난다. 시스템을 crash시키는 null pointer dereferencing 같은 많은 함정을 피해야 했다. 그때 나는 109개의 룰이 포함된 “C++ Coders Practices”라는 문서를 받았다.

Delivery Hero에서도 비슷하게 tech leader가 “올바른 일을 하도록" 만들어주기 위해 “Delivery Hero Reliability Manifesto”라는 문서를 만들었고, 문서가 여러번의 수정을 거쳐 완성도가 높아졌으므로, 더 많은 사람들에게 유용하게 쓰일 것 같아 공유하기로 하였다.

Manifesto는 reliable system을 만들기 위해 필요한 것에 대한 현재 생각을 반영한 rule, guideline, best practice의 모음이다. Manifeseto는 Deliver Hero가 High reliability를 달성하기 위한 스토리의 일부분이다. Manifesto 말고도 High reliability를 달성하는데에는 아래와 같은 노력이 필요했다.

- 똑똑한 사람들이 참여해서 Manifesto같은 문서들을 같이 작성한다.
- 계속 토론하고 문서 수정을 거쳐 새롭게 배운 내용을 문서에 붙인다.
- 배운것들을 각 서비스에 적용한 Reliability score로 변환하여 인센티브를 제공한다.
- failure에서 배운것과 성공을 celebrate하는 weekly operations meeting을 한다.
- 기술 부채를 추적하고 최종적으로(eventually) 없애나간다.
- 함께 산을 옮길 수 있는 똑똑하고 실용적인 접근을 하며 배려할줄아는 다양한 그룹의 엔지니어를 채용한다.

# Delivery Hero Reliability Manifesto

## Meta Rule

**M-1** 이 Manifesto를 몰래 위반하는 것 대신 룰을 변경하기 위한 토론을 하자.

**M-2** 우리는 이 문서의 룰이 유효한지 1년에 2번 평가한다.

## Architecture & Technical Debt

**A-1 *We document arhictecture***: 모든 서비스와 서비스의 디펜던시는 architecture chart에 문서화되고, 우리의 아키텍처 가이드라인(원문에서 공개하지 않았음)의 컨벤션을 따른다.

**A-2 *We care about naming***: 모든 서비스는 모호하지 않고 이해하기 쉬운 이름을 써야 한다.

**A-3 *We start with a monolith***: 빠르게 움직이기 위해 [Monolith first pattern](https://martinfowler.com/bliki/MonolithFirst.html) 을 따르고, 요구사항에 대해 더 이해하게 되면 sub-service로 쪼갠다.

**A-4 *We embrace microservice principles***: 새 서비스는 아래 내용을 따라야 한다.

- API나 message로 통신해야 한다.
- 다른 서비스와 Data storage를 공유해선 안된다.
- 서비스는 technical component가 아니라 product domain(bounded context)의 일부가 되어야 한다.
- Single Responsiblity Principle을 따라야 한다.
- 한 squad에서만 소유해야 한다.
- 2개 서비스보다 더 긴 synchronous call-chain을 피해야 한다.
- Incident로부터 복구하는 시간을 줄이기 위해 서비스의 상태, 행동을 관찰할 수 있는 데이터와 툴을 이용해야 한다.
- 서비스의 overhead를 정당화 할 수 있도록 (network latency를 가지는데도 불구하고 서비스로 분리되어야 할 이유), 서비스가 충분한 크기를 가져야 한다.
- data consistency guarantee(at-least-once 같은)를 전달한다. (exactly-once서비스와 엮이면 exactly-once를 보장해야 한다는건가..?)

**A-5 *We embrace the data mesh***: Data producer는 공통 data platform으로 사용하는 Datahub([google cloud의 Delivery Hero customer 소개](https://cloud.google.com/customers/delivery-hero)를 보면 Analytics Hub를 말하는듯 함)에 [product의 domain data](https://martinfowler.com/articles/data-monolith-to-mesh.html#DomainDataAsAProduct) 를 퍼블리쉬 해야하고, 아래 내용들을 보장해야 한다. (datahub에 document를 쓸때의 룰인듯 함)

- Discoverable
- Addressable
- Trusthworty and truthful
- Self-describing semantics and syntax
- Inter-operable and governed by global standards
- Secure and governed by a global access control

**A-6 *We review architecture***: 새 서비스는 tribe, vertical tech lead가 참석하는 [technical design review](https://medium.com/git-out-the-vote/strengthening-products-and-teams-with-technical-design-reviews-ae6a1bec5216) meeting을 패스해야 한다. tribe tech lead는 2년마다 전체 아키텍처를 공유한다. 위 두 미팅은 모든 사람이 참석가능하다.

**A-7 *We know our debt***: 분기마다 techincal debt를 추적한다.

**A-8 *We are cloud native***: 가능하다면 self-hosting보다 managed service를 선택한다.

**A-9 *We minimize critical things***: 서비스가 배달 주문을 처리하기위한 critical path에 포함되는것을 최대한 피한다. critical service에 있는 non-critical component를 다른곳으로 옮겨 lean하게 유지한다.

**A-10 *We document decisions***: [RFC](https://en.wikipedia.org/wiki/Request_for_Comments)와 [Architecture Decision Record](https://github.com/joelparkerhenderson/architecture_decision_record)를 써서 중요한 architectural decision에 컨텍스트와 결과를 같이 문서화한다.

**A-11 *We love well defined APIs***: 다른 팀을 위해 모든 API를 문서화하고 API library에 문서를 퍼블리쉬한다.

## Delivery

**D-1 *We deploy every day***: 우리의 목표는 엔지니어가 하루에 최소 한번의 production deploy를 하는 것이다.

**D-2 *We track deployments***: 모든 배포는 deployment events로 트래킹 가능해야 한다.

**D-3 *We are open 24/7***: 모든 서비스는 zero-downtime deployment를 지원해야 한다. 피크타임이나 [금요일 배포](https://charity.wtf/2019/05/01/friday-deploy-freezes-are-exactly-like-murdering-puppies/)도 안전하게 동작해야한다.

**D-4 *We deploy with a safety-net***: 모든 Tier 1 서비스는 자동화된 canary deployment를 지원해야 한다.

**D-5 *Our infrastructure is code***: 모든 인프라는 repository에 code로 configure되어야 하고, CI/CD pipeline을 통해 변경사항이 반영되어야 한다.

**D-6 *We automate testing***: production code가 60~80%의 unit test coverage를 가지고, main application flow는 integration test로 커버되어야 한다.

**D-7 *We never code alone***: 새로 만들거나 복잡한 코드는 페어 프로그래밍으로 해결한다. 모든 production code 변경은 코드 리뷰를 거친다.

## Resilience

**R-1 *We limit risk***: 비즈니스의 10% 이상(GMV 기준)을 차지하는 국가는 dedicated resource에서 critical service를 운영한다.

**R-2 *We don’t treat things equally***: 모든 서비스는 아래 Tier중 하나에 할당된다.

1. Tier 1: unavailability가 발생한지 첫 30분동안 전체 비즈니스의 20% 이상에 영향을 미치는 코어 서비스와 주문을 처리하는데 필요한 모든 서비스.
2. Tier 2: downtime으로 수익 손실(광고)이나 비용증가 등의 영향을 미치는 서비스.
3. Tier 3: 유저 경험에 영향을 미치는 서비스
4. Tier 4: 나머지 내부 서비스

**R-3 *Our services degrade gracefully***: Tier 1, 2의 서비스는 dependency failure에서도 문제가 생기면 안되고, 이런 degraded mode일땐 fallback(default behavior)이 동작해야한다.

**R-4 *We design for failure***: 아래 방어 로직을 구현한다.

1. **Timeout**: 충분한 wait interval이 지나면 결과가 너무 늦게나오거나 sucess return이 올 가능성이 낮다.
2. **Retry**: 많은 fault는 일시적이고 잠시 뒤에 알아서 고쳐질 것이므로 cascading failure를 피하기 위해 exponential backoff와 jitter를 쓴다.
3. **Circuit Breaker**: 시스템이 심각한 상태면 client가 기다리지 않고 빠르개 실패시켜 critical resource에 장애가 나지 않도록 하는 것이 낫다.
4. **Fallback**: 계속 실패가 발생할때를 대비한 처리 로직을 만들어야 한다.
5. **Throttling**: 이상하게 동작하는 client가 서비스를 중단시키는것을 막아야한다.
6. **We prepare for rapid growth with ongoing load-tests**: 급격한 비즈니스 성장에도 서비스는 버틸 수 있어야 한다.
7. **Idempotence**: 여러번의 identical request는 서비스에 한번만 반영되어야 한다.
8. **Recoverable**: downstream service failure에도 복구를 위해 message replay를 할 수 있어야 한다.
9. **Dead-letter queues**: Erroneous message는 valid message의 처리를 막아선 안되고, 추후 분석을 위해 DLQ로 들어가야 한다.

**R-5 *We test for failure***: Tier 1, 2서비스는 dependency failure 상황도 테스트 해야한다. Synchronous failure는 no response, slow response, error response, unexpected response(bad JSON등등)를 테스트하고, Asynchronous는 중복이나 out of order같은 케이스도 같이 테스트 해야한다.

**R-6 *We track the [golden signals](https://sre.google/sre-book/monitoring-distributed-systems/#xref_monitoring_golden-signals)***: 모든 팀은 최소한 system health와 연관된 requests per minute, error rate, server response time, business metric을 보여주는 real time dashboard를 만들어야 한다.

**R-7 *We are the first to know about problems***: critical threhold를 넘으면 모든 관련된 metric은 alert을 발생시켜야하며, alert과 metric design은 architecture review에 포함되어야 한다.

**R-8 *We log in a central location***: 모든 로깅은 공통된 컨벤션으로 한곳에 쌓여야 한다. 로깅 비용을 인지하고 어떤 것이 로그로 남아야하는지에 대한 의미있는(conscious) 결정을 내려야 한다.

**R-9 *We prepare for rapid growth with ongoing load-tests***

1. Scale: 저번 주 peak requests per minutes을 기준으로, 평균 부하로 시작해서 1분이내에 peak request의 3배, 30분이내에 4배까지도 버틸 수 있는지 확인한다.
2. Frequency: 격주에 한번은 수행한다.
3. Quality: write operation을 포함한 실제 요청 패턴을 사용한다.
4. Envrionments: 가능하다면 Production에서 load test를 수행한다.
5. Expectation: server response time, error rate이 accetable level 이내로 유지되면 load test는 성공한 것이다.

**R-10 *We agree on error budgets***: incident로 인한 주문 손실에 대해 0.1%까지의 error budget을 준다. 이 중, platform에 0.05%, global service에 0.05%를 할당한다. 매월 실제 수치와 budget을 확인한다.

**R-11 *We cancel noise***: public API의 최대 error rate은 매일 평균 0.01%까지 허용한다.

**R-12 *We speed things up with runbooks***: 이슈를 분석하고 재현하는 방법을 런북으로 만들고 alert과 연결해서 복구시간을 최소화한다.

**R-13 *We prepare for chaos***: 서비스는 모든 dependency를 문서화하고 dependent service failure에대한 mitigation strategy를 만들어야 한다. 또한 정기적으로 중요한 서비스들을 테스트한다.

**R-14 *We don’t rely on compute-instances***: compute-instance는 언제나 시스템에 영향을 미치지 않고 kill될 수 있어야 한다.

**R-15 *We survive availability zone outage***: AZ outage가 발생해도 서비스는 동작해야 한다.

**R-16 *We can recover from disasters***: 모든 data는 long term cloud storage에 최소 30일의 retention으로 암호화된 상태로 저장된다. Tier 1, 2 서비스는 2시간 이내에 재해로부터 복구되는것을 보장해야한다.

## Continuous Improvement

**C-1 *We track all incidents***: Critical incident는 statuspage(검색해도 안나옴..)에 리포팅되고 업데이트 되어야 한다. 모든 incident는 tracking sheet(어떻게 관리하는지 궁금..)로 관리되어야 한다.

**C-2 *We learn from our mistakes***: Critical incident는 template에 맞춰 post-mortem으로 작성되어야 하고 statuspage에 게시되어야 한다. 또한 Incident는 weekly stablity review meeting에서 리뷰해야 한다.

**C-3 *We go to WOR(Weekly Operational Review)***: Weekly Operational Review동안 시스템의 안정성과 보안을 향상시켜야 한다. Incident로부터 배운 것, 잘 한것, 비즈니스/기술적인 업데이트를 공유하고, 한 squad(랜덤픽)를 골라 아래 내용을 공유한다.

1. 자신과 팀이 하는일에 대한 소개
2. 서비스의 Architecture chart를 보여주고 critical한 서비스 소개
3. 최근 3개월간 중요한 Incident와 여기서 배운 것을 공유
4. Monitoring dashboard(Requests per minute, Error rate, Server response time, business metrics) 공유
5. 어떻게 load test를 수행하는지, peak RPM기준으로 몇배까지 안정적으로 견딜 수 있는지 공유
6. 문제가 될 수있는 가장 중요한 부분 3개와 각각을 어떻게 대응할건지 공유

**C-4 *We share our code***: 모든 팀은 Delivery Hero의 모든 코드에 기여할 수 있다.

**C-5 *We don’t point fingers***: 문제가 발생하면 소매를 걷고 문제 해결을 돕는다.

**C-6 *We foster honest and open communication***: 투명하고 사실에 개반한 토론을 하며 가장 좋은 주장이 채택되어야 한다.

**C-7 *We like diversity of people and ideas***: 모든 발언은 중요하다.

**C-8 *We assume good intentions***: 모든 텍스트 커뮤니케이션에는 언제나 선의를 주려는 의도가 있음(charitable)을 생각하며 이해하라.

## Security

**S-1 *Security is not optional***: 최선을 다해 시스템과 데이터를 보호하고 security dashboard rating 꾸준히 개선한다.

**S-2 *We block attackers at the edge***: 모든 customer-facing DNS entry는 Cloudflare로 보호되어야 한다. (Inter-service communication도 보호되어야하는데.. 내용이 잘려있음).

**S-3 *We limit our attack surface***: Internal tool, back-office, infrastructure는 public internet으로 direct access 할 수 없도록 해야 한다.

**S-4 *We control access in one place***: 모든 back-office는 OpsPortal로 통합되어야하고 identity, role management를 위해 DH IAM service를 사용해야 한다.

**S-5 *We lock away our secrets***: 모든 secret은 vault soultion ([Vault](https://www.vaultproject.io/) 권장)으로 관리되어야하며 github에 secret을 절대 저장하지 않는다.

**S-6 *We simulate attacks***: DH security team이 1년에 두번 penetration test를 수행할수 있도록 public API를 가진 service를 알려준다.

**S-7 *We respect privacy***: GDPR requirements에 맞출 수 있도록 개인정보를 처리한다.

1. 개인정보를 적법하게, 공정하게, 투명하게 처리한다.
2. 처음부터 필요한 정보만 한정하여 개인정보 수집을 최소화 한다.
3. 개인정보를 특정한 목적으로 사용하는것을 제한한다.
4. pseudonimyzation, anonymization을 통해 개인 식별을 하지 못하게 한다.
5. 최신의 기술을 사용해 개인정보의 confidentiality, integrity, availability를 보장한다.

**S-8 *We gamify security***: 옳은 행동을 각 팀의 성과로 반영하기 위해 security score table을 만들고 공개한다.

## Peformance & Cost Efficiency

**P-1 *We don’t waste time***: 모든 서비스는 95%의 요청을 150ms이내에 처리해야 한다.

**P-2 *We make cost visible on squad level***: Cloud resoure, observability tool, data processing에 대해 squad/service level로 resource tagging을 한다. 모든 squad는 weekly cost를 모니터링해야 한다.

**P-3 *We leverage economies of scale***: 우리 시스템이 주문 수가 늘어날 수록 cost per order는 감소하도록 만들어야 한다. 분기단위로 cost per order가 10%씩 내려가는 트렌드가 보이면 좋다.

**P-4 *We are frugal with logging***: Observability cost는 전체 cloud cost의 15%를 넘으면 안된다.

## Elite Level Rules

**E-1 *We are spot on***: 전체 서비스의 최소 80%는 spot instance로 운영한다.

**E-2 *We don’t mind disasters***: underlying infrastructure(database 삭제나 region down, etcd 문제 등)에서 재해가 발생한 경우에도 downtime은 없어야 한다.

**E-3 *We kill our mutants***: Unit test quality를 검증하기 위해 mutation testing을 수행한다.

**E-4 *We only trust what is tested***: Performance, security testing을 CI/CD pipeline에 붙인다.

**E-5 *Every microseconds counts***: 서비스간 통신에 gRPC/Protobuf protocol을 사용한다.

**E-6 *We trust each other***: Trunk based development를 이용해 pair programming, collective code ownership을 가지도록 하고 팀 내의 code visibility를 높인다.

**E-7 *We know our metrics***: lead time(개발시작부터 production 배포까지 소요되는 시간), 배포 빈도, 복구 시간과 복구시간동안 실패비율을 모니터링한다.