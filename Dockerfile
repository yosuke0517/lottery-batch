FROM python:3.8
ENV PYTHONUNBUFFERED 1

# パッケージの更新確認
RUN apt-get -y update

RUN apt-get update && apt-get install -y unzip

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends chromium && \
    pip install --upgrade pip setuptools wheel && \
    pip install selenium && \
    # webdriverはなるべく近いバージョンをダウンロード
    pip install chromedriver-binary~=$(chromium --version | perl -pe 's/([^0-9]+)([0-9]+\.[0-9]+).+/$2/g')

RUN mkdir /app
WORKDIR /app
ADD requirements.txt /app/
RUN pip install --upgrade pip \
    -r requirements.txt
ADD . /app/