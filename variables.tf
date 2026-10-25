# Names, region, and tags for this build.
# The provider is already configured. Resource files read these values
# so a name is written once and reused everywhere.
#
# The state account lives in its own resource group. Destroying the group
# the pipeline manages does not delete the state file that destroy is using.

variable "location" {
  description = "Azure region for every resource in this build."
  type        = string
  default     = "East US"
}

variable "state_resource_group_name" {
  description = "Resource group that holds the remote state storage account."
  type        = string
  default     = "rg-tfpipe-state-zeon01"
}

variable "pipeline_resource_group_name" {
  description = "Empty resource group created locally so the pipeline can be granted access to it. The pipeline cannot create this group."
  type        = string
  default     = "rg-tfpipe-poc-zeon01"
}

variable "storage_account_name" {
  description = "Storage account for the Terraform state blob. Lowercase letters and digits only."
  type        = string
  default     = "sttfpipezeon01"
}

variable "storage_container_name" {
  description = "Blob container that holds the state file."
  type        = string
  default     = "tfstate"
}

variable "state_blob_name" {
  description = "Blob name of the Terraform state file inside the container."
  type        = string
  default     = "pipeline.tfstate"
}

variable "storage_account_tier" {
  description = "Performance tier of the state storage account."
  type        = string
  default     = "Standard"
}

variable "storage_replication_type" {
  description = "Replication of the state account. Locally redundant storage keeps copies in one datacenter."
  type        = string
  default     = "LRS"
}

variable "github_repository" {
  description = "GitHub repository that runs the pipeline, as owner/name."
  type        = string
  default     = "zsociety47/azure-terraform-pipeline-poc"
}

variable "application_display_name" {
  description = "Display name of the Entra app registration GitHub Actions uses to sign in."
  type        = string
  default     = "github-actions-azure-terraform-pipeline-poc"
}

variable "pull_request_credential_name" {
  description = "Name of the federated credential that allows a pull request to plan and test."
  type        = string
  default     = "github-pull-request"
}

variable "pull_request_subject" {
  description = "OpenID Connect subject Azure matches for a pull request. Letter case matters. GitHub includes the owner id and repository id."
  type        = string
  default     = "repo:zsociety47@122703085/azure-terraform-pipeline-poc@1428385149:pull_request"
}

variable "main_credential_name" {
  description = "Name of the federated credential that allows the main branch to apply."
  type        = string
  default     = "github-main"
}

variable "main_subject" {
  description = "OpenID Connect subject Azure matches for a push to the main branch. GitHub includes the owner id and repository id."
  type        = string
  default     = "repo:zsociety47@122703085/azure-terraform-pipeline-poc@1428385149:ref:refs/heads/main"
}

variable "tags" {
  description = "Base tags shared by every resource. lifetime and created are added per resource group in tags.tf."
  type        = map(string)
  default = {
    project = "azure-terraform-pipeline-poc"
    owner   = "zeon"
  }
}
