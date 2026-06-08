# jp-address-datasets

日本の住所処理ツール（ジオコーダー / 住所正規化など）の評価用テストデータを集約するレポジトリ。

## 用途

- **ベンチマーク**: ジオコーダーのスループット計測
- **正規化精度評価**: 既存ライブラリ の出力比較
- **公開用データセット**: 出典・ライセンスを明示した再現可能なテストセット

## データセット一覧

| ID | 名称 | 出典 | 件数 | ライセンス |
|----|------|------|-----:|------------|
| `jat` | Japanese Address Testdata | [t-sagara/Japanese-Address-testdata](https://github.com/t-sagara/Japanese-Address-testdata) | 76 | [MIT](https://github.com/t-sagara/Japanese-Address-testdata/blob/main/LICENSE) |
| `nja` | Normalize Japanese Addresses test corpus | [geolonia/normalize-japanese-addresses](https://github.com/geolonia/normalize-japanese-addresses) | 7,191 | [MIT](https://github.com/geolonia/normalize-japanese-addresses/blob/master/LICENSE.txt) |
| `school` | 国土数値情報 学校等 (P29、幼稚園〜大学・専修学校) | [国土交通省 国土数値情報](https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-P29.html) | 53,842 | [国土数値情報利用約款](https://nlftp.mlit.go.jp/ksj/other/agreement.html) |
| `houjin` | 法人番号公表サイト 全件データの所在地 | [国税庁](https://www.houjin-bangou.nta.go.jp/download/zenken/) | 4,456,565 | [利用規約](https://www.houjin-bangou.nta.go.jp/riyokiyaku/) |
| `abr` | アドレス・ベース・レジストリ | [デジタル庁 ABR](https://dataset.address-br.digital.go.jp/) | 211,761,061 | [利用規約](https://www.digital.go.jp/policies/base_registry_address_tos) |

各データの利用にあたっては必ず出典元のライセンス・利用規約を確認してください。

## 前提

すべてのスクリプトは Docker コンテナ内 で実行されます。

### DevContainer など、コンテナ内で実行する場合

ホスト側 Docker を呼ぶ環境では、コンテナ内のパスをホスト側のパスに置き換える必要があります:

```bash
HOST_DIR=/Users/foo/path/to/jp-address-datasets make download
```

## 使い方

### 全件取得

```bash
make download
```

### 個別取得

```bash
make download-jat
make download-nja
make download-school
make download-houjin
make download-abr
```

#### ABR の取得範囲を絞る

| 環境変数 | 効果 |
|---|---|
| `PREF=13` | 当該都道府県（2桁コード）のみ取得 |
| `SKIP_RSDTDSP=1` | 住居表示マスター（rsdtdsp_blk + rsdtdsp_rsdt）をスキップ |
| `SKIP_PARCEL=1` | 地番マスター（約 1,900 ファイル）をスキップ |
| `PARALLEL=16` | 並列ダウンロード数（デフォルト 16） |

```bash
# 東京都のみ、住居表示と地番をスキップして軽量に動作確認
PREF=13 SKIP_RSDTDSP=1 SKIP_PARCEL=1 make download-abr
```

### Lint

```bash
make lint
```

## ファイル構成

`data/` 配下を raw（取得元データ）と prc（住所抽出済み）に分離します:

- `data/raw/{dataset}.{ext}` — 取得元データそのまま（CSV / GeoJSON）
- `data/prc/{dataset}.txt` — 住所文字列のみを 1 行 1 件で抽出（重複排除済み）

| データセット | Raw | 住所のみ |
|---|---|---|
| jat | `raw/jat.csv` | `prc/jat.txt` |
| nja | `raw/nja.csv` | `prc/nja.txt` |
| houjin | `raw/houjin.csv` | `prc/houjin.txt` |
| school | `raw/school.geojson` | `prc/school.txt` |
| abr (pref) | `raw/abr/mt_city/*.csv` | `prc/abr_pref.txt` |
| abr (city) | `raw/abr/mt_city/*.csv` | `prc/abr_city.txt` |
| abr (town) | `raw/abr/mt_town_fullset/*.csv` | `prc/abr_town.txt` |
| abr (blk) | `raw/abr/mt_rsdtdsp_blk/*.csv` | `prc/abr_blk.txt` |
| abr (rsdt) | `raw/abr/mt_rsdtdsp_rsdt/*.csv` | `prc/abr_rsdt.txt` |
| abr (parcel) | `raw/abr/mt_parcel/*.csv` | `prc/abr_parcel.txt` |

## ライセンス

- **スクリプト・ドキュメント**: MIT License ([LICENSE](LICENSE))
- **データ**: 各出典元のライセンスに従います（上表参照）

データを再配布する場合は、各出典の表示要件（クレジット表記等）を必ず守ってください。