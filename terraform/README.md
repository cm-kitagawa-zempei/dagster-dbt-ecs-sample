# Terraform構成

DagsterをECS on Fargateで動かすインフラ構成。基盤とアプリケーションに分離して管理。

## 構成

```
terraform/
├── foundation/          # 基盤リソース（先に作成）
│   ├── main.tf         # VPC、RDS、ECR、IAM、Secrets Manager
│   ├── variables.tf    # 変数定義
│   ├── outputs.tf      # 出力値（application側で使用）
│   └── terraform.tfvars.example
├── application/         # アプリケーションリソース（後に作成）
│   ├── main.tf         # ALB、ECS、CloudWatch、Service Discovery
│   ├── variables.tf    # 変数定義
│   ├── outputs.tf      # ALBエンドポイント等
│   └── terraform.tfvars.example
└── README.md
```

## ECRイメージ準備

foundation作成後、コンテナイメージをECRにプッシュ。

```bash
cd ../dagster_project
docker compose build
aws ecr get-login-password | docker login --username AWS --password-stdin <ECR_URL>
# タグ付け・プッシュ（詳細は dagster_project/README.md 参照）
```

## 実行手順

### 1. AWS認証設定

```bash
export AWS_PROFILE=your-profile-name
```

### 2. 変数ファイル準備

```bash
# foundation
cp terraform/foundation/terraform.tfvars.example terraform/foundation/terraform.tfvars
# 編集

# application
cp terraform/application/terraform.tfvars.example terraform/application/terraform.tfvars  
# 編集
```

### 3. 基盤リソース作成（先に実行）

```bash
cd terraform/foundation
terraform init && terraform apply
```

### 4. アプリケーションリソース作成（後に実行）

```bash
cd terraform/application
terraform init && terraform apply
```

## データ連携

applicationはfoundationの出力値を参照

```hcl
data "terraform_remote_state" "foundation" {
    backend = "local"
    config = {
        path = "../foundation/terraform.tfstate"
    }
}
```

## 必要な変数

### foundation/

- `prefix`: リソース名プレフィックス
- `dagster_postgres_*`: PostgreSQL設定
- `dbt_env_secret_snowflake_*`: Snowflake認証情報

### application/

- `prefix`: リソース名プレフィックス

## 注意事項

1. 実行順序: foundation → application
2. 状態ファイル: foundation/terraform.tfstate存在確認
3. 機密情報: terraform.tfvarsで管理（バージョン管理対象外）
4. 削除順序: application → foundation
