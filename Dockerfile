# Единый multi-stage Dockerfile для стенда de-practice-7.
# Каждый сервис compose собирает свой этап через build.target.
# Сборка: docker compose build jupyter ubuntu-vm

# ============================================================
# Этап 1: jupyter (база — apache/spark, pip-зависимости в образе)
# ============================================================
FROM apache/spark:3.5.5 AS jupyter

USER root

# Все python-зависимости ставятся на этапе сборки, а не при каждом старте контейнера
RUN pip install --no-cache-dir \
      jupyterlab \
      pyspark==3.5.5 \
      'psycopg[binary]' \
      boto3 \
      pandas \
      pyarrow \
      deltalake \
      'python-dateutil==2.9.0'

WORKDIR /home/spark/notebooks

EXPOSE 8888 4040

CMD ["jupyter", "lab", \
     "--ip=0.0.0.0", \
     "--port=8888", \
     "--no-browser", \
     "--allow-root", \
     "--ServerApp.token=''", \
     "--ServerApp.root_dir=/home/spark/notebooks"]

# ============================================================
# Этап 2: ubuntu-vm (база — ubuntu, python 3.8 + pyspark в образе)
# ============================================================
FROM ubuntu:22.04 AS ubuntu-vm

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Europe/Moscow

# Системные пакеты + python 3.8 из deadsnakes + pyspark 3.5.5 + delta-spark 3.3.0
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      software-properties-common gnupg curl openjdk-17-jre-headless && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      python3.8 python3.8-venv python3.8-distutils && \
    curl -sSL https://bootstrap.pypa.io/pip/3.8/get-pip.py | python3.8 && \
    PIP_DEFAULT_TIMEOUT=60 python3.8 -m pip install --no-cache-dir \
      pyspark==3.5.5 \
      delta-spark==3.3.0 && \
    ln -sf /usr/bin/python3.8 /usr/local/bin/python && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# PySpark отвечает на этот интерпретатор
ENV PYSPARK_PYTHON=/usr/bin/python3.8 \
    PYSPARK_DRIVER_PYTHON=/usr/bin/python3.8

WORKDIR /home/student/study

# Держим контейнер живым
CMD ["tail", "-f", "/dev/null"]
