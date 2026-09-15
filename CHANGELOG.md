# Changelog

## [0.1.0](https://github.com/nullplatform/services-valkey/compare/0.0.1...v0.1.0) (2026-09-15)


### Features

* serverless valkey service with connect link ([218a4ae](https://github.com/nullplatform/services-valkey/commit/218a4ae2a0a32aca3b2ab71dfff0af1bba956ff9))

## Changelog

## Unreleased


### Features

* serverless valkey cache with a per-link user, password and TLS connection url
* `terraform.tfvars.example` for the permissions role module
* tofu state lives in one pre-existing bucket named by `VALKEY_S3_STATE_BUCKET` instead of a bucket per service
