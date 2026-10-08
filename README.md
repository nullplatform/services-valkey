# services-valkey

Nullplatform service that provisions **AWS ElastiCache Serverless for Valkey** caches and connects them to applications.

## What it does

Creates a serverless Valkey cache per service instance, reachable from inside the VPC or (Valkey 9) over the internet, and hands each linked application its own user.

| Capability | Notes |
| :---- | :---- |
| Engine | Valkey 9 (default), 8 or 7, serverless: no node sizing, scales with usage. The major version can be upgraded, never downgraded |
| Settings | Like the console: **Use default settings** or **Customize default settings**, which opens connectivity (network type, VPC and subnets), security (encryption key, security groups), backup and usage limits |
| Connection type | **VPC** (default): placed in the VPC and subnets of the `vpc` provider, or the ones set in the customized settings; port 6379 open to the VPC CIDR only; the agent role can only touch security groups tagged `managed-by=nullplatform`. Customized security settings can select other security groups, which replace that default one. **Public** (Valkey 9 only): reachable over the internet, IAM authentication only. Fixed after creation |
| Network type | IPv4 (default), dual stack or IPv6. Fixed after creation |
| Authentication | RBAC user group per cache; one user per link: a password user on a VPC cache, an IAM-authenticated user on a public one |
| Encryption | At rest with a dedicated KMS key per cache, an existing key chosen in the customized security settings, or a shared key given to the agent; in transit always. Fixed after creation |
| Backups | Optional daily automatic backups, kept 1-35 days, at a chosen UTC time |
| Usage limits | Optional minimum and maximum for data storage (1-5,000 GB) and requests (1,000-15,000,000 ECPUs/s); 0 removes a single limit, "Not set" removes them all |
| Tags | Your tags plus the platform's, which yours cannot override |
| Connection | Endpoint, port and a ready-to-use TLS connection URL exported to linked applications |
| Metrics | Six CloudWatch metrics of the cache, queried for the time range picked in the UI |

## Links

| Link | What it does |
| :---- | :---- |
| `create-serverless-valkey-link` | Creates a Valkey user with full access (`on ~* +@all`) and adds it to the cache's user group. On a VPC cache it exports `user_name` and `user_password` (secret); on a public cache it also creates an IAM user allowed only to `elasticache:Connect` to this cache as this user, and exports its `access_key_id`, `secret_access_key` (secret), `aws_region` and `cache_name`. |

## Layout

```
valkey/
├── specs/
│   ├── service-spec.json.tpl      # attributes shown to the developer
│   ├── links/connect.json.tpl
│   └── requirements/aws/          # IAM role the agent assumes
├── deployment/                    # security group, KMS key, user group and the cache (aws, or awscc for a public cache)
├── permissions/                   # link: per-link user (password, or IAM user and access key)
├── scripts/aws/                   # context building and tofu execution
│   ├── smoke/verify_cache         # smoke test: the cache in AWS against the form
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

**Permissions to request.** These are the permissions the module grants. In an account that does not use assume role, grant them to the agent role instead.

| Area | Actions | Scope |
| :---- | :---- | :---- |
| Caches | `elasticache:*` | Serverless caches, user groups and users named `np-*` |
| Caches | `elasticache:CreateUserGroup`, `ModifyUserGroup`, `DeleteUserGroup`, `CreateServerlessCache`, `ModifyServerlessCache` | All users and user groups (needed to reference them) |
| Caches | `elasticache:Describe*`, `ListTagsForResource` | `*` |
| Caches | `iam:CreateServiceLinkedRole` | `AWSServiceRoleForElastiCache` only |
| Network | `ec2:CreateSecurityGroup`, `CreateTags` and rule management | Security groups tagged `managed-by=nullplatform` |
| Network | `ec2:CreateVpcEndpoint`, `ModifyVpcEndpoint`, `DeleteVpcEndpoints`, `CreateTags` | Endpoints ElastiCache Serverless creates for each cache (`AmazonElastiCacheManaged=true`) |
| Network | `ec2:Describe*` on VPCs, subnets, security groups, endpoints, route tables, prefix lists, ENIs and tags | `*` |
| Encryption | `kms:CreateKey` and key management | Keys tagged `managed-by=nullplatform`, aliases `nullplatform-valkey-*` |
| Encryption | `kms:DescribeKey`, `CreateGrant` for ElastiCache | Only the keys in `external_kms_key_arns`, when set |
| State | `s3:ListBucket`, `GetObject`, `PutObject`, `DeleteObject` and their versions | The `state_bucket_name` bucket |

The agent role itself always needs `cloudwatch:GetMetricStatistics` on `*`: metrics run on the agent's credentials, never on the permissions role, so they cost a single AWS call. The module attaches that policy to `agent_role_arn` and `additional_agent_role_arns`; set `attach_metrics_policy_to_agent_roles = false` if the agent role is managed elsewhere.

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

Each link user is named `np-<link slug>-<first 5 characters of the link id>-user`. On a VPC cache its password is generated by Terraform, stored only in the link's state and attributes, and delivered to the application as a secret environment variable. On a public cache the user has no password: the link creates an IAM user of the same name, and the application signs short-lived IAM tokens with its access key. Those IAM users live under the `/nullplatform/valkey/` path and must carry the `np-valkey-link-boundary` permissions boundary (created by the requirements module), which caps them at `elasticache:Connect`: the permissions role cannot create a link user without it, nor touch any IAM user outside that path.

The aws provider cannot set a serverless cache's connection type yet, so a public cache is created through Cloud Control with the `awscc` provider; a VPC cache keeps the `aws` resource, so caches created before this option existed are left untouched.

The platform merges every stored attribute into an update, so a field emptied in the form comes back with its old value. That is why the usage limits have an explicit **Not set / Set** choice and take 0 as "no limit", and why the update workflow ends with `clear_usage_limits`: the providers keep a single bound that is no longer set, so that step sends it to AWS as 0. A delete is built from the stored attributes alone, because the platform fills its parameters with the form defaults.

## Metrics

`metric:list` and `metric:data` notifications run `scripts/aws/list_metrics` and `scripts/aws/fetch_metric` directly from `entrypoint/metric`, without `np service workflow exec` and without assuming the permissions role. `metric:data` makes one AWS call, to CloudWatch: `AWS/ElastiCache` with the dimension `clusterId = cache_name`, in the region of the cache ARN, for the requested `start_time`, `end_time` and `period` (rounded up to a multiple of 60 seconds).

| Metric | Statistic | Unit |
| :---- | :---- | :---- |
| `ElastiCacheProcessingUnits` | Sum | count |
| `BytesUsedForCache` | Maximum | bytes |
| `CacheHitRate` | Average | percent |
| `CurrConnections` | Maximum | count |
| `SuccessfulReadRequestLatency` | Average | microseconds |
| `ThrottledCmds` | Sum | count |
| `AvailableECPUPerSecond` | 30,000 minus ECPU/s used | count |
| `BilledDataStorage` | Larger of storage used and 100 MB | bytes |

The ECPU/s ceiling is 30,000, what AWS supports on an empty cache, and 100 MB is the minimum data storage AWS meters for Valkey. Both have a value even on an idle cache. They ignore usage limits set on the cache by hand, which this service never configures.

A service whose cache does not exist yet returns an empty series. A CloudWatch error fails the request instead of showing an empty graph.

The service has no logs: `log:*` notifications run `scripts/aws/read_logs`, which answers with no entries. Telemetry scripts print nothing but their result, since stdout is the response. Workflow overrides do not apply to telemetry.

## Connecting

Serverless caches always run with encryption in transit, so every client must connect over TLS.

Linked applications receive:

| Variable | From | |
| :---- | :---- | :---- |
| `ENDPOINT` | service | Cache hostname |
| `PORT` | service | `6379` |
| `USER_NAME` | link | Valkey user for this link |
| `USER_PASSWORD` | link | secret |
| `CONNECTION_URL` | link | `valkeys://<user>:<password>@<endpoint>:<port>`, secret. On a public cache, `valkeys://<user>@<endpoint>:<port>` |
| `ACCESS_KEY_ID` | link | public cache only: access key of the link's IAM user |
| `SECRET_ACCESS_KEY` | link | public cache only, secret |
| `AWS_REGION` | link | public cache only: region the IAM token is signed for |
| `CACHE_NAME` | link | public cache only: cache the IAM token is signed for |

Use `CONNECTION_URL` where the client accepts a connection string, or the individual variables otherwise. On a public cache the password is an IAM authentication token: use Valkey GLIDE 2.2 or later, which generates and refreshes it from the access key, or another client together with the Developer Toolkit for ElastiCache. The `valkeys://` scheme is the TLS form and is understood by valkey-py and valkey-glide; clients that only accept the Redis scheme take the same URL as `rediss://`.

## Local testing

Set `aws_profile` in `values.yaml`, run `aws sso login --profile <name>`, and start the agent locally. With no IAM provider configured, the service runs on that profile's credentials.

Unit tests run with [bats-core](https://github.com/bats-core/bats-core):

```bash
bats valkey/scripts/tests/aws/ valkey/utils/tests/
```

`valkey/scripts/smoke/verify_cache` checks a cache against what its service holds in nullplatform, value by value: engine, connection and network type, subnets and security groups, encryption key, backups, usage limits and tags. With link IDs it also checks each link's Valkey user and, on a public cache, its IAM user, boundary, policy and access key. It needs `np` authenticated and AWS credentials for the cache's account, prints one PASS or FAIL line per value and exits 1 when any check fails:

```bash
AWS_PROFILE=<profile> valkey/scripts/smoke/verify_cache <service-id> [<link-id> ...]
```

## Run locally as a package

`np package run` runs this service on your machine the way production does: a
local controlplane-agent that registers with the platform, spawns the worker
image built from this repo, and hands it every action routed to it. No cluster,
no publish. The two tasks in `mise.toml` are the whole contract with the CLI:

| Command | Runs | Does |
|---|---|---|
| `np package build --image` | `mise run build:image` | Builds `valkey-worker:dev` |
| `np package run` | `mise run run` | Builds the image, then starts the local agent |

Prerequisites: **Docker** with host networking (Linux as is; on Docker Desktop
enable *host networking*), **[mise](https://mise.jdx.dev)** (`mise trust` once
here), an **`NP_API_KEY`** for the agent to register with, and `np` from the
**alpha** channel, which carries `np package run`:

```bash
curl -fsSL https://cli.nullplatform.com/install.sh | VERSION=alpha sh   # ~/.local/bin/np
np package run --help                                                   # must list --no-forward-env
```

```bash
export NP_API_KEY=...
eval "$(aws configure export-credentials --format env)"   # cloud credentials as variables
np package run --log-level DEBUG                          # Ctrl+C to stop
```

The agent is tagged `package:valkey` and `local:<your user>`. It receives an
action only when the service's notification channel selects those tags, so
point a channel at `local:<your user>` to route work to your machine.

> **Tags decide who gets the work.** Never start a local agent with tags a
> production channel selects: it would receive production actions.

`np package run` forwards your shell's environment to the agent container,
minus what describes your machine (`PATH`, `HOME`, `DOCKER_*`, `KUBECONFIG`,
`AWS_PROFILE` and the other file-pointing AWS variables), and the `run` task
passes the same variables to the worker through an `NP_WORKER_RULES` entry.
Every secret in your shell crosses too, and is readable with `docker inspect`;
pass `--no-forward-env` to forward nothing.

| Variable | Default | Purpose |
|---|---|---|
| `NP_API_KEY` | required | The key the agent registers with (`--api-key` also sets it) |
| `NP_LOG_LEVEL` | `INFO` | Agent log level (`--log-level` also sets it) |
| `NP_PACKAGE_SLUG` | `valkey` | The slug in the `package:<slug>` tag, when published under another slug |
| `NP_LOCAL_USER` | `$USER` | The value of the `local:<user>` tag |
| `NP_AGENT_IMAGE` | `controlplane-agent:latest` | The agent image; needs worker rules (0.11.1+) |

The local run never changes what the platform runs. To ship the change, merge
it: the release publishes the image and registers the artifact.

## Image tags

| Image | Moved by | Use it to |
|---|---|---|
| `services/valkey:vX.Y.Z` | its release, once | pin an exact version |
| `beta/services/valkey:test-<branch>-<short sha>` | each push to a pull request of this repository | deploy a change to a test scope before merging it |

Beta images live in a separate repository that the beta role can write and the production role cannot, so a beta can never overwrite a released image. Pull requests from this repository can assume the beta role (fork and bot pull requests are skipped), and the tag carries the commit SHA, so two pull requests never overwrite each other by accident. Nothing deletes beta tags: they are ephemeral by convention. Each beta is also registered as its own nullplatform oci_image artifact (the `beta/` repository, under `NP_ARTIFACT_NRN`), separate from the release artifact, so it can be deployed to a test scope from the platform.
