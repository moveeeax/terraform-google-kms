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

  # The keys created here are protected by lifecycle.prevent_destroy, so
  # `terraform destroy` on this example fails by design. See the "Destruction
  # semantics" section of the module README before tearing it down.
  keys = {
    # Symmetric encryption key, rotated every 90 days. Only the listed
    # members may use it; the grant is on this key, not on the project.
    "app-key" = {
      rotation_period      = "7776000s"
      encrypter_decrypters = var.app_key_users
    }

    # Asymmetric signing key. Signing keys cannot be rotated automatically, so
    # rotation_period must be left unset.
    "signing-key" = {
      purpose   = "ASYMMETRIC_SIGN"
      algorithm = "EC_SIGN_P256_SHA256"
    }
  }
}

variable "project_id" {
  description = "Project ID to deploy the example key ring into."
  type        = string
}

variable "app_key_users" {
  description = "Members allowed to encrypt and decrypt with app-key, e.g. [\"serviceAccount:service-123@gs-project-accounts.iam.gserviceaccount.com\"]."
  type        = list(string)
  default     = []
}

variable "region" {
  description = "Region for the google provider and key ring location."
  type        = string
  default     = "us-central1"
}

output "key_ring_id" {
  value = module.kms.key_ring_id
}

output "crypto_key_ids" {
  value = module.kms.crypto_key_ids
}
