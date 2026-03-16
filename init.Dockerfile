FROM ubuntu:24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        jq \
    && rm -rf /var/lib/apt/lists/*

COPY init.sh .

CMD [ "init.sh" ]
