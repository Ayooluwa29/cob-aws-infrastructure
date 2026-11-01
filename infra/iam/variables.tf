variable "project" {
  description = "Project short name, lower case. Used in every resource name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]*$", var.project))
    error_message = "project must be lower case letters and digits, starting with a letter."
  }
}

variable "environment" {
  description = "Environment name. Used in resource names and tag conditions."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be \"dev\" or \"prod\"."
  }
}

variable "region" {
  description = "AWS region for this stack's resources and policy scoping."
  type        = string
}