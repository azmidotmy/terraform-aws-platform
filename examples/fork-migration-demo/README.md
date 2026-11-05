# fork-migration-demo

A local demo of replacing a forked module with the central module, from `docs/04`, section 4.6. It needs no cloud account.

*Like changing the name of your street. Without a letter, the postman thinks the old house is gone. With the letter (`moved`), he knows it is the same house.*

```
./run-demo.sh
```

It works in a temporary folder and prints each step:

1. A team applies with a forked module.
2. The team points to the central module, which names a resource differently, **without** a `moved` block. The plan wants to destroy and create (`1 to add, 1 to destroy`). It is not applied.
3. The central module carries a `moved` block. The plan only says "has moved" (`0 to add, 0 to change, 0 to destroy`).
4. The team renames its module label with a `moved` block in the root module. The state follows.
5. Verification gate: `terraform plan -detailed-exitcode` returns `0`.

It uses the built-in `terraform_data` resource, so no provider is downloaded. Tested on Terraform v1.17.1.

**What this does not show:** real AWS resources, or the S3 backend.
