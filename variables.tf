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
  description = <<-EOT
    Crypto keys to create in the key ring, keyed by key name.

    * `rotation_period` - Automatic rotation period. Only supported for keys
      with purpose `ENCRYPT_DECRYPT` (defaults to 90 days) and
      `RAW_ENCRYPT_DECRYPT` (unset by default). Must be at least 86400s.
    * `purpose` - Immutable key purpose. Must match `algorithm`.
    * `algorithm` - Algorithm of the key versions created from this key.
    * `protection_level` - `SOFTWARE` or `HSM`. Immutable.
    * `destroy_scheduled_duration` - How long key versions sit in
      DESTROY_SCHEDULED before being permanently destroyed. Immutable, and the
      Cloud KMS default of 30 days applies when it is unset.
  EOT

  type = map(object({
    rotation_period            = optional(string)
    purpose                    = optional(string, "ENCRYPT_DECRYPT")
    algorithm                  = optional(string, "GOOGLE_SYMMETRIC_ENCRYPTION")
    protection_level           = optional(string, "SOFTWARE")
    destroy_scheduled_duration = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, key in var.keys : contains([
        "ENCRYPT_DECRYPT",
        "RAW_ENCRYPT_DECRYPT",
        "ASYMMETRIC_SIGN",
        "ASYMMETRIC_DECRYPT",
        "MAC",
        "KEY_ENCAPSULATION",
      ], key.purpose)
    ])
    error_message = "Each key's purpose must be one of ENCRYPT_DECRYPT, RAW_ENCRYPT_DECRYPT, ASYMMETRIC_SIGN, ASYMMETRIC_DECRYPT, MAC or KEY_ENCAPSULATION."
  }

  # A purpose/algorithm mismatch is only rejected by the API at apply time, once
  # the key ring already exists. Catch it during plan instead.
  validation {
    condition = alltrue([
      for name, key in var.keys : anytrue([
        key.purpose == "ENCRYPT_DECRYPT" && key.algorithm == "GOOGLE_SYMMETRIC_ENCRYPTION",
        key.purpose == "RAW_ENCRYPT_DECRYPT" && startswith(key.algorithm, "AES_"),
        key.purpose == "ASYMMETRIC_SIGN" && anytrue([
          startswith(key.algorithm, "EC_SIGN_"),
          startswith(key.algorithm, "RSA_SIGN_"),
          startswith(key.algorithm, "PQ_SIGN_"),
        ]),
        key.purpose == "ASYMMETRIC_DECRYPT" && startswith(key.algorithm, "RSA_DECRYPT_"),
        key.purpose == "MAC" && startswith(key.algorithm, "HMAC_"),
        key.purpose == "KEY_ENCAPSULATION" && startswith(key.algorithm, "KEM_"),
      ])
    ])
    error_message = "Each key's algorithm must match its purpose: GOOGLE_SYMMETRIC_ENCRYPTION for ENCRYPT_DECRYPT, AES_* for RAW_ENCRYPT_DECRYPT, EC_SIGN_*/RSA_SIGN_*/PQ_SIGN_* for ASYMMETRIC_SIGN, RSA_DECRYPT_* for ASYMMETRIC_DECRYPT, HMAC_* for MAC, KEM_* for KEY_ENCAPSULATION."
  }

  validation {
    condition = alltrue([
      for name, key in var.keys : contains(["SOFTWARE", "HSM"], key.protection_level)
    ])
    error_message = "Each key's protection_level must be SOFTWARE or HSM. EXTERNAL and EXTERNAL_VPC need an EKM connection, which this module does not manage."
  }

  # The API rejects rotation_period on keys that cannot rotate automatically.
  validation {
    condition = alltrue([
      for name, key in var.keys :
      key.rotation_period == null || contains(["ENCRYPT_DECRYPT", "RAW_ENCRYPT_DECRYPT"], key.purpose)
    ])
    error_message = "rotation_period may only be set on symmetric keys (purpose ENCRYPT_DECRYPT or RAW_ENCRYPT_DECRYPT); Cloud KMS does not rotate keys of other purposes automatically."
  }

  validation {
    condition = alltrue([
      for name, key in var.keys : key.rotation_period == null || (
        can(regex("^[0-9]+(\\.[0-9]{1,9})?s$", key.rotation_period)) &&
        try(tonumber(trimsuffix(key.rotation_period, "s")) >= 86400, false)
      )
    ])
    error_message = "rotation_period must be a duration in seconds such as \"7776000s\", and at least 86400s (24 hours)."
  }

  validation {
    condition = alltrue([
      for name, key in var.keys : key.destroy_scheduled_duration == null || (
        can(regex("^[0-9]+(\\.[0-9]{1,9})?s$", key.destroy_scheduled_duration)) &&
        try(tonumber(trimsuffix(key.destroy_scheduled_duration, "s")) >= 86400, false)
      )
    ])
    error_message = "destroy_scheduled_duration must be a duration in seconds such as \"2592000s\", and at least 86400s (24 hours)."
  }
}

variable "prevent_destroy" {
  description = <<-EOT
    Protect the crypto keys with `lifecycle { prevent_destroy = true }`. When
    true (the default), `terraform destroy` and any change that would replace a
    key fail at plan time, because destroying a crypto key schedules every one
    of its versions for destruction and the key material cannot be recovered
    once that window elapses. Set to false only for throwaway environments.

    Flipping this on an existing deployment moves the keys between two resource
    addresses; while they are protected that move is rejected at plan time
    rather than silently destroying them.
  EOT
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels applied to the crypto keys."
  type        = map(string)
  default     = {}
}
