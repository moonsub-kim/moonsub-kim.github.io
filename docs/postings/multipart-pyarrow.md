---
title: S3 Multipart Upload와 pyarrow로 고정된 스키마를 가지는 Parquet 파일 생성
parent: 글
last_modified_date: 2022-08-28
has_children: false
nav_order: 4
---

# S3 Multipart Upload와 pyarrow로 고정된 스키마를 가지는 Parquet 파일 생성

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

## pyarrow
풀어야 할 문제가 또 있다. Pandas를 이용해서 parquet file을 만들고 있었는데, Pandas는 데이터 타입에 대해 강제할수가 없다.
예를들어 Pandas dataframe의 한 컬럼에 Decimal(10.01), Decimal(10.1)를 가지는 레코드 두개각 들어있으면, 이걸 parquet file로 만들었을때 해당 컬럼의 타입은 DECIMAL(4, 2) 이 된다.
그리고 다른 Pandas dataframe에서 Decimal(10.0001)이 들어있는걸 parquet file로 만들면 DECIMAL(6, 4) 가 된다.
즉, Pandas는 실제 데이터가 들어오는것을 보고 그에 맞춰서 데이터 타입이 동적으로 결정된다.
하지만 S3 object를 읽는 Athena는 parquet file을 읽을 때 고정된 Decimal type을 써야한다.
스키마를 DECIMAL(6, 4)로 설정하면, parquet file의 데이터 타입이 DECIMAL(4, 2)로 되어있을 경우 읽지 못한다.
고쳐주면 좋겠지만 .. 애초에 Pandas에서 고정된 데이터 타입을 정의할 수 있으면 깔끔하게 해결할 수 있는것같다.

위 문제를 해결해주는 것이 pyarrow이다. PyArrow는 원래 columnar access를 위해 사용하는 Apache Arrow의 파이썬 라이브러리이다.
하지만 columnar layout 말고도 타입을 정의하고 parquet file로 저장할 수 있다.
(Pandas에서도 pyarrow를 쓰도록 할 수 있는데, Pandas를 쓰게되면 PyArrow가 제공해주는 타입정의 사용불가능해보였다.)

```py
import pyarrow as pa

schema: pa.Schema = pa.schema(
    [
        pa.Field("id", pa.int64()),
        pa.Field("name", pa.string()),
        pa.Field("created_dttm", pa.timestamp('us')), # parquet에서 nanosecond timestamp는 deprecate되었음. https://issues.apache.org/jira/browse/ARROW-1957
        pa.Field("cost", pa.decimal128(18,10)),
        # 이외의 data type은 https://arrow.apache.org/docs/python/api/datatypes.html
    ]
)
```

위와같이 스키마를 정의해두고 아래처럼 데이터를 넣으면 된다
```py
t: pa.Table = pa.Table.from_pylist(
    [
        {"id": 1, "name": "name1", "created_dttm": datetime.now(), "cost": Decimal(10.0)},
        ...
    ],
)
```
`from_pylist` 말고도 pyarrow table을 생성하는 다른 방법들은 [pyarrow.Table](https://arrow.apache.org/docs/python/generated/pyarrow.Table.html)을 보면 된다.

## pyarrow table을 s3 multipart를 이용하여 parquet file로 업로드

pyarrow는 file을 저장할 수 있도록 도와주는 [FileSystem Interface](https://arrow.apache.org/docs/python/api/filesystems.html)도 제공하고 여기서 multipart upload도 지원한다.
pyarrow doc에서는 multipart upload에대한 언급이 없지만, 실제로 테스트 해본 결과 multipart로 한개의 parquet object가 생성되는것을 확인했다.

```py
from pyarrow import fs, parquet as pq

# https://arrow.apache.org/docs/python/generated/pyarrow.fs.S3FileSystem.html#pyarrow.fs.S3FileSystem
file_system: fs.FileSystem = fs.S3FileSystem(
    access_key=access_key,
    secret_key=secret_key,
    region=region,
    # background_writes=True, # True가 default value인데 non-blocking으로 write를 하게된다.
)

# https://arrow.apache.org/docs/python/generated/pyarrow.parquet.ParquetWriter.html
parquet_writer: pq.ParquetWriter = pq.ParquetWriter(
    where=f's3://{bucket}/{prefix}/{object_name}.parquet'
    schema=schema, # 위에서 생성한 테이블 스키마,
    filesystem=file_system,
    allow_truncated_timestamp=True, # timestamp에서 nanoseconde등의 data loss가 생길때 무시하는 옵션
)

parquet_writer.write_table(t1) # 매번 write_table할때마다 
parquet_writer.write_table(t2)
...
parquet_writer.write_table(tn)

parquet_writer.close() # with as statement로도 사용가능하다.
```

## 실제 코드에 붙여보기

### Transpose
실제로 사용하는 케이스는 mysql query result를 s3에 내리는 작업(현재는 이것 말고도 다양한 usecase에서 사용 중)인데 python에서 query result를 받으면 record의 list로 들어오고, 위 예시에서 봤던 JSON형태로 들어오지 않는다.
따라서 pyarrow.Table이 제공해주는 인터페이스에 맞게 데이터를 변환해주는 작업이 필요하다.
위 예시만 그대로 보면 단순하게 record 순서대로 key를 붙여주면 되지만, pyarrow는 column 기반의 data layout을 가지고있으므로 row-wise를 column-wise로 바꿔주면 좀더 pyarrow-friendly하게 쓴다고 볼 수 있다.
따라서 transpose를 진행해줘야한다.
```py
records: Tuple[Tuple[Any], ...] = (
    (1, "name1", '2022-05-01T00:00:00+00:00', '10.0'),
    (2, "name2", '2022-05-01T00:00:00+00:00', '11.0'),
    ...
)
column_wise: List[List[Any]] = []
for record in records:
    for i, data in enumerate(record):
        column_wise[i].append(data)

t: pa.Table = pa.Table.from_arrays(
    arrays=[pa.array(column_list) for column_list in columns],
    schema=schema,
)
```

### NULL Decimal 처리

Decimal이 언제나 not null로 선언되어있으면 문제가 생기지 않는데, nullable하다면 string으로 들어오는 decimal을 명시적으로 값을 미리 변환해서 넣어주지 않으면 에러가 난다.
```py
from decimal import Decimal

records: Tuple[Tuple[Any], ...] = (
    (1, "name1", '2022-05-01T00:00:00+00:00', ''),
    (2, "name2", '2022-05-01T00:00:00+00:00', None),
    ...
)
column_wise: List[List[Any]] = []
for record in records:
    for i, data in enumerate(record):
        if pa.types.is_decimal(schema.types[i]): # pa.Schema에서 i번째 컬럼이 Decimal type인지 확인
            column_wise[i].append(Decimal(data) if data is not None and data != '' else None) # Decimal(None)은 에러가 난다.
        else:
            column_wise[i].append(data)
```

## multipart leak

모든 코드가 비슷하지만, Airflow task는 실패할수 있을 가정하고 만들어야 한다.
위 코드에서 중간에 task가 실패하는 경우, multipart upload가 완료되지 않고 그대로 남아있게 될 것이다.
물론 S3은 엄청나게 scalable하기 때문에 시스템에 문제가 생기는 상황은 일어나지 않겠지만, 돈은 나간다.
따라서 작업을 시작하기 전에 in-progress multipart upload가 남아있는지 확인하고 제거해주는 코드를 추가해주면 좋다.

```py
from mypy_boto3_s3 import S3Client # 이 라이브러리를 활용하면 boto에 type을 씌워서 쓸 수 있다
from mypy_boto3_s3.type_defs import ListMultipartUploadsOutputTypeDef

s3: S3Client = boto3.client('s3')

res: ListMultipartUploadsOutputTypeDef = s3.list_multipart_uploads(bucket=bucket, prefix=prefix)
upload: MultipartUploadTypeDef
for upload in res['Uploads']:
    s3.abort_multipart_upload(bucket=bucket, key=upload['Key'], UploadId=upload['UploadId'])

```

## 유의사항

Apache Arrow 7.0.0 이전 버전에서 S3 multipart upload를 사용할때 데이터가 "손실" 될 수있는 버그를 7.0.0에서 수정했으므로 S3 multipart upload를 사용한다면 꼭 7.0.0 이상의 버전을 써야한다.

[https://arrow.apache.org/blog/2022/02/08/7.0.0-release/](https://arrow.apache.org/blog/2022/02/08/7.0.0-release/)

## 참조

[https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpuoverview.html](https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpuoverview.html)

[https://arrow.apache.org/docs/](https://arrow.apache.org/docs/)

[https://aws.amazon.com/blogs/aws-cloud-financial-management/discovering-and-deleting-incomplete-multipart-uploads-to-lower-amazon-s3-costs/](https://aws.amazon.com/blogs/aws-cloud-financial-management/discovering-and-deleting-incomplete-multipart-uploads-to-lower-amazon-s3-costs/)

[https://aws.amazon.com/blogs/big-data/top-10-performance-tuning-tips-for-amazon-athena/](https://aws.amazon.com/blogs/big-data/top-10-performance-tuning-tips-for-amazon-athena/)

[https://pypi.org/project/mypy-boto3/](https://pypi.org/project/mypy-boto3/)