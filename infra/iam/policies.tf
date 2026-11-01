locals {
  policies = {

    # ---------- Everyone: self-service + mandatory MFA ----------
    baseline = {
      description = "Own password and MFA only; everything else denied until signed in with MFA"
      statements = [
        {
          sid       = "ConsoleBasics"
          actions   = ["iam:GetAccountPasswordPolicy", "iam:GetAccountSummary", "iam:ListVirtualMFADevices", "s3:ListAllMyBuckets"]
          resources = ["*"]
        },
        {
          sid = "ManageOwnPasswordAndMfa"
          actions = [
            "iam:ChangePassword", "iam:GetUser", "iam:ListMFADevices",
            "iam:CreateVirtualMFADevice", "iam:DeleteVirtualMFADevice",
            "iam:EnableMFADevice", "iam:DeactivateMFADevice", "iam:ResyncMFADevice",
          ]
          resources = [
            "arn:aws:iam::${local.account_id}:user/&{aws:username}",
            "arn:aws:iam::${local.account_id}:mfa/&{aws:username}",
          ]
        },
        {
          sid    = "DenyEverythingElseWithoutMfa"
          effect = "Deny"
          not_actions = [
            "iam:CreateVirtualMFADevice", "iam:EnableMFADevice", "iam:GetUser", "iam:ListMFADevices",
            "iam:ListVirtualMFADevices", "iam:ResyncMFADevice", "iam:ChangePassword",
            "iam:GetAccountPasswordPolicy", "sts:GetSessionToken",
          ]
          resources  = ["*"]
          conditions = [{ test = "BoolIfExists", variable = "aws:MultiFactorAuthPresent", values = ["false"] }]
        },
      ]
    }

    # ---------- Developers and data engineers: see what is running ----------
    platform-describe = {
      description = "Read-only view of compute, network, database and logs for COB"
      statements = [
        {
          sid = "DescribeRuntime"
          actions = [
            "ec2:Describe*", "ecs:Describe*", "ecs:List*", "ecr:Describe*", "ecr:List*",
            "lambda:GetFunction", "lambda:GetFunctionConfiguration", "lambda:ListFunctions", "lambda:ListTags",
            "rds:Describe*", "rds:ListTagsForResource", "redshift:Describe*", "elasticloadbalancing:Describe*",
          ]
          resources  = ["*"]
          conditions = local.region_only
        },
        {
          sid        = "ReadMetrics"
          actions    = ["cloudwatch:GetMetricData", "cloudwatch:GetMetricStatistics", "cloudwatch:ListMetrics", "cloudwatch:DescribeAlarms"]
          resources  = ["*"]
          conditions = local.region_only
        },
        {
          sid       = "ListLogGroups"
          actions   = ["logs:DescribeLogGroups", "logs:GetQueryResults"]
          resources = ["*"]
        },
        {
          sid       = "ReadCobLogs"
          actions   = ["logs:DescribeLogStreams", "logs:GetLogEvents", "logs:FilterLogEvents", "logs:StartQuery", "logs:StopQuery"]
          resources = local.log_groups
        },
      ]
    }

    # ---------- Developers ----------
    app-s3-read = {
      description = "Read application buckets"
      statements = [
        { sid = "ListAppBuckets", actions = ["s3:ListBucket", "s3:GetBucketLocation"], resources = local.app_buckets },
        { sid = "ReadAppObjects", actions = ["s3:GetObject", "s3:GetObjectVersion"], resources = local.app_objects },
      ]
    }

    app-operate = {
      description = "Operate COB application workloads (no infrastructure creation)"
      statements = [
        {
          sid       = "DeployFunctions"
          actions   = ["lambda:InvokeFunction", "lambda:UpdateFunctionCode", "lambda:UpdateFunctionConfiguration", "lambda:PublishVersion"]
          resources = local.lambda_functions
        },
        {
          sid       = "OperateEcs"
          actions   = ["ecs:UpdateService", "ecs:StopTask", "ecs:ExecuteCommand"]
          resources = local.ecs_resources
        },
        {
          sid       = "EcrLogin"
          actions   = ["ecr:GetAuthorizationToken"]
          resources = ["*"]
        },
        {
          sid = "PushAndPullImages"
          actions = [
            "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
            "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer",
          ]
          resources = local.ecr_repos
        },
        {
          sid        = "PowerCycleTaggedInstances"
          actions    = ["ec2:StartInstances", "ec2:StopInstances", "ec2:RebootInstances"]
          resources  = local.ec2_instances
          conditions = local.project_tagged
        },
        {
          sid        = "SessionManagerToTaggedInstances"
          actions    = ["ssm:StartSession"]
          resources  = local.ec2_instances
          conditions = local.project_tagged
        },
        {
          sid       = "SessionManagerDocument"
          actions   = ["ssm:StartSession"]
          resources = ["arn:aws:ssm:${local.region}::document/SSM-SessionManagerRunShell"]
        },
        {
          sid       = "ManageOwnSessions"
          actions   = ["ssm:TerminateSession", "ssm:ResumeSession"]
          resources = ["arn:aws:ssm:*:*:session/&{aws:username}-*"]
        },
        {
          sid       = "WriteAppObjects"
          actions   = ["s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload"]
          resources = local.app_objects
        },
      ]
    }

    # ---------- Data engineers ----------
    data-lake-read = {
      description = "Read all data buckets"
      statements = [
        { sid = "ListDataBuckets", actions = ["s3:ListBucket", "s3:GetBucketLocation"], resources = local.data_buckets },
        { sid = "ReadDataObjects", actions = ["s3:GetObject", "s3:GetObjectVersion"], resources = local.data_objects },
      ]
    }

    data-lake-write = {
      description = "Write to data buckets"
      statements = [
        { sid = "WriteDataObjects", actions = ["s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload"], resources = local.data_objects },
      ]
    }

    glue-pipeline-read = {
      description = "See Glue jobs, crawlers and triggers and their run history"
      statements = [
        {
          sid       = "ReadCobPipelines"
          actions   = ["glue:GetJob", "glue:GetJobRun", "glue:GetJobRuns", "glue:GetCrawler", "glue:GetCrawlerMetrics", "glue:GetTrigger"]
          resources = local.glue_pipeline
        },
        {
          sid       = "ListPipelines"
          actions   = ["glue:GetJobs", "glue:GetCrawlers", "glue:GetTriggers"]
          resources = ["*"]
        },
      ]
    }

    glue-operate = {
      description = "Run Glue jobs/crawlers and maintain tables in COB databases"
      statements = [
        {
          sid = "RunPipelines"
          actions = [
            "glue:StartJobRun", "glue:BatchStopJobRun", "glue:StartCrawler", "glue:StopCrawler",
            "glue:StartTrigger", "glue:StopTrigger",
          ]
          resources = local.glue_pipeline
        },
        {
          sid = "MaintainTables"
          actions = [
            "glue:CreateTable", "glue:UpdateTable", "glue:DeleteTable",
            "glue:CreatePartition", "glue:BatchCreatePartition", "glue:UpdatePartition",
            "glue:BatchUpdatePartition", "glue:DeletePartition", "glue:BatchDeletePartition",
          ]
          resources = local.glue_catalog
        },
      ]
    }

    # ---------- Data engineers and analysts ----------
    glue-catalog-read = {
      description = "Read COB databases and tables in the Glue Data Catalog"
      statements = [
        {
          sid = "ReadCatalog"
          actions = [
            "glue:GetDatabase", "glue:GetDatabases", "glue:GetTable", "glue:GetTables",
            "glue:GetPartition", "glue:GetPartitions", "glue:BatchGetPartition", "glue:SearchTables",
          ]
          resources = local.glue_catalog
        },
      ]
    }

    athena-query = {
      description = "Run queries in the COB analytics workgroup"
      statements = [
        {
          sid = "RunQueries"
          actions = [
            "athena:StartQueryExecution", "athena:StopQueryExecution", "athena:GetQueryExecution",
            "athena:GetQueryResults", "athena:GetQueryResultsStream", "athena:ListQueryExecutions",
            "athena:BatchGetQueryExecution", "athena:GetWorkGroup",
            "athena:ListNamedQueries", "athena:GetNamedQuery", "athena:BatchGetNamedQuery",
          ]
          resources = local.athena_workgroup
        },
        {
          sid       = "BrowseCatalogInAthena"
          actions   = ["athena:GetDataCatalog", "athena:ListDatabases", "athena:GetDatabase", "athena:GetTableMetadata", "athena:ListTableMetadata"]
          resources = local.athena_catalog
        },
        {
          sid       = "ListWorkgroups"
          actions   = ["athena:ListWorkGroups", "athena:ListDataCatalogs"]
          resources = ["*"]
        },
        {
          sid       = "ResultsBucket"
          actions   = ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"]
          resources = local.results_bucket
        },
        {
          sid       = "ResultsObjects"
          actions   = ["s3:GetObject", "s3:PutObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]
          resources = local.results_objects
        },
      ]
    }

    # ---------- Analysts ----------
    curated-read = {
      description = "Read only the curated/ prefix of data buckets"
      statements = [
        {
          sid        = "ListCuratedPrefix"
          actions    = ["s3:ListBucket"]
          resources  = local.data_buckets
          conditions = [{ test = "StringLike", variable = "s3:prefix", values = ["curated", "curated/*"] }]
        },
        { sid = "BucketLocation", actions = ["s3:GetBucketLocation"], resources = local.data_buckets },
        { sid = "ReadCuratedObjects", actions = ["s3:GetObject"], resources = local.curated_objects },
      ]
    }

    analyst-sandbox = {
      description = "Senior analysts: create tables and saved queries in the sandbox"
      statements = [
        {
          sid       = "SandboxTables"
          actions   = ["glue:CreateTable", "glue:UpdateTable", "glue:DeleteTable", "glue:CreatePartition", "glue:BatchCreatePartition"]
          resources = local.glue_sandbox
        },
        {
          sid       = "SavedQueries"
          actions   = ["athena:CreateNamedQuery", "athena:UpdateNamedQuery", "athena:DeleteNamedQuery"]
          resources = local.athena_workgroup
        },
        {
          sid        = "ListSandboxPrefix"
          actions    = ["s3:ListBucket"]
          resources  = local.data_buckets
          conditions = [{ test = "StringLike", variable = "s3:prefix", values = ["sandbox", "sandbox/*"] }]
        },
        {
          sid       = "SandboxObjects"
          actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload"]
          resources = local.sandbox_objects
        },
      ]
    }

    # ---------- Senior data engineers and senior analysts ----------
    redshift-query = {
      description = "Run SQL on COB Redshift clusters through the Data API (database GRANTs decide what data is visible)"
      statements = [
        {
          sid       = "ExecuteOnCobClusters"
          actions   = ["redshift-data:ExecuteStatement", "redshift-data:BatchExecuteStatement", "redshift-data:ListDatabases", "redshift-data:ListSchemas", "redshift-data:ListTables", "redshift-data:DescribeTable"]
          resources = local.redshift_cluster
        },
        {
          sid       = "OwnStatementsOnly"
          actions   = ["redshift-data:DescribeStatement", "redshift-data:GetStatementResult", "redshift-data:CancelStatement"]
          resources = ["*"]
          conditions = [{
            test     = "StringEquals"
            variable = "redshift-data:statement-owner-iam-userid"
            values   = ["&{aws:userid}"]
          }]
        },
        {
          sid       = "ListOwnStatements"
          actions   = ["redshift-data:ListStatements"]
          resources = ["*"]
        },
        {
          sid       = "IamBasedDbLogin"
          actions   = ["redshift:GetClusterCredentialsWithIAM"]
          resources = local.redshift_dbname
        },
      ]
    }
  }
}