# Use the latest available Ubuntu image as build stage
FROM ubuntu:latest AS builder

# Upgrade all packages and install dependencies
RUN apt-get update \
    && apt-get upgrade -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        gnupg \
    && apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set variables necessary for download and verification of bitcoind
ARG TARGETARCH
ARG ARCH
ARG VERSION=0.21.4
ARG LITECOIN_CORE_SIGNATURE=D35621D53A1CC6A3456758D03620E9D387E55666
ENV LITECOIN_DATA=/litecoin/.litecoin
ENV PATH=/opt/litecoin-${VERSION}/bin:$PATH

RUN case ${TARGETARCH:-amd64} in \
    "arm64") ARCH="aarch64-linux-gnu";; \
    "amd64") ARCH="x86_64-linux-gnu";; \
    *) echo "Dockerfile does not support this platform"; exit 1 ;; \
    esac \
    && gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys ${LITECOIN_CORE_SIGNATURE} \
    && wget -q --show-progress --progress=dot:giga https://download.litecoin.org/litecoin-${VERSION}/linux/litecoin-${VERSION}-${ARCH}.tar.gz \
            https://download.litecoin.org/litecoin-${VERSION}/SHA256SUMS.asc \
    && gpg --verify SHA256SUMS.asc \
    && grep " litecoin-${VERSION}-${ARCH}.tar.gz" SHA256SUMS.asc | sha256sum -c - \
    && tar -xzf *.tar.gz -C /opt \
    && ln -sv litecoin-${VERSION} /opt/litecoin \
    && rm *.tar.gz *.asc \
    && rm -rf /opt/litecoin-${VERSION}/bin/litecoin-qt

# Use latest Ubuntu image as base for main image
FROM ubuntu:latest AS final

WORKDIR /litecoin

# Set litecoin user and group with static IDs
ARG GROUP_ID=1000
ARG USER_ID=1000
RUN userdel ubuntu \
    && groupadd -g ${GROUP_ID} litecoin \
    && useradd -u ${USER_ID} -g litecoin -d /litecoin litecoin

# Copy over litecoin binaries
COPY --chown=litecoin:litecoin --from=builder /opt/litecoin/bin/ /usr/local/bin/

# Upgrade all packages and install dependencies
RUN apt-get update \
    && apt-get upgrade -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gosu \
    && apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy scripts to Docker image
COPY ./bin ./docker-entrypoint.sh /usr/local/bin/

VOLUME ["/litecoin/.litecoin"]

# Set HOME
ENV HOME=/litecoin

EXPOSE 9332 9333

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["ltc_oneshot"]
