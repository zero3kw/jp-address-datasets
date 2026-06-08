FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        jq \
        shellcheck \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# DuckDB CLI (アーキは buildx 標準の TARGETARCH から決定)
ARG TARGETARCH
RUN case "$TARGETARCH" in \
        amd64) duckdb_arch=amd64 ;; \
        arm64) duckdb_arch=arm64 ;; \
        *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL --retry 5 --retry-delay 3 --retry-all-errors \
        "https://github.com/duckdb/duckdb/releases/latest/download/duckdb_cli-linux-${duckdb_arch}.zip" \
        -o /tmp/duckdb.zip \
    && unzip -q /tmp/duckdb.zip -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/duckdb \
    && rm /tmp/duckdb.zip

WORKDIR /work
CMD ["bash"]
