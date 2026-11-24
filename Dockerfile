# Base images are pinned by digest; Dependabot keeps the digests current.
FROM rust:1-trixie@sha256:931c2c0531a8b143e044f0f3914dfe802f15bb3d1955f0b657e9359327ac2ffc AS builder
WORKDIR /src
COPY . .
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/src/target \
    cargo build --release --locked \
    && cp target/release/hushdns /usr/local/bin/hushdns
# Docker lets unprivileged users bind ports below 1024 inside the container,
# Podman does not. A permitted-only file capability, which the server raises
# itself at startup, covers both. Without the effective bit the binary still
# starts where the capability is dropped, as in the Helm chart.
RUN apt-get update && apt-get install -y --no-install-recommends libcap2-bin \
    && setcap cap_net_bind_service=+p /usr/local/bin/hushdns \
    && getcap /usr/local/bin/hushdns

FROM gcr.io/distroless/cc-debian13:nonroot@sha256:532c7a94f9e96ba9db75eb9388f4227751131c7cb0a411d1a8521af4096135de
LABEL org.opencontainers.image.title="hushdns" \
      org.opencontainers.image.description="An ad-blocking, privacy-focused DNS server" \
      org.opencontainers.image.source="https://github.com/mustafa-zidan/hushdns" \
      org.opencontainers.image.licenses="GPL-3.0-or-later"
COPY --from=builder /usr/local/bin/hushdns /usr/local/bin/hushdns
COPY config/hushdns.toml /etc/hushdns/hushdns.toml
ENV HUSHDNS_CONFIG=/etc/hushdns/hushdns.toml
EXPOSE 53/udp 53/tcp 853/tcp 443/tcp
USER nonroot
ENTRYPOINT ["/usr/local/bin/hushdns"]
