# Use a pinned Ubuntu LTS image as build stage (kept current by Renovate)
FROM ubuntu:26.04@sha256:9559ceb7c21e528e233e8dff26a0fb2682f4094cce06176eeb075d87a22b31de AS builder

# Upgrade all packages and install dependencies
RUN apt-get update \
    && apt-get upgrade -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        gnupg \
    && apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set variables necessary for download and verification of litecoin
ARG TARGETARCH
ARG ARCH
# renovate: datasource=github-releases depName=litecoin-project/litecoin versioning=loose
ARG LITECOIN_VERSION=0.21.5.8
ARG LITECOIN_CORE_SIGNATURES="D35621D53A1CC6A3456758D03620E9D387E55666 \
    C0921846FED0BF4CF28BE1D73B2A6315CD51A673 \
    "
ENV LITECOIN_DATA=/litecoin/.litecoin
ENV PATH=/opt/litecoin-${LITECOIN_VERSION}/bin:$PATH

RUN case ${TARGETARCH:-amd64} in \
    "arm64") ARCH="aarch64-linux-gnu";; \
    "amd64") ARCH="x86_64-linux-gnu";; \
    *) echo "Dockerfile does not support this platform"; exit 1 ;; \
    esac \
    && gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys ${LITECOIN_CORE_SIGNATURES} \
    && wget -q --show-progress --progress=dot:giga https://download.litecoin.org/litecoin-${LITECOIN_VERSION}/linux/litecoin-${LITECOIN_VERSION}-${ARCH}.tar.gz \
            https://download.litecoin.org/litecoin-${LITECOIN_VERSION}/SHA256SUMS.asc \
    && gpg --status-fd 1 --verify SHA256SUMS.asc 2>/dev/null \
        | grep -Eq "^\[GNUPG:\] VALIDSIG.*($(printf '%s\n' ${LITECOIN_CORE_SIGNATURES} | paste -sd'|' -))$" \
    && grep " litecoin-${LITECOIN_VERSION}-${ARCH}.tar.gz" SHA256SUMS.asc | sha256sum -c - \
    && tar -xzf *.tar.gz -C /opt \
    && ln -sv litecoin-${LITECOIN_VERSION} /opt/litecoin \
    && rm *.tar.gz *.asc \
    && rm -rf /opt/litecoin-${LITECOIN_VERSION}/bin/litecoin-qt

# Use a pinned Ubuntu LTS image as base for main image (kept current by Renovate)
FROM ubuntu:26.04@sha256:9559ceb7c21e528e233e8dff26a0fb2682f4094cce06176eeb075d87a22b31de AS final

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

# Add HEALTHCHECK probing the local RPC (credentials come from litecoin.conf,
# which litecoin-cli reads from $HOME/.litecoin by default)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 CMD litecoin-cli -rpcconnect=127.0.0.1 -rpcport=9332 getblockchaininfo > /dev/null 2>&1 || exit 1

EXPOSE 9332 9333

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["ltc_oneshot"]
