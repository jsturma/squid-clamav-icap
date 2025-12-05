FROM debian:bookworm
COPY entrypoint.sh ./entrypoint.sh
RUN chmod +x entrypoint.sh

ARG SQUIDCLAMAV_GIT=https://github.com/darold/squidclamav.git
ARG SQUIDCLAMAV_VERSION=v7.4

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        c-icap \
        ca-certificates \
        patch \
        libicapapi5 \
        libssl-dev \
        libicapapi-dev \
        libc-dev \
        gcc \
        make \
        file \
        autoconf \
        automake \
        libtool \
        pkg-config \
        iproute2 \
        curl \
     && apt-mark auto \
        vim \
        wget \
        squid \
\
     && git clone --recursive "${SQUIDCLAMAV_GIT}" "/usr/src/squidclamav" \
     && (cd /usr/src/squidclamav \
         && git checkout "${SQUIDCLAMAV_VERSION}" 2>/dev/null || true \
         && ./configure \
         && make -j$(nproc) \
         && make install \
     ) \
     && rm -rf /usr/src/squidclamav \
\
     && apt-get autoremove --purge -y \
     && apt-get clean \
     && rm -rf /var/tmp/* /tmp/* /var/lib/apt/cache/*
     
RUN (echo "acl all src 0.0.0.0/0.0.0.0" \
     && echo "icap_access allow all") >> /etc/c-icap/c-icap.conf
     
COPY entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/* \
    && sed -i 's,\r,,g' /usr/local/bin/*
ENTRYPOINT ["./entrypoint.sh"]
    
