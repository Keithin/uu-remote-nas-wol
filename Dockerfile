FROM ubuntu:24.04 AS build
ARG UPSTREAM_REVISION=fe052cdca7ad90d1ab7c27d031036b1071869070
ENV UU_NO_GTK=1
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates git build-essential pkg-config libx11-dev libxext-dev libxtst-dev libxfixes-dev cargo-1.91
ENV PATH="/usr/lib/rust-1.91/bin:$PATH"
WORKDIR /source
RUN git init && git fetch --depth 1 https://github.com/VallierDev/uu-remote-linux.git "$UPSTREAM_REVISION" && git checkout --detach FETCH_HEAD && test "$(git rev-parse HEAD)" = "$UPSTREAM_REVISION"
RUN cargo test --release --locked --bin uuremote-server wol::tests && cargo build --release --locked --bin uuremote-server

FROM ubuntu:24.04
LABEL org.opencontainers.image.source="https://github.com/Keithin/uu-remote-nas-wol" \
      org.opencontainers.image.licenses="GPL-3.0"
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libx11-6 libxext6 libxtst6 libxfixes3 && rm -rf /var/lib/apt/lists/*
COPY --from=build /source/target/release/uuremote-server /usr/local/bin/
ENV UU_CONFIG=/config/config.json UU_DESKTOP_BACKEND=none UU_LOGIN_WINDOW=0 UU_AUDIO=0 UU_WOL_HELPER=1 HOME=/data
WORKDIR /data
ENTRYPOINT ["/bin/sh", "-c", "umask 077; exec uuremote-server \"$@\"", "uu-wol"]
