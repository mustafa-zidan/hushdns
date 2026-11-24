# Base images are pinned by digest; Dependabot keeps the digests current.
FROM rust:1-trixie@sha256:09027f873d45b8ecd1dc86f1fa13b7a62b875c961f017a0e331267b350430137 AS builder
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

FROM gcr.io/distroless/cc-debian13:nonroot@sha256:3ee00291cf386ec52a552e6a858d555debd74776eb4bfa53fa3df2cd6677515e
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
