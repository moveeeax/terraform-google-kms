# Input validation: every case here would otherwise only be rejected by the
# Cloud KMS API during apply, after the key ring already exists.

mock_provider "google" {}

variables {
  project_id = "example-project"
  name       = "test-keyring"
  location   = "us-central1"
}

run "rejects_unknown_purpose" {
  command = plan

  variables {
    keys = {
      "bad" = { purpose = "SIGN_THINGS" }
    }
  }

  expect_failures = [var.keys]
}

run "rejects_purpose_algorithm_mismatch" {
  command = plan

  variables {
    keys = {
      # Default algorithm left in place, which is symmetric-only.
      "signer" = { purpose = "ASYMMETRIC_SIGN" }
    }
  }

  expect_failures = [var.keys]
}

run "rejects_unsupported_protection_level" {
  command = plan

  variables {
    keys = {
      "external" = { protection_level = "EXTERNAL" }
    }
  }

  expect_failures = [var.keys]
}

run "rejects_rotation_period_on_non_rotatable_key" {
  command = plan

  variables {
    keys = {
      "mac" = {
        purpose         = "MAC"
        algorithm       = "HMAC_SHA256"
        rotation_period = "7776000s"
      }
    }
  }

  expect_failures = [var.keys]
}

run "rejects_rotation_period_below_one_day" {
  command = plan

  variables {
    keys = {
      "app" = { rotation_period = "3600s" }
    }
  }

  expect_failures = [var.keys]
}

run "rejects_malformed_rotation_period" {
  command = plan

  variables {
    keys = {
      "app" = { rotation_period = "90d" }
    }
  }

  expect_failures = [var.keys]
}

run "rejects_malformed_destroy_scheduled_duration" {
  command = plan

  variables {
    keys = {
      "app" = { destroy_scheduled_duration = "30 days" }
    }
  }

  expect_failures = [var.keys]
}
