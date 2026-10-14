# Install: registering the Serverless Valkey service

This directory holds the reference OpenTofu/Terraform used to **install** Serverless Valkey on a nullplatform account. It registers the service specification, the link specification and the agent association (notification channel), so creating a Valkey service starts routing its actions to an agent.

It is a guide to copy, not a module to apply from here: it declares no provider. Configure the `nullplatform` provider in the root module where you use it.

This is separate from `../requirements/aws`, which creates the IAM role the agent assumes in the AWS account that holds the caches. See the Installation section of the top-level [`README.md`](../../../README.md) for the full order.

## Layout

```
install/
├── README.md          (this file)
└── aws/               working example
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── terraform.tfvars.example
```

## Using the example

```bash
cp -r valkey/specs/install/aws /path/to/your/infra/serverless-valkey
cd /path/to/your/infra/serverless-valkey
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

tofu init
tofu apply
```

`repository_branch` must be a pinned ref (a release tag or a commit SHA): the specs are read from that ref of this repository.

`tags_selectors` must match the tags of the agents that should pick up Valkey actions (the same selectors passed as `tags_selectors` to the `nullplatform/agent` tofu module).

The notification channel subscribes to `service` and `telemetry` notifications: without `telemetry` the service shows no metrics.

Run this once per nullplatform namespace. It only registers the service with the platform and creates no AWS infrastructure: caches are created per service, at `create` time, by `deployment/` with the role from `requirements/aws`.
