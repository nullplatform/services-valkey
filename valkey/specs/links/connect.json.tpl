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
        "user_password",
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
          "description": "Password of the link user (auto-populated, delivered as secret env var)",
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
          "description": "Ready-to-use TLS connection string for the link user (auto-populated, delivered as secret env var)",
          "order": 3
        }
      }
    },
    "values": {}
  }
}
