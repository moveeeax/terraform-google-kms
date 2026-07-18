terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "kms" {
  source = "../.."

  project_id = var.project_id
  name       = "example-keyring"
  location   = var.region

  keys = {
    "app-key" = {
      rotation_period = "7776000s"
    }
  }
}

variable "project_id" {
  description = "Project ID to deploy the example key ring into."
  type        = string
}

variable "region" {
  description = "Region for the google provider and key ring location."
  type        = string
  default     = "us-central1"
}

output "key_ring_id" {
  value = module.kms.key_ring_id
}
