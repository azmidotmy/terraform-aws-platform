# policies/exceptions

The exception register as code (`docs/03`, section 3.4).

*Like a visitor pass: every exception has an expiry date, and a check fails when a pass has expired.*

- `register.json`: one row per exception, with an owner, an approver and an end date.
- `main.tf`: five rules (E1 to E5) written as output preconditions.
- `tests/exceptions.tftest.hcl`: nine tests. One passes with the real register, and the others break one rule at a time.

```
cd policies/exceptions
terraform init
terraform test
```

Executed on Terraform v1.17.1: 9 passed, 0 failed. Needs Terraform 1.7 or later.

Use in a pipeline: `terraform plan -var "register_json=$(cat register.json)"`. The plan fails with the E4 message once an exception has passed its end date. To test another day, add `-var 'today=2027-01-01T00:00:00Z'`.
