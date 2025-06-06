FROM aeternity/builder:focal-otp26 as builder

# Add required files to download and compile only the dependencies
ADD rebar.config rebar.lock Makefile rebar3 rebar.config.script /app/
ENV ERLANG_ROCKSDB_OPTS "-DWITH_SYSTEM_ROCKSDB=ON -DWITH_LZ4=ON -DWITH_SNAPPY=ON -DWITH_BZ2=ON -DWITH_ZSTD=ON"

RUN cd /app && make prod-compile-deps
# Add the whole project and compile aeternity itself.
ADD . /app
RUN cd /app && make prod-build

# Put aeternity node in second stage container
FROM ubuntu:20.04

# Install shared library dependencies
RUN apt-get -qq update \
    && apt-get -qq -y install libssl1.1 curl libsodium23 libgmp10 \
        libsnappy1v5 liblz4-1 libzstd1 libgflags2.2 libbz2-1.0 \
    && ldconfig \
    && rm -rf /var/lib/apt/lists/*

# Install shared rocksdb code from builder container

COPY --from=builder /usr/local/lib/librocksdb.so.7.10.2 /usr/local/lib/
RUN ln -fs librocksdb.so.7.10.2 /usr/local/lib/librocksdb.so.7.10 \
    && ln -fs librocksdb.so.7.10.2 /usr/local/lib/librocksdb.so.7 \
    && ln -fs librocksdb.so.7.10.2 /usr/local/lib/librocksdb.so \
    && ldconfig

# Deploy application code from builder container
COPY --from=builder /app/_build/prod/rel/aeternity /home/aeternity/node

# Aeternity app won't run as root for security reasons
RUN useradd --uid 1000 --shell /bin/bash aeternity \
    && chown -R aeternity:aeternity /home/aeternity

# Switch to non-root user
USER aeternity
ENV SHELL /bin/bash

# Create data directories in advance so that volumes can be mounted in there
# see https://github.com/moby/moby/issues/2259 for more about this nasty hack
RUN mkdir -p /home/aeternity/node/data/mnesia \
    && mkdir -p /home/aeternity/node/keys

WORKDIR /home/aeternity/node

EXPOSE 3013 3014 3015 3113 3213 3413

COPY ./docker/healthcheck.sh /healthcheck.sh
HEALTHCHECK --timeout=3s CMD /healthcheck.sh

# Run in `console` mode with `-noinput` to enable Ctrl-C for entering the
# Erlang Break menu. In `foreground` mode (which is equivalent to `-noinput
# +Bd`), no Ctrl-C handler is installed, and Docker will not forward Ctrl-C
# to a process running as PID 1 unless it has a custom handler.
CMD ["bin/aeternity", "console", "-noinput"]
