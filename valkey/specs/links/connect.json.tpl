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
      "required": [
        "user_name",
        "connection_url"
      ],
      "properties": {
        "user_name": {
          "type": "string",
          "title": "User Name",
          "export": true,
          "readOnly": true,
          "visibleOn": [
            "read"
          ],
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
          "visibleOn": [
            "read"
          ],
          "editableOn": [],
          "description": "Password of the link user on a VPC cache (auto-populated, delivered as secret env var). Empty on a public cache, which authenticates with IAM",
          "order": 2
        },
        "connection_url": {
          "type": "string",
          "title": "Connection URL",
          "export": {
            "type": "environment_variable",
            "secret": true
          },
          "readOnly": true,
          "visibleOn": [
            "read"
          ],
          "editableOn": [],
          "description": "Ready-to-use TLS connection string for the link user (auto-populated, delivered as secret env var). On a public cache it carries no password: send an IAM token signed with the link's access key instead",
          "order": 3
        },
        "access_key_id": {
          "type": "string",
          "title": "Access Key ID",
          "export": true,
          "readOnly": true,
          "visibleOn": [
            "read"
          ],
          "editableOn": [],
          "description": "Access key of the link's IAM user, used to sign IAM authentication tokens for a public cache (auto-populated, public caches only)",
          "order": 4
        },
        "secret_access_key": {
          "type": "string",
          "title": "Secret Access Key",
          "export": {
            "type": "environment_variable",
            "secret": true
          },
          "readOnly": true,
          "visibleOn": [
            "read"
          ],
          "editableOn": [],
          "description": "Secret of the link's IAM user (auto-populated, delivered as secret env var, public caches only)",
          "order": 5
        },
        "aws_region": {
          "type": "string",
          "title": "AWS Region",
          "export": true,
          "readOnly": true,
          "visibleOn": [
            "read"
          ],
          "editableOn": [],
          "description": "Region the IAM token is signed for (auto-populated, public caches only)",
          "order": 6
        },
        "cache_name": {
          "type": "string",
          "title": "Cache Name",
          "export": true,
          "readOnly": true,
          "visibleOn": [
            "read"
          ],
          "editableOn": [],
          "description": "Serverless cache name the IAM token is signed for (auto-populated, public caches only)",
          "order": 7
        }
      }
    },
    "values": {}
  }
}
