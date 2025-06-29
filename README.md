# Dagster + dbt ECS Sample

DagsterとdbtをECS on Fargateで動かすサンプルプロジェクト。
関連ブログ: https://dev.classmethod.jp/articles/dagster-dbt-core-ecs-sample

## 前提条件

- AWS CLI設定済み
- Terraform、Dockerのコマンドが使える状態
- uv（Pythonパッケージ管理）
- Snowflakeアカウント（キーペア認証設定済み）

## 構築手順

### 1. ローカル確認

```bash
cd dagster_project
uv run dagster dev
```

### 2. dbtパッケージ準備

```bash
uv run dagster-dbt project prepare-and-package --file dagster_project/project.py
```

### 3. AWS環境デプロイ

**基盤リソース作成**

```bash
cd terraform/foundation
cp terraform.tfvars.example terraform.tfvars
# 変数を編集後
terraform init
terraform apply
```

**コンテナイメージ準備**

```bash
cd ../../dagster_project
docker compose build
# ECRプッシュ（詳細は dagster_project/README.md 参照）
```

**アプリケーションリソース作成**

```bash
cd ../terraform/application
cp terraform.tfvars.example terraform.tfvars
# 変数を編集後
terraform init
terraform apply
```

## ディレクトリ構造

```
dagster-dbt-ecs-sample/
├── dagster_project/         # Dagsterプロジェクト
│   ├── dagster_project/     # Pythonモジュール
│   ├── dbt-project/         # パッケージ化されたdbtプロジェクト（AWS用）
│   ├── Dockerfile_dagster   # Webserver/Daemon用
│   ├── Dockerfile_user_code # ユーザーコード用
│   └── docker-compose.yml   # ビルド設定
├── jaffle_shop/             # dbtサンプルプロジェクト（別リポジトリで管理）
└── terraform/               # インフラ定義
    ├── foundation/          # VPC、RDS、ECR、IAM、Secrets Manager
    └── application/         # ALB、ECS、CloudWatch、Service Discovery
```

## 重要な設定

- dbt接続: Snowflakeキーペア認証
- 機密情報: Secrets Manager管理
- コンテナ間通信: Service Discovery
- 実行順序: foundation → application

## 関連ドキュメント

- [Dagsterプロジェクト詳細](./dagster_project/README.md)
- [Terraform構成](./terraform/README.md)