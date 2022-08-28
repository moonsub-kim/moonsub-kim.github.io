---
title: S3 Multipart Upload와 PyArrow를 이용해서 고정된 스키마를 가지는 Parquet 파일 생성
parent: 글
last_modified_date: 2022-08-28
has_children: false
nav_order: 2
---

# S3 Multipart Uploade와 PyArrow를 이용해서 고정된 스키마를 가지는 Parquet 파일 생성

## S3 Multipart Upload
종종 Airflow 워커로 datalake 바깥의 소스로부스 데이터를 긁어와서 S3 object로 저장해야하는 경우가 생긴다.
이런 상황에서 데이터 볼륨이 작으면 워커에커 충분히 처리가능한데, 볼륨이 크게되면 워커 메모리를 늘리거나, S3 object를 여러개 쪼개는 방식을 고려할 수 있다.

하지만 위 케이스들은 각각 단점이 생긴다.
워커 메모리를 늘리는건 관리가 쉽지 않다.
각각 데이터 볼륨에 맞추어서 튜닝을 해줘야 하는데, 많은 종류의 데이터에 대해 같은 형태의 태스크를 수행시킨다면,
어떤 데이터는 시간이 지날수록 퍼가야 하는 데이터 볼륨이 많아져 계속 메모리를 증가시켜줘야하고, 볼륨이 적어지게되면 실제 사용하는 메모리보다 훨씬 더 많은 양의 메모리를 요청해놔야 하므로 비효율적이 된다.
또한 S3 object를 여러개로 쪼개는것은 나중에 데이터를 읽어갈때 S3에 더 많은 request를 날리게 되어 쓰로틀링이 걸릴 수도 있다.
S3 쓰로틀링 외에도 Athena 에서는 object 수가 많아질 수록 쿼리 런타임도 증가하게 된다.

이런 케이스에선 S3에서 제공하는 multipart upload를 쓰면 된다.
위 케이스 말고도, AWS 문서에 multipart upload를 쓰면 좋은 케이스들을 나열해놨다.

## PyArrow
풀어야 할 문제가 또 있다. Pandas를 이용해서 parquet file을 만들고 있었는데, Pandas는 데이터 타입에 대해 강제할수가 없다.
예를들어 pandas dataframe의 한 컬럼에 Decimal(10.01), Decimal(10.1)를 가지는 레코드 두개각 들어있으면, 이걸 parquet file로 만들었을때 해당 컬럼의 타입은 DECIMAL(4, 2) 이 된다.
그리고 다른 pandas dataframe에서 Decimal(10.0001)이 들어있는걸 parquet file로 만들면 DECIMAL(6, 4) 가 된다.
즉, pandas는 실제 데이터가 들어오는것을 보고 그에 맞춰서 데이터 타입이 동적으로 결정된다.
하지만 S3 object를 읽는 Athena는 parquet file을 읽을 때 고정된 Decimal type을 써야한다.
스키마를 DECIMAL(6, 4)로 설정하면, parquet file의 데이터 타입이 DECIMAL(4, 2)로 되어있을 경우 읽지 못한다.
고쳐주면 좋겠지만 .. 애초에 pandas에서 고정된 데이터 타입을 정의할 수 있으면 깔끔하게 해결할 수 있는것같다.

위 문제를 해결해주는 것이 PyArrow이다. 