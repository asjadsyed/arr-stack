FROM ubuntu:24.04@sha256:d1e2e92c075e5ca139d51a140fff46f84315c0fdce203eab2807c7e495eff4f9

WORKDIR /opt/init

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        jq \
    && rm -rf /var/lib/apt/lists/*

COPY init.sh .

CMD [ "./init.sh" ]
