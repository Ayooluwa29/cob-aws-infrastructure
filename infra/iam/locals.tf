data "aws_caller_identity" "current" {}

locals {
  prefix     = "cob-dev"
  region     = "eu-west-2"
  account_id = data.aws_caller_identity.current.account_id

  # ---- S3 ----
  app_buckets     = ["arn:aws:s3:::${local.prefix}-app-*"]
  app_objects     = ["arn:aws:s3:::${local.prefix}-app-*/*"]
  data_buckets    = ["arn:aws:s3:::${local.prefix}-data-*"]
  data_objects    = ["arn:aws:s3:::${local.prefix}-data-*/*"]
  curated_objects = ["arn:aws:s3:::${local.prefix}-data-*/curated/*"]
  sandbox_objects = ["arn:aws:s3:::${local.prefix}-data-*/sandbox/*"]
  results_bucket  = ["arn:aws:s3:::${local.prefix}-athena-results"]
  results_objects = ["arn:aws:s3:::${local.prefix}-athena-results/analytics/*"]

  # ---- Glue (database names use underscores: cob_dev_*) ----
  glue_prefix   = replace(local.prefix, "-", "_")
  glue_arn      = "arn:aws:glue:${local.region}:${local.account_id}"
  glue_catalog  = ["${local.glue_arn}:catalog", "${local.glue_arn}:database/${local.glue_prefix}_*", "${local.glue_arn}:table/${local.glue_prefix}_*/*"]
  glue_sandbox  = ["${local.glue_arn}:catalog", "${local.glue_arn}:database/${local.glue_prefix}_sandbox", "${local.glue_arn}:table/${local.glue_prefix}_sandbox/*"]
  glue_pipeline = ["${local.glue_arn}:job/${local.prefix}-*", "${local.glue_arn}:crawler/${local.prefix}-*", "${local.glue_arn}:trigger/${local.prefix}-*"]

  # ---- Athena / Redshift ----
  athena_workgroup = ["arn:aws:athena:${local.region}:${local.account_id}:workgroup/${local.prefix}-analytics"]
  athena_catalog   = ["arn:aws:athena:${local.region}:${local.account_id}:datacatalog/AwsDataCatalog"]
  redshift_cluster = ["arn:aws:redshift:${local.region}:${local.account_id}:cluster:${local.prefix}-*"]
  redshift_dbname  = ["arn:aws:redshift:${local.region}:${local.account_id}:dbname:${local.prefix}-*/*"]

  # ---- Compute ----
  lambda_functions = ["arn:aws:lambda:${local.region}:${local.account_id}:function:${local.prefix}-*"]
  ecs_resources = [
    "arn:aws:ecs:${local.region}:${local.account_id}:cluster/${local.prefix}-*",
    "arn:aws:ecs:${local.region}:${local.account_id}:service/${local.prefix}-*/*",
    "arn:aws:ecs:${local.region}:${local.account_id}:task/${local.prefix}-*/*",
  ]
  ecr_repos = ["arn:aws:ecr:${local.region}:${local.account_id}:repository/${local.prefix}-*"]
  ec2_instances = ["arn:aws:ec2:${local.region}:${local.account_id}:instance/*"]

  log_groups = flatten([
    for g in ["/aws/lambda/${local.prefix}-*", "/ecs/${local.prefix}-*"] : [
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:${g}",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:${g}:*",
    ]
  ])

  # ---- Reusable conditions ----
  region_only = [{ test = "StringEquals", variable = "aws:RequestedRegion", values = [local.region] }]
  project_tagged = [
    { test = "StringEquals", variable = "aws:ResourceTag/Project", values = ["COB"] },
    { test = "StringEquals", variable = "aws:ResourceTag/Environment", values = ["dev"] },
  ]
}