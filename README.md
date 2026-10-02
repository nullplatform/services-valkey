# services-valkey

Nullplatform service that provisions **AWS ElastiCache Serverless for Valkey** caches and connects them to applications.

## What it does

Creates a serverless Valkey cache per service instance, reachable only from inside the VPC, and hands each linked application its own user and password.

| Capability | Notes |
| :---- | :---- |
| Engine | Valkey 8, serverless: no node sizing, scales with usage |
| Network | Placed in the VPC and subnets of the `vpc` provider; port 6379 open to the VPC CIDR only; the agent role can only touch security groups tagged `managed-by=nullplatform` |
| Authentication | RBAC user group per cache; one user per link |
| Encryption | At rest with a dedicated KMS key per cache, or a shared key given to the agent; in transit always |
| Connection | Endpoint, port and a ready-to-use TLS connection URL exported to linked applications |
| Metrics | Six CloudWatch metrics of the cache, queried for the time range picked in the UI |

## Links

| Link | What it does |
| :---- | :---- |
| `create-serverless-valkey-link` | Creates a Valkey user with full access (`on ~* +@all`), adds it to the cache's user group and exports `user_name` and `user_password` (secret) to the application. |

## Layout

```
valkey/
├── specs/
│   ├── service-spec.json.tpl      # attributes shown to the developer
│   ├── links/connect.json.tpl
│   └── requirements/aws/          # IAM role the agent assumes
├── deployment/                    # security group, user group and the cache
├── permissions/                   # link: per-link user and password
├── scripts/aws/                   # context building and tofu execution
│   └── tests/aws/                 # BATS unit tests
├── utils/                         # assume role helpers
├── entrypoint/                    # action routing
├── workflows/aws/                 # one file per action
└── values.yaml                    # static config, not exposed in the UI
```

## Installation

**1. Create the permissions role.** Apply `valkey/specs/requirements/aws` in the target AWS account:

```hcl
module "valkey_requirements" {
  source            = "git::https://github.com/nullplatform/services-valkey.git//valkey/specs/requirements/aws?ref=main"
  cluster_name      = "<nullplatform agent cluster>"
  state_bucket_name = "<existing S3 bucket for the tofu state>"
}
```

To apply it as a root module instead, copy `terraform.tfvars.example` to `terraform.tfvars` and fill it in — it lists every variable, with the optional ones commented out at their defaults.

**2. Publish the role.** Register `permissions_role_arn` in the nullplatform AWS IAM provider under the selector **`valkey`**, and allow the agent role to assume it.

**3. Create the state bucket.** Create a single S3 bucket that every valkey service shares for its tofu state, enable versioning on it, and pass its name to the requirements module as `state_bucket_name`. The agent must receive the same name in the environment variable `VALKEY_S3_STATE_BUCKET`. The service never creates or deletes this bucket: if it is missing, every action fails with a clear error.

Each service keeps its state under `services/valkey/<service id>/terraform.tfstate`, and each of its links under `services/valkey/<service id>/links/<link id>.tfstate`. Deleting a service removes that prefix and nothing else.

**4. Configure the network.** The service reads the region and the network from nullplatform providers, looked up for the service NRN and its dimensions:

- **`aws-configuration`** (`cloud-providers` category, from `tofu-modules//nullplatform/cloud/aws/cloud`) — `account.region`.
- **`aws-networking-configuration`** (`vpc` category, from `tofu-modules//nullplatform/cloud/aws/vpc`) — `vpc.id`, and in `vpc.subnets` the private subnets the cache is placed in.

```hcl
module "vpc_provider" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/cloud/aws/vpc?ref=<tag>"

  nrn                 = "organization=<id>:account=<id>"
  vpc_id              = "<vpc-id>"
  vpc_subnets         = ["<private-subnet-id-1>", "<private-subnet-id-2>"]
  vpc_security_groups = ["<node/cluster-security-group-id>"]
}
```

A cache that already exists keeps the VPC, subnets and region recorded in its state, so changing the provider never replaces it.

**5. Choose the encryption key.** Each cache gets its own KMS key by default and nothing else is needed. To put every cache on one existing key instead, give the agent its ARN in `VALKEY_KMS_KEY_ARN` and list the same ARN in the requirements module as `external_kms_key_arns`, which is what lets the role use it. The key is read only when the cache is created: ElastiCache cannot re-key a serverless cache, so changing the variable later leaves existing caches on the key they were created with.

**6. Register the service.** Point a `service_definition` at this repository with `service_path = "valkey"`, and add it to the agent's repository list. The `specs/install` module subscribes the agent channel to `service` and `telemetry` notifications; without `telemetry` the service shows no metrics.

## How it works

Every service instance keeps its Terraform state in its own S3 bucket (`np-service-<service-id>`), created on demand and removed when the service is deleted. Links use the same bucket under a separate key, so creating or removing a link never touches the cache state.

Before any AWS call, each workflow assumes the permissions role published in the IAM provider under the selector `valkey`, and every later step runs on the temporary credentials it returns. When the provider publishes no role for that selector, the agent keeps its own credentials and uses them directly — which is what makes local testing work, and what a setup that does not use assume-role relies on.

The cache name is `np-<service slug>-<first 5 characters of the service id>`, capped at 36 characters so the derived user group (`-ug`) stays within the ElastiCache limit. It is computed once and then frozen in the service attributes (`cache_name`): renaming the service never renames the cache, and the link workflow reads the same attribute to find the user group it has to join. The `np-` prefix is what scopes the permissions role to caches created by nullplatform.

Each link user is named `np-<link slug>-<first 5 characters of the link id>-user`. Its password is generated by Terraform, stored only in the link's state and attributes, and delivered to the application as a secret environment variable.

## Metrics

`metric:list` and `metric:data` notifications run `workflows/aws/metric-list.yaml` and `workflows/aws/metric.yaml`. The data workflow assumes the permissions role and reads `AWS/ElastiCache` with the dimension `clusterId = cache_name`, in the region of the cache ARN, for the requested `start_time`, `end_time` and `period` (rounded up to a multiple of 60 seconds).

| Metric | Statistic | Unit |
| :---- | :---- | :---- |
| `ElastiCacheProcessingUnits` | Sum | count |
| `BytesUsedForCache` | Maximum | bytes |
| `CacheHitRate` | Average | percent |
| `CurrConnections` | Maximum | count |
| `SuccessfulReadRequestLatency` | Average | microseconds |
| `ThrottledCmds` | Sum | count |

A service whose cache does not exist yet returns an empty series. A CloudWatch error fails the request instead of showing an empty graph.

## Connecting

Serverless caches always run with encryption in transit, so every client must connect over TLS.

Linked applications receive:

| Variable | From | |
| :---- | :---- | :---- |
| `ENDPOINT` | service | Cache hostname |
| `PORT` | service | `6379` |
| `USER_NAME` | link | Valkey user for this link |
| `USER_PASSWORD` | link | secret |
| `CONNECTION_URL` | link | `valkeys://<user>:<password>@<endpoint>:<port>`, secret |

Use `CONNECTION_URL` where the client accepts a connection string, or the individual variables otherwise. The `valkeys://` scheme is the TLS form and is understood by valkey-py and valkey-glide; clients that only accept the Redis scheme take the same URL as `rediss://`.

## Local testing

Set `aws_profile` in `values.yaml`, run `aws sso login --profile <name>`, and start the agent locally. With no IAM provider configured, the service runs on that profile's credentials.

Unit tests run with [bats-core](https://github.com/bats-core/bats-core):

```bash
bats valkey/scripts/tests/aws/ valkey/utils/tests/
```
