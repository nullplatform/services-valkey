{
  "name": "Serverless Valkey Link",
  "slug": "create-serverless-valkey-link",
  "unique": false,
  "assignable_to": "any",
  "use_default_actions": true,
  "use_default_naming": false,
  "use_managed_actions": false,
  "selectors": {
    "category": "any",
    "imported": false,
    "provider": "any",
    "sub_category": "any"
  },
  "attributes": {
    "schema": {
      "type": "object",
      "$schema": "http://json-schema.org/draft-07/schema#",
      "required": ["user_name", "user_password"],
      "properties": {
        "aws_region": {
          "type": "string",
          "title": "AWS Region",
          "config": "aws.region",
          "visibleOn": [],
          "editableOn": [],
          "description": "Region of the cache (taken from the account configuration)"
        },
        "vpc_id": {
          "type": "string",
          "title": "VPC",
          "config": "aws.vpcId",
          "visibleOn": [],
          "editableOn": [],
          "description": "VPC of the cache (taken from the account configuration)"
        },
        "access_key_id": {
          "type": "string",
          "title": "AWS Access Key ID",
          "config": "aws.accessKeyId",
          "visibleOn": [],
          "editableOn": [],
          "description": "Credentials used when no permissions role is configured (taken from the account configuration)"
        },
        "secret_access_key": {
          "type": "string",
          "title": "AWS Secret Access Key",
          "config": "aws.secretAccessKey",
          "visibleOn": [],
          "editableOn": [],
          "description": "Credentials used when no permissions role is configured (taken from the account configuration)"
        },
        "user_name": {
          "type": "string",
          "title": "User Name",
          "export": true,
          "readOnly": true,
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "Valkey user created for this link (auto-populated after link creation)",
          "order": 1
        },
        "user_password": {
          "type": "string",
          "title": "User Password",
          "export": {
            "type": "environment_variable",
            "secret": true
          },
          "readOnly": true,
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "Password of the link user (auto-populated, delivered as secret env var)",
          "order": 2
        }
      }
    },
    "values": {}
  }
}
