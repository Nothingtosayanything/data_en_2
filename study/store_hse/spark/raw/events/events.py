import os
import argparse

from datetime import date, timedelta
from pyspark.sql import SparkSession
from pyspark.sql import functions as F


parser = argparse.ArgumentParser()

parser.add_argument(
    "--load-date",
    required=True,
    type=date.fromisoformat
)

args = parser.parse_args()

LOAD_DATE = args.load_date
START_DATE = LOAD_DATE - timedelta(days=3)

PG = dict(
    host='postgres',
    port=5432,
    dbname=os.environ.get('POSTGRES_DB'),
    user=os.environ.get('POSTGRES_USER'),
    password=os.environ.get('POSTGRES_PASSWORD'),
)

BUCKET = 'de-course'
EVENTS_PATH = f"s3a://{BUCKET}/raw/events"

spark = (
    SparkSession.builder
    .config("spark.hadoop.fs.s3a.endpoint", os.environ.get('MINIO_ENDPOINT'))
    .config("spark.hadoop.fs.s3a.access.key", os.environ.get('MINIO_ROOT_USER'))
    .config("spark.hadoop.fs.s3a.secret.key", os.environ.get('MINIO_ROOT_PASSWORD'))
    .config("spark.hadoop.fs.s3a.path.style.access", "true")
    .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false")
    .config("spark.sql.sources.partitionOverwriteMode", "dynamic")
    .getOrCreate()
)

spark.sparkContext.setLogLevel("ERROR")

jdbc = dict(
    url=f"jdbc:postgresql://{PG['host']}:{PG['port']}/{PG['dbname']}",
    user=PG['user'],
    password=PG['password'],
    driver='org.postgresql.Driver',
)

hadoop_conf = spark.sparkContext._jsc.hadoopConfiguration()
path = spark._jvm.org.apache.hadoop.fs.Path(EVENTS_PATH)
fs = path.getFileSystem(hadoop_conf)
files = fs.globStatus(
    spark._jvm.org.apache.hadoop.fs.Path(
        f"{EVENTS_PATH}/event_dt=*/part-*.parquet"
    )
)

sink_has_data = files is not None and len(files) > 0

if sink_has_data:
    where = f"""
        WHERE event_time >= '{START_DATE}'
          AND event_time < '{LOAD_DATE}'
    """
else:
    where = ""


query = f"""
    SELECT event_id
         , customer_id
         , event_time
         , event_type
         , product_id
         , session_id
    FROM public.events
    {where}
"""


df_events = (
    spark.read.format("jdbc")
    .option("query", query)
    .options(**jdbc)
    .load()
)

df_events = df_events.withColumn(
    "event_dt",
    F.to_date("event_time")
)


(
    df_events.write
    .format("parquet")
    .mode("overwrite")
    .partitionBy("event_dt")
    .save(EVENTS_PATH)
)

print(f"Сохранено: {EVENTS_PATH}, строк: {df_events.count()}")

spark.stop()