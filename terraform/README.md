# Terraform構成

このディレクトリは、基盤リソースとアプリケーションリソースに分割したTerraform構成です。

## ディレクトリ構成

```
terraform/
├── foundation/          # 基盤リソース（事前作成が必要）
│   ├── main.tf         # VPC、RDS、ECR、IAM、Secrets Manager等
│   ├── variables.tf    # 基盤リソース用変数
│   ├── outputs.tf      # アプリケーション側で使用する出力値
│   ├── providers.tf    # プロバイダー設定
│   └── terraform.tfvars.example  # 変数設定例
├── application/         # アプリケーションリソース
│   ├── main.tf         # ALB、ECS、CloudWatch、Service Discovery
│   ├── variables.tf    # アプリケーション用変数
│   ├── outputs.tf      # ALBエンドポイント等の出力値
│   ├── providers.tf    # プロバイダー設定
│   └── terraform.tfvars.example  # 変数設定例
└── README.md           # このファイル
```

## リソース構成

### foundation/ (基盤リソース)
- VPC・ネットワーク: VPC、サブネット、IGW、NAT Gateway、ルートテーブル
- セキュリティグループ: 全てのSG定義
- RDS: PostgreSQLデータベース
- ECR: Dockerレジストリ
- IAM: 全てのロール・ポリシー
- Secrets Manager: DB認証情報、Snowflake認証情報

### application/ (アプリケーションリソース)
- ALB: ロードバランサー、ターゲットグループ、リスナー
- ECS: クラスター、タスク定義、サービス
- CloudWatch: ログ群
- Service Discovery: Cloud Map設定

## 実行手順

### 1. AWS認証設定

環境変数でAWS認証を設定：

```bash
export AWS_PROFILE=your-profile-name
export AWS_DEFAULT_REGION=ap-northeast-1
```

### 2. 変数ファイルの準備

```bash
# foundation用変数ファイル作成
cp terraform/foundation/terraform.tfvars.example terraform/foundation/terraform.tfvars
# 必要な値を編集

# application用変数ファイル作成
cp terraform/application/terraform.tfvars.example terraform/application/terraform.tfvars
# 必要な値を編集
```

### 3. 基盤リソースの作成（先に実行）

```bash
cd terraform/foundation
terraform init
terraform plan
terraform apply
```

### 4. アプリケーションリソースの作成（後に実行）

```bash
cd terraform/application
terraform init
terraform plan
terraform apply
```

## データソース連携

`application/`では、`terraform_remote_state`データソースを使用して`foundation/`の出力値を参照しています：

```hcl
data "terraform_remote_state" "foundation" {
    backend = "local"
    config = {
        path = "../foundation/terraform.tfstate"
    }
}
```

## 必要な変数

### foundation/で必要な変数
- `prefix`: リソース名プレフィックス（デフォルト: cm-kitagawa）
- `dagster_postgres_db`: PostgreSQLデータベース名
- `dagster_postgres_user`: PostgreSQLユーザー名
- `dagster_postgres_password`: PostgreSQLパスワード（機密情報）
- `dbt_env_secret_snowflake_account`: Snowflakeアカウント
- `dbt_env_secret_snowflake_user`: Snowflakeユーザー
- `dbt_env_secret_snowflake_private_key`: Snowflake秘密鍵（機密情報）
- `dbt_env_secret_snowflake_private_key_passphrase`: 秘密鍵パスフレーズ（機密情報）

### application/で必要な変数
- `prefix`: リソース名プレフィックス（デフォルト: cm-kitagawa）

## 注意事項

1. 実行順序: 必ずfoundation → applicationの順で実行してください
2. 状態ファイル: foundation/terraform.tfstateが存在することを確認してからapplicationを実行してください
3. 機密情報: パスワードや秘密鍵は`terraform.tfvars`ファイルで管理し、バージョン管理に含めないでください