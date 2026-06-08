FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        jq \
        shellcheck \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# DuckDB CLI (バージョン固定。latest リダイレクトより安定)
ARG TARGETARCH
ARG DUCKDB_VERSION=v1.5.3
RUN case "$TARGETARCH" in \
        amd64) duckdb_arch=amd64 ;; \
        arm64) duckdb_arch=arm64 ;; \
        *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL --retry 5 --retry-delay 3 --retry-all-errors \
        "https://github.com/duckdb/duckdb/releases/download/${DUCKDB_VERSION}/duckdb_cli-linux-${duckdb_arch}.zip" \
        -o /tmp/duckdb.zip \
    && unzip -q /tmp/duckdb.zip -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/duckdb \
    && rm /tmp/duckdb.zip

WORKDIR /work
CMD ["bash"]
