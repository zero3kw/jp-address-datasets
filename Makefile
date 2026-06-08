.PHONY: help docker-build download download-jat download-nja download-houjin download-school download-abr lint clean

SCRIPTS      := $(wildcard scripts/*.sh)
DOCKER_IMAGE := jp-address-datasets:latest
# DevContainer 内など、コンテナ内パスとホスト側パスが異なる環境では
# HOST_DIR=/host/abs/path make ... で上書きする
HOST_DIR     ?= $(CURDIR)
DOCKER_RUN   := docker run --rm -v "$(HOST_DIR):/work" -w /work --user "$(shell id -u):$(shell id -g)" -e PREF -e SKIP_RSDTDSP -e SKIP_PARCEL -e PARALLEL $(DOCKER_IMAGE)

help:
	@echo "Targets (すべて Docker 経由で実行):"
	@echo "  make docker-build     - Docker イメージをビルド"
	@echo "  make download         - 全データセットを取得"
	@echo "  make download-jat     - JAT (t-sagara)"
	@echo "  make download-nja     - NJA (geolonia)"
	@echo "  make download-houjin  - 法人番号 (自動取得)"
	@echo "  make download-school  - 国土数値情報 学校"
	@echo "  make download-abr     - ABR (DCAT feed から自動取得)"
	@echo "  make lint             - shellcheck"
	@echo "  make clean            - data/ 配下を全削除"

docker-build:
	docker build -t $(DOCKER_IMAGE) .

download: docker-build
	$(DOCKER_RUN) bash scripts/download_datasets.sh all

download-jat: docker-build
	$(DOCKER_RUN) bash scripts/download_datasets.sh jat

download-nja: docker-build
	$(DOCKER_RUN) bash scripts/download_datasets.sh nja

download-houjin: docker-build
	$(DOCKER_RUN) bash scripts/download_datasets.sh houjin

download-school: docker-build
	$(DOCKER_RUN) bash scripts/download_datasets.sh school

download-abr: docker-build
	$(DOCKER_RUN) bash scripts/download_datasets.sh abr

lint: docker-build
	$(DOCKER_RUN) shellcheck -x -P scripts $(SCRIPTS)

clean:
	rm -rf data
	mkdir -p data/raw data/prc
	touch data/.gitkeep
