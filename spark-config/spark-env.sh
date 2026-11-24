# Переменные окружения Spark (source-ится shell-скриптами /opt/spark)
# Файл должен лежать в ./spark-config как spark-env.sh

# Память воркера/исполнителей в Standalone-режиме
export SPARK_WORKER_MEMORY=4g
export SPARK_WORKER_CORES=2
export SPARK_EXECUTOR_MEMORY=3g
export SPARK_EXECUTOR_CORES=2