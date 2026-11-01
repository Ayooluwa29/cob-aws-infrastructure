locals {
  groups = {
    junior-developer = {
      policy_keys = ["baseline", "platform-describe", "app-s3-read"]
    }
    senior-developer = {
      policy_keys = ["baseline", "platform-describe", "app-s3-read", "app-operate"]
    }
    junior-data-engineer = {
      policy_keys = ["baseline", "platform-describe", "data-lake-read", "glue-catalog-read", "glue-pipeline-read", "athena-query"]
    }
    senior-data-engineer = {
      policy_keys = [
        "baseline", "platform-describe", "data-lake-read", "data-lake-write",
        "glue-catalog-read", "glue-pipeline-read", "glue-operate", "athena-query", "redshift-query",
      ]
    }
    junior-analyst = {
      policy_keys = ["baseline", "athena-query", "glue-catalog-read", "curated-read"]
    }
    senior-analyst = {
      policy_keys = ["baseline", "athena-query", "glue-catalog-read", "curated-read", "redshift-query", "analyst-sandbox"]
    }
  }
}