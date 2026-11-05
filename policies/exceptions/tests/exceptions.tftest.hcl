# Run from the policies/exceptions folder:  terraform init && terraform test
# Syntax: Terraform Docs, "Tests" (https://developer.hashicorp.com/terraform/language/tests).
# Each bad case breaks one rule and expects that rule's output to fail.

variables {
  today = "2026-11-05T00:00:00Z"
}

run "real_register_passes_on_a_day_inside_the_window" {
  command = plan
  variables {
    register_json = file("register.json")
  }
  assert {
    condition     = output.exception_count == 1
    error_message = "The register has one exception."
  }
}

run "e4_the_same_register_fails_after_the_end_date" {
  command = plan
  variables {
    register_json = file("register.json")
    today         = "2027-01-01T00:00:00Z"
  }
  expect_failures = [output.check_not_expired]
}

run "e1_missing_field" {
  command = plan
  variables {
    register_json = "{\"exceptions\":[{\"id\":\"EXC-9\",\"rule\":\"r\",\"scope\":\"s\",\"owner\":\"a\",\"approved_by\":\"b\",\"approved_on\":\"2026-11-04T00:00:00Z\",\"expires\":\"2026-12-04T00:00:00Z\"}]}"
  }
  expect_failures = [output.check_fields]
}

run "e1_date_is_not_rfc3339" {
  command = plan
  variables {
    register_json = "{\"exceptions\":[{\"id\":\"EXC-9\",\"rule\":\"r\",\"scope\":\"s\",\"owner\":\"a\",\"reason\":\"x\",\"approved_by\":\"b\",\"approved_on\":\"4 Nov 2026\",\"expires\":\"2026-12-04T00:00:00Z\"}]}"
  }
  expect_failures = [output.check_fields]
}

run "e2_owner_approves_own_exception" {
  command = plan
  variables {
    register_json = "{\"exceptions\":[{\"id\":\"EXC-9\",\"rule\":\"r\",\"scope\":\"s\",\"owner\":\"a\",\"reason\":\"x\",\"approved_by\":\"a\",\"approved_on\":\"2026-11-04T00:00:00Z\",\"expires\":\"2026-12-04T00:00:00Z\"}]}"
  }
  expect_failures = [output.check_approval]
}

run "e3_longer_than_90_days" {
  command = plan
  variables {
    register_json = "{\"exceptions\":[{\"id\":\"EXC-9\",\"rule\":\"r\",\"scope\":\"s\",\"owner\":\"a\",\"reason\":\"x\",\"approved_by\":\"b\",\"approved_on\":\"2026-11-04T00:00:00Z\",\"expires\":\"2027-06-04T00:00:00Z\"}]}"
  }
  expect_failures = [output.check_duration]
}

run "e3_ends_before_it_starts" {
  command = plan
  variables {
    today         = "2026-09-15T00:00:00Z"
    register_json = "{\"exceptions\":[{\"id\":\"EXC-9\",\"rule\":\"r\",\"scope\":\"s\",\"owner\":\"a\",\"reason\":\"x\",\"approved_by\":\"b\",\"approved_on\":\"2026-11-04T00:00:00Z\",\"expires\":\"2026-10-01T00:00:00Z\"}]}"
  }
  expect_failures = [output.check_duration]
}

run "e5_duplicate_ids" {
  command = plan
  variables {
    register_json = "{\"exceptions\":[{\"id\":\"EXC-1\",\"rule\":\"r\",\"scope\":\"s\",\"owner\":\"a\",\"reason\":\"x\",\"approved_by\":\"b\",\"approved_on\":\"2026-11-04T00:00:00Z\",\"expires\":\"2026-12-04T00:00:00Z\"},{\"id\":\"EXC-1\",\"rule\":\"r\",\"scope\":\"s\",\"owner\":\"a\",\"reason\":\"x\",\"approved_by\":\"b\",\"approved_on\":\"2026-11-04T00:00:00Z\",\"expires\":\"2026-12-04T00:00:00Z\"}]}"
  }
  expect_failures = [output.check_unique_ids]
}

run "rejects_text_that_is_not_json" {
  command = plan
  variables {
    register_json = "not json"
  }
  expect_failures = [var.register_json]
}
