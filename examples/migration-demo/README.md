# migration-demo

A local demo of the tools in `docs/04-migration.md`. It needs no cloud account.

```
./run-demo.sh
```

It works in a temporary folder and prints the result of each step:

1. Create a resource with state in an old local path.
2. Move the state with `terraform init -migrate-state` and check that `terraform plan -detailed-exitcode` returns `0`.
3. Rename the resource with a `moved` block. The plan says "has moved" and nothing is destroyed.
4. Remove the resource from state, then bring it back with an `import` block.
5. Run the verification gate: exit code `0`.

It uses the built-in `terraform_data` resource, so no provider is downloaded. Tested on Terraform v1.17.1 and v1.5.7.

**What this does not show:** the S3 backend, real AWS resources, or `use_lockfile`. See `docs/04`, section 4.6.
