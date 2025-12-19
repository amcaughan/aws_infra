# aws_infra

Personal AWS account infrastructure managed with Terragrunt and Terraform.

This repository defines a small, opinionated baseline focused on:
- account-level security visibility
- high-signal alerts
- cost guardrails

This is just for me personally to manage my AWS account.

What’s in here

- CloudTrail with targeted CloudWatch alarms (root login, IAM changes, trail tampering)
- GuardDuty with optional automated response for EC2 cryptomining
- Account-wide S3 public access block
- Cost controls (Budgets, Cost Anomaly Detection)
- Secure S3 patterns for logs and state
- Terragrunt-based layout for clarity and dependency management

What’s intentionally not in here

- Automated apply from CI (this core infra repo would need basically full admin, that's too unsafe)
  Changes are applied manually to keep a clear human approval boundary
- Multi-account / Organizations setup (Not trying to create a pile of spaghetti, this is for small use cases)

Usage

This repo is applied manually via Terragrunt. CI is limited to static analysis and security scanning.

If you copy pieces from this repo, do so deliberately. Most modules are tightly scoped to a single-account context.

License

MIT
