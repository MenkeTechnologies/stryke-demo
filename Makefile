.PHONY: install up down all arrow mysql postgres spark aws gcp kafka grpc parquet duckdb redis mongo

install:
	s install

up:
	docker compose up -d

down:
	docker compose down -v

all:
	s demos/run_all.stk

arrow:    ; s demos/01_arrow.stk
mysql:    ; MYSQL_URI=mysql://root:root@127.0.0.1:3306/test s demos/02_mysql.stk
postgres: ; POSTGRES_URI=postgres://postgres:postgres@127.0.0.1:5432/postgres s demos/03_postgres.stk
spark:    ; s demos/04_spark.stk
aws:      ; AWS_ENDPOINT_URL=http://localhost:4566 AWS_REGION=us-east-1 \
            AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test \
            s demos/05_aws.stk
gcp:      ; s demos/06_gcp.stk
kafka:    ; KAFKA_BROKERS=localhost:9092 s demos/07_kafka.stk
grpc:     ; s demos/08_grpc.stk
parquet:  ; s demos/09_parquet.stk
duckdb:   ; s demos/10_duckdb.stk
redis:    ; REDIS_URL=redis://localhost:6379 s demos/11_redis.stk
mongo:    ; MONGODB_URI=mongodb://localhost:27017 s demos/12_mongo.stk
