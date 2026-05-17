# stryke-demo

Live demos for every package in the stryke-* family. One `s install`
pulls all twelve from GitHub; each demo is a standalone `.stk` script.

Created by MenkeTechnologies.

## Packages exercised

| # | Package | Demo | Service needed |
|---|---|---|---|
| 1  | [stryke-arrow](https://github.com/MenkeTechnologies/stryke-arrow)       | `demos/01_arrow.stk`    | none (in-process) |
| 2  | [stryke-mysql](https://github.com/MenkeTechnologies/stryke-mysql)       | `demos/02_mysql.stk`    | MySQL 5.7+ / MariaDB |
| 3  | [stryke-postgres](https://github.com/MenkeTechnologies/stryke-postgres) | `demos/03_postgres.stk` | Postgres 12+ |
| 4  | [stryke-spark](https://github.com/MenkeTechnologies/stryke-spark)       | `demos/04_spark.stk`    | none (embedded) |
| 5  | [stryke-aws](https://github.com/MenkeTechnologies/stryke-aws)           | `demos/05_aws.stk`      | LocalStack or real AWS |
| 6  | [stryke-gcp](https://github.com/MenkeTechnologies/stryke-gcp)           | `demos/06_gcp.stk`      | real GCP (ADC) |
| 7  | [stryke-kafka](https://github.com/MenkeTechnologies/stryke-kafka)       | `demos/07_kafka.stk`    | Kafka broker |
| 8  | [stryke-grpc](https://github.com/MenkeTechnologies/stryke-grpc)         | `demos/08_grpc.stk`     | a reflection-enabled gRPC server |
| 9  | [stryke-parquet](https://github.com/MenkeTechnologies/stryke-parquet)   | `demos/09_parquet.stk`  | none (in-process) |
| 10 | [stryke-duckdb](https://github.com/MenkeTechnologies/stryke-duckdb)     | `demos/10_duckdb.stk`   | none (embedded) |
| 11 | [stryke-redis](https://github.com/MenkeTechnologies/stryke-redis)       | `demos/11_redis.stk`    | Redis 6+ |
| 12 | [stryke-mongo](https://github.com/MenkeTechnologies/stryke-mongo)       | `demos/12_mongo.stk`    | MongoDB 5+ |

## Install

```sh
git clone https://github.com/MenkeTechnologies/stryke-demo
cd stryke-demo
s install         # pulls all 12 packages from GitHub, builds helpers
```

`s install` resolves every git dep, builds each package's Rust helper
binary into the global stryke store, and locks the graph in
`stryke.lock`. No per-demo install needed.

## Spin up all live services

`docker-compose.yml` ships MySQL, Postgres, Redis, Mongo, Kafka (KRaft
mode), and LocalStack so you can exercise everything but GCP and gRPC
locally:

```sh
make up                  # start every container
make all                 # auto-detects which services are reachable
make down                # tear down + clear volumes
```

## Run a single demo

```sh
make arrow               # in-process; no services
make duckdb              # embedded
make spark               # embedded DataFusion session

make mysql               # needs make up (or your own mysql at :3306)
make postgres
make redis
make mongo
make kafka
make aws                 # uses LocalStack at :4566

# Need explicit args:
s demos/06_gcp.stk gs://my-bucket projects/my-proj/subscriptions/my-sub
s demos/08_grpc.stk localhost:50051
```

Or invoke directly:

```sh
MONGODB_URI=mongodb://localhost s demos/12_mongo.stk
```

## Run everything available

```sh
s demos/run_all.stk
```

`run_all.stk` pings each backing service and runs only the demos whose
service answers. The rest print `SKIP` and the runner moves on. Safe to
run against any subset of services.

## Layout

```
stryke-demo/
  stryke.toml                # 12 git deps, one per package
  docker-compose.yml         # MySQL + Postgres + Redis + Mongo + Kafka + LocalStack
  Makefile
  demos/
    01_arrow.stk             # in-process Arrow RecordBatch + CSV/Parquet/Feather/JSON
    02_mysql.stk             # CREATE / INSERT / SELECT round-trip
    03_postgres.stk          # CREATE / INSERT / SELECT round-trip
    04_spark.stk             # SparkSQL via embedded DataFusion session
    05_aws.stk               # S3 + DynamoDB + STS via LocalStack
    06_gcp.stk               # GCS put/get/list + Pub/Sub pump
    07_kafka.stk             # create-topic + produce + consume + describe + delete
    08_grpc.stk              # list services + describe via reflection
    09_parquet.stk           # inspect + schema + head + stats
    10_duckdb.stk            # in-mem + bind + scalar + persistent file db
    11_redis.stk             # KV + list + hash + sorted set
    12_mongo.stk             # CRUD + aggregate + index admin
    run_all.stk              # ping each service, run only the reachable demos
```

## Updating dep pins

`stryke.toml` pins each package to `branch = "main"`. When the packages
start cutting `vX.Y.Z` tags, swap to `tag = "vX.Y.Z"` for reproducible
installs and rerun `s install` to refresh `stryke.lock`.

## License

MIT.
