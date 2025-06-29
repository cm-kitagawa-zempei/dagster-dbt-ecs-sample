import os
from pathlib import Path

from dagster_dbt import DbtProject

# AWS環境ではパッケージ化されたプロジェクトを使用、開発環境では元のプロジェクトを使用
is_aws = os.getenv("DAGSTER_ENV") == "AWS"
print(f"is_aws: {is_aws}")

if is_aws:
    # AWS環境: packaged_project_dirをproject_dirとして使用
    project_dir = Path(__file__).joinpath("..", "..", "dbt-project").resolve()
    packaged_project_dir = project_dir
else:
    # ローカル環境: ローカルではjaffle_shopを使用
    project_dir = Path(__file__).joinpath("..", "..", "..", "jaffle_shop").resolve()
    packaged_project_dir = Path(__file__).joinpath("..", "..", "dbt-project").resolve()

jaffle_shop_project = DbtProject(
    project_dir=project_dir,
    packaged_project_dir=packaged_project_dir,
)
jaffle_shop_project.prepare_if_dev()
