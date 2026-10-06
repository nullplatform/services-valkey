# Changelog

## Unreleased


### Features

* metrics for the cache in the service's metrics view: ECPUs, memory, hit rate, connections, read latency, throttled commands, available ECPUs per second and billed storage
* the requirements module grants the agent role `cloudwatch:GetMetricStatistics` so metrics show
* the install module subscribes the agent channel to `telemetry` notifications

## [0.3.5](https://github.com/nullplatform/services-valkey/compare/v0.3.4...v0.3.5) (2026-10-02)


### Bug Fixes

* **deps:** bump actions/checkout from 4 to 7 ([#19](https://github.com/nullplatform/services-valkey/issues/19)) ([67293c5](https://github.com/nullplatform/services-valkey/commit/67293c5b944faacab72b85023f4876db7b791760))

## [0.3.4](https://github.com/nullplatform/services-valkey/compare/v0.3.3...v0.3.4) (2026-10-02)


### Bug Fixes

* scope the vpc endpoint grant to elasticache serverless by service name ([#33](https://github.com/nullplatform/services-valkey/issues/33)) ([8b4b8c9](https://github.com/nullplatform/services-valkey/commit/8b4b8c9e21ea424b9c15b0166b369ef1bedc743c))

## [0.3.3](https://github.com/nullplatform/services-valkey/compare/v0.3.2...v0.3.3) (2026-10-02)


### Bug Fixes

* **deps:** update dependency opentofu/opentofu to v1.13.1 ([#29](https://github.com/nullplatform/services-valkey/issues/29)) ([9642bf0](https://github.com/nullplatform/services-valkey/commit/9642bf0d168db4aa5cfcebf3be696f02a7ef2281))

## [0.3.2](https://github.com/nullplatform/services-valkey/compare/v0.3.1...v0.3.2) (2026-10-02)


### Bug Fixes

* take region and network from the cloud and vpc providers ([#28](https://github.com/nullplatform/services-valkey/issues/28)) ([7a159f1](https://github.com/nullplatform/services-valkey/commit/7a159f1d2b070276eda86387eeefd48d10ac7593))

## [0.3.1](https://github.com/nullplatform/services-valkey/compare/v0.3.0...v0.3.1) (2026-10-01)


### Bug Fixes

* **deps:** bump nullplatform/scopes/worker-bridge from 1.1.1 to 2.0.1 ([b531fe9](https://github.com/nullplatform/services-valkey/commit/b531fe9936fefb0d31321f5d70ff7377a37f16ff))
* **deps:** bump nullplatform/scopes/worker-bridge from 1.1.1 to 2.0.1 ([ee5cd27](https://github.com/nullplatform/services-valkey/commit/ee5cd271cfc9aa2bfe4c35ae2df47a00339b73f6))

## [0.3.0](https://github.com/nullplatform/services-valkey/compare/v0.2.2...v0.3.0) (2026-09-29)


### Features

* encrypt each cache with its own KMS key, overridable per account ([#24](https://github.com/nullplatform/services-valkey/issues/24)) ([aae598f](https://github.com/nullplatform/services-valkey/commit/aae598f06acc0c3ffa45eb01d0c96b1ec250bfc5))

## [0.2.2](https://github.com/nullplatform/services-valkey/compare/v0.2.1...v0.2.2) (2026-09-23)


### Bug Fixes

* install the pinned tofu when the cached one is older ([#10](https://github.com/nullplatform/services-valkey/issues/10)) ([436458d](https://github.com/nullplatform/services-valkey/commit/436458dfee86f85234d3b62976e950c3bc4d2fe2))
* namespace the tofu state under services/valkey/&lt;service-id&gt; ([#17](https://github.com/nullplatform/services-valkey/issues/17)) ([08616f5](https://github.com/nullplatform/services-valkey/commit/08616f53b656d5db7a921f03ab3f97541936c360))

## [0.2.1](https://github.com/nullplatform/services-valkey/compare/v0.2.0...v0.2.1) (2026-09-17)


### Bug Fixes

* **ci:** auto-merge the release PR from workflow_run; Dependabot commits as fix(deps) ([a894cce](https://github.com/nullplatform/services-valkey/commit/a894cce5f56a47daabad403bc23eb59662d36310))
* **ci:** merge the release PR from workflow_run instead of the gated pull_request trigger ([5cfc732](https://github.com/nullplatform/services-valkey/commit/5cfc732b6827d583208ff2b9341a2c7c70f2e9a9))
* **deps:** dependabot commits as fix(deps) so the base image bump gets released ([a705d38](https://github.com/nullplatform/services-valkey/commit/a705d38bb13ccb06045663f70a30145442167728))

## [0.2.0](https://github.com/nullplatform/services-valkey/compare/v0.1.0...v0.2.0) (2026-09-17)


### Features

* dependabot for base image bumps ([0eb2503](https://github.com/nullplatform/services-valkey/commit/0eb25034b5c513c0653a16d8cdc4a8ff64ad9662))
* dependabot for base image bumps ([d43c70f](https://github.com/nullplatform/services-valkey/commit/d43c70f9b0252fe196151baccc14f2ae6482fa3b))


### Bug Fixes

* **deps:** update dependency opentofu/opentofu to v1.12.6 ([9278439](https://github.com/nullplatform/services-valkey/commit/927843960c5b64ac3d607dc29814b79ac77a5073))
* **deps:** update dependency opentofu/opentofu to v1.12.6 ([5605038](https://github.com/nullplatform/services-valkey/commit/5605038ff200894cf2282e03ef07e260c13f26af))

## [0.1.0](https://github.com/nullplatform/services-valkey/compare/0.0.1...v0.1.0) (2026-09-15)


### Features

* serverless valkey service with connect link ([218a4ae](https://github.com/nullplatform/services-valkey/commit/218a4ae2a0a32aca3b2ab71dfff0af1bba956ff9))

## Changelog

## Unreleased


### Features

* serverless valkey cache with a per-link user, password and TLS connection url
* `terraform.tfvars.example` for the permissions role module
* tofu state lives in one pre-existing bucket named by `VALKEY_S3_STATE_BUCKET` instead of a bucket per service
