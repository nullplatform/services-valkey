{
  "name": "Serverless Valkey",
  "slug": "serverless-valkey",
  "type": "dependency",
  "unique": false,
  "assignable_to": "any",
  "use_default_actions": true,
  "use_default_naming": false,
  "use_managed_actions": false,
  "available_links": [
    "create-serverless-valkey-link"
  ],
  "selectors": {
    "category": "Database",
    "imported": false,
    "provider": "AWS",
    "sub_category": "In-memory Cache"
  },
  "attributes": {
    "schema": {
      "type": "object",
      "$schema": "http://json-schema.org/draft-07/schema#",
      "additionalProperties": false,
      "required": [
        "endpoint",
        "valkey_arn"
      ],
      "properties": {
        "aws_region": {
          "type": "string",
          "title": "AWS Region",
          "config": "aws.region",
          "visibleOn": [],
          "editableOn": [],
          "description": "Region where the cache is created (taken from the account configuration)"
        },
        "vpc_id": {
          "type": "string",
          "title": "VPC",
          "config": "aws.vpcId",
          "visibleOn": [],
          "editableOn": [],
          "description": "VPC the cache is placed in (taken from the account configuration)"
        },
        "subnet_ids": {
          "type": "string",
          "title": "Subnets",
          "config": "aws.subnetIds",
          "visibleOn": [],
          "editableOn": [],
          "description": "Comma-separated subnet IDs the cache is placed in (taken from the account configuration)"
        },
        "endpoint": {
          "type": "string",
          "title": "Endpoint",
          "export": true,
          "readOnly": true,
          "visibleOn": [
            "read"
          ],
          "editableOn": [],
          "description": "Hostname applications connect to on port 6379 with TLS (auto-populated after creation)",
          "order": 1
        },
        "valkey_arn": {
          "type": "string",
          "title": "Cache ARN",
          "export": false,
          "readOnly": true,
          "visibleOn": [
            "read"
          ],
          "editableOn": [],
          "description": "ARN of the serverless cache (auto-populated after creation)",
          "order": 2
        },
        "cache_name": {
          "type": "string",
          "title": "Cache Name",
          "export": false,
          "readOnly": true,
          "visibleOn": [],
          "editableOn": [],
          "description": "Internal cache name, fixed after creation"
        }
      }
    },
    "values": {}
  }
}
