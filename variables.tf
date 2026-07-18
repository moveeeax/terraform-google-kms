variable "project_id" {
  description = "ID of the project in which to create the key ring."
  type        = string
}

variable "name" {
  description = "Name of the KMS key ring."
  type        = string
}

variable "location" {
  description = "Location of the key ring, e.g. us-central1 or global."
  type        = string
}

variable "keys" {
  description = "Crypto keys to create in the key ring, keyed by key name."
  type = map(object({
    rotation_period = optional(string, "7776000s")
    purpose         = optional(string, "ENCRYPT_DECRYPT")
    algorithm       = optional(string, "GOOGLE_SYMMETRIC_ENCRYPTION")
  }))
  default = {}
}

variable "labels" {
  description = "Labels applied to the crypto keys."
  type        = map(string)
  default     = {}
}
