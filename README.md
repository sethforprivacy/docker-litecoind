litecoind for Docker
===================

Docker image that runs the Litecoin `litecoind` node in a container for easy deployment.

***Note: Credit for this image goes almost entirely to https://github.com/kylemanna/docker-litecoind, I have added some optimizations and migrated the overall setup to Litecoin and wanted a way to keep more easily up to date.***

Quick Start
-----------

1. Create a `litecoind-data` volume to persist the litecoind blockchain data, should exit immediately.  The `litecoind-data` container will store the blockchain when the node container is recreated (software upgrade, reboot, etc):

        docker volume create --name=litecoind-data
        docker run -v litecoind-data:/litecoin/.litecoin --name=litecoind-node -d \
            -p 9333:9333 \
            -p 127.0.0.1:9332:9332 \
            ghcr.io/sethforprivacy/litecoind:latest

2. Verify that the container is running and litecoind node is downloading the blockchain

        $ docker ps
        CONTAINER ID        IMAGE                         COMMAND             CREATED             STATUS              PORTS                                              NAMES
        d0e1076b2dca        ghcr.io/sethforprivacy/litecoind:latest     "btc_oneshot"       2 seconds ago       Up 1 seconds        127.0.0.1:9332->9332/tcp, 0.0.0.0:9333->9333/tcp   litecoind-node

3. You can then access the daemon's output thanks to the [docker logs command]( https://docs.docker.com/reference/commandline/cli/#logs)

        docker logs -f litecoind-node
