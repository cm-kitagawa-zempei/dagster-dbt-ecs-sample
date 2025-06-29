# Dagster プロジェクト

DagsterとdbtをECS環境で動かすプロジェクト。

## ファイル構成

```
dagster_project/
├── dagster_project/          # Pythonモジュール
│   ├── assets.py            # dbtアセット定義
│   ├── definitions.py       # エントリーポイント
│   ├── project.py           # dbtプロジェクト設定
│   └── schedules.py         # スケジュール定義
├── dbt-project/             # パッケージ化dbtプロジェクト（AWS用）
├── Dockerfile_dagster       # Webserver/Daemon用
├── Dockerfile_user_code     # Code Server用
├── docker-compose.yml       # ビルド設定
├── dagster.yaml             # インスタンス設定
├── workspace.yaml           # コードロケーション設定
└── pyproject.toml           # 依存関係
```

## Docker環境

### ビルド

```bash
docker compose build
```

作成されるイメージ

- `dagster_project-dagster_ecs_core`: Webserver/Daemon用
- `dagster_project-dagster_ecs_user_code`: Code Server用

### ECRプッシュ

基盤リソース作成後の手順

```bash
# ECR情報設定
export ECR_REGISTRY="<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com"

# ECRログイン
aws ecr get-login-password | docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Dagster Core プッシュ
docker tag dagster_project-dagster_ecs_core:latest ${ECR_REGISTRY}/<PREFIX>-dagster_ecs_core:latest
docker push ${ECR_REGISTRY}/<PREFIX>-dagster_ecs_core:latest

# User Code プッシュ
docker tag dagster_project-dagster_ecs_user_code:latest ${ECR_REGISTRY}/<PREFIX>-dagster_ecs_user_code:latest
docker push ${ECR_REGISTRY}/<PREFIX>-dagster_ecs_user_code:latest
```

※ `<PREFIX>` は terraform.tfvars の prefix 値

## 主要設定

### dagster.yaml

Dagsterインスタンス設定（PostgreSQL接続、EcsRunLauncher等）

### workspace.yaml

コードロケーション設定（Service Discovery経由でCode Serverに接続）

### project.py

dbtプロジェクト設定。`DAGSTER_ENV` 環境変数で切り替え

- ローカル：`jaffle_shop/` 参照
- AWS：`dbt-project/` 参照

## 環境変数

**Dagster用**

- `DAGSTER_ENV=AWS`: AWS環境フラグ
- `DAGSTER_POSTGRES_*`: PostgreSQL接続情報

**dbt用（Secrets Managerから自動注入）**

- `DBT_ENV_SECRET_SNOWFLAKE_*`: Snowflake認証情報

## コンテナ詳細

### Dockerfile_dagster

Webserver/Daemon実行用。最小限のライブラリと設定ファイルのみ。

### Dockerfile_user_code

Code Server実行用。Dagster・dbtプロジェクトを含み、gRPCサーバー（ポート4000）起動。