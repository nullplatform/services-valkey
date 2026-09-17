# Changelog

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
