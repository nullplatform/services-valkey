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
        "port",
        "valkey_arn"
      ],
      "uiSchema": {
        "type": "VerticalLayout",
        "elements": [
          {
            "type": "Control",
            "scope": "#/properties/engine_version"
          },
          {
            "type": "Control",
            "scope": "#/properties/connection_type",
            "options": {
              "format": "radio"
            },
            "rule": {
              "effect": "SHOW",
              "condition": {
                "scope": "#/properties/engine_version",
                "schema": {
                  "const": "9"
                }
              }
            }
          },
          {
            "type": "Control",
            "scope": "#/properties/settings_mode",
            "options": {
              "format": "radio"
            }
          },
          {
            "type": "Categorization",
            "options": {
              "collapsable": {
                "label": "CUSTOMIZE DEFAULT SETTINGS",
                "collapsed": false
              }
            },
            "elements": [
              {
                "type": "Category",
                "label": "Connectivity",
                "elements": [
                  {
                    "type": "Control",
                    "scope": "#/properties/network_type",
                    "options": {
                      "format": "radio"
                    }
                  },
                  {
                    "type": "VerticalLayout",
                    "elements": [
                      {
                        "type": "Control",
                        "scope": "#/properties/vpc_id"
                      },
                      {
                        "type": "Control",
                        "scope": "#/properties/subnet_ids"
                      }
                    ],
                    "rule": {
                      "effect": "SHOW",
                      "condition": {
                        "scope": "#/properties/connection_type",
                        "schema": {
                          "not": {
                            "const": "public"
                          }
                        }
                      }
                    }
                  }
                ]
              },
              {
                "type": "Category",
                "label": "Security",
                "elements": [
                  {
                    "type": "Control",
                    "scope": "#/properties/security_settings",
                    "options": {
                      "format": "radio"
                    }
                  },
                  {
                    "type": "VerticalLayout",
                    "elements": [
                      {
                        "type": "Control",
                        "scope": "#/properties/encryption_key",
                        "options": {
                          "format": "radio"
                        }
                      },
                      {
                        "type": "Control",
                        "scope": "#/properties/kms_key_arn",
                        "rule": {
                          "effect": "SHOW",
                          "condition": {
                            "scope": "#/properties/encryption_key",
                            "schema": {
                              "const": "existing"
                            }
                          }
                        }
                      },
                      {
                        "type": "Control",
                        "scope": "#/properties/security_group_ids",
                        "rule": {
                          "effect": "SHOW",
                          "condition": {
                            "scope": "#/properties/connection_type",
                            "schema": {
                              "not": {
                                "const": "public"
                              }
                            }
                          }
                        }
                      }
                    ],
                    "rule": {
                      "effect": "SHOW",
                      "condition": {
                        "scope": "#/properties/security_settings",
                        "schema": {
                          "const": "customize"
                        }
                      }
                    }
                  }
                ]
              },
              {
                "type": "Category",
                "label": "Backup",
                "elements": [
                  {
                    "type": "Control",
                    "scope": "#/properties/automatic_backups",
                    "options": {
                      "format": "radio"
                    }
                  },
                  {
                    "type": "VerticalLayout",
                    "elements": [
                      {
                        "type": "Control",
                        "scope": "#/properties/backup_retention_days"
                      },
                      {
                        "type": "Control",
                        "scope": "#/properties/backup_window_start"
                      }
                    ],
                    "rule": {
                      "effect": "SHOW",
                      "condition": {
                        "scope": "#/properties/automatic_backups",
                        "schema": {
                          "const": "enabled"
                        }
                      }
                    }
                  }
                ]
              },
              {
                "type": "Category",
                "label": "Usage limits",
                "elements": [
                  {
                    "type": "Control",
                    "scope": "#/properties/usage_limits",
                    "options": {
                      "format": "radio"
                    }
                  },
                  {
                    "type": "VerticalLayout",
                    "rule": {
                      "effect": "SHOW",
                      "condition": {
                        "scope": "#/properties/usage_limits",
                        "schema": {
                          "const": "set"
                        }
                      }
                    },
                    "elements": [
                      {
                        "type": "Control",
                        "scope": "#/properties/data_storage_minimum_gb"
                      },
                      {
                        "type": "Control",
                        "scope": "#/properties/data_storage_maximum_gb"
                      },
                      {
                        "type": "Control",
                        "scope": "#/properties/ecpu_minimum"
                      },
                      {
                        "type": "Control",
                        "scope": "#/properties/ecpu_maximum"
                      }
                    ]
                  }
                ]
              }
            ],
            "rule": {
              "effect": "SHOW",
              "condition": {
                "scope": "#/properties/settings_mode",
                "schema": {
                  "const": "customize"
                }
              }
            }
          },
          {
            "type": "Control",
            "scope": "#/properties/tags"
          }
        ]
      },
      "properties": {
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
        "port": {
          "type": "string",
          "title": "Port",
          "export": true,
          "readOnly": true,
          "visibleOn": [
            "read"
          ],
          "editableOn": [],
          "description": "Port applications connect to, over TLS (auto-populated after creation)",
          "order": 2
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
          "order": 3
        },
        "cache_name": {
          "type": "string",
          "title": "Cache Name",
          "export": false,
          "readOnly": true,
          "visibleOn": [],
          "editableOn": [],
          "description": "Internal cache name, fixed after creation"
        },
        "engine_version": {
          "type": "string",
          "title": "Engine version",
          "enum": [
            "7",
            "8",
            "9"
          ],
          "default": "9",
          "editableOn": [
            "create",
            "update"
          ],
          "description": "Version compatibility of the engine that will run the cache. AWS applies minor and patch upgrades automatically. It can be upgraded after creation, never downgraded. Public requires Valkey 9.",
          "order": 4
        },
        "connection_type": {
          "type": "string",
          "title": "Connection type",
          "oneOf": [
            {
              "const": "vpc",
              "title": "VPC: routes traffic through your VPC endpoint"
            },
            {
              "const": "public",
              "title": "Public: allows access from the internet, with IAM authentication only"
            }
          ],
          "default": "vpc",
          "editableOn": [
            "create"
          ],
          "description": "VPC routes traffic through your VPC endpoint. Public allows access from the internet, requires Valkey 9 and IAM authentication: every link authenticates with IAM instead of a password. Fixed after creation.",
          "order": 5
        },
        "settings_mode": {
          "type": "string",
          "title": "Default settings",
          "oneOf": [
            {
              "const": "default",
              "title": "Use default settings: IPv4, a customer managed key created for this cache, default security group, automatic backups off, no usage limits"
            },
            {
              "const": "customize",
              "title": "Customize default settings"
            }
          ],
          "default": "default",
          "editableOn": [
            "create",
            "update"
          ],
          "description": "Use the recommended default settings to get started quickly, or customize them.",
          "order": 6
        },
        "network_type": {
          "type": "string",
          "title": "Network type",
          "oneOf": [
            {
              "const": "ipv4",
              "title": "IPv4: resources communicate only over IPv4"
            },
            {
              "const": "dual_stack",
              "title": "Dual stack: IPv4 and IPv6"
            },
            {
              "const": "ipv6",
              "title": "IPv6: resources communicate only over IPv6"
            }
          ],
          "default": "ipv4",
          "editableOn": [
            "create"
          ],
          "description": "IP version(s) the cache supports. Dual stack needs subnets with an IPv6 range, IPv6 needs IPv6-only subnets. Fixed after creation.",
          "order": 7
        },
        "vpc_id": {
          "type": "string",
          "title": "VPC ID - optional",
          "editableOn": [
            "create"
          ],
          "description": "The VPC the cache runs in. Leave empty to use the one of the vpc provider. Fixed after creation.",
          "order": 8,
          "pattern": "^vpc-[0-9a-f]+$"
        },
        "subnet_ids": {
          "type": "string",
          "title": "Subnet IDs - optional",
          "editableOn": [
            "create"
          ],
          "description": "Comma-separated subnets, one per Availability Zone you will access the cache from; we recommend the AZs where your application is deployed. Leave empty to use the subnets of the vpc provider. Fixed after creation.",
          "order": 9,
          "pattern": "^\\s*subnet-[0-9a-f]+(\\s*,\\s*subnet-[0-9a-f]+)*\\s*$"
        },
        "security_settings": {
          "type": "string",
          "title": "Security",
          "oneOf": [
            {
              "const": "default",
              "title": "Default security settings: a customer managed key created for this cache, encryption in transit, default security group"
            },
            {
              "const": "customize",
              "title": "Customize your security settings"
            }
          ],
          "default": "default",
          "editableOn": [
            "create",
            "update"
          ],
          "description": "Configure your network and data security settings by using the default ElastiCache values or defining your own. Encryption in transit is always enabled.",
          "order": 10
        },
        "encryption_key": {
          "type": "string",
          "title": "Encryption key",
          "oneOf": [
            {
              "const": "dedicated",
              "title": "Customer managed key created for this cache"
            },
            {
              "const": "existing",
              "title": "Existing customer managed key"
            }
          ],
          "default": "dedicated",
          "editableOn": [
            "create"
          ],
          "description": "The KMS key that protects the data at rest. By default the service creates a dedicated customer managed key, with rotation, for each cache. Fixed after creation.",
          "order": 11
        },
        "kms_key_arn": {
          "type": "string",
          "title": "KMS key ARN",
          "pattern": "^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/.+$",
          "editableOn": [
            "create"
          ],
          "description": "ARN of an existing customer managed KMS key, in the same region as the cache. The permissions role must be allowed to use it.",
          "order": 12
        },
        "security_group_ids": {
          "type": "array",
          "title": "Security groups",
          "items": {
            "type": "string",
            "title": "Security group ID",
            "pattern": "^sg-[0-9a-f]+$"
          },
          "editableOn": [
            "create",
            "update"
          ],
          "description": "Security groups that act as a firewall for the cache. They replace the default security group, which only allows Valkey (port 6379) from inside the VPC. VPC caches only.",
          "order": 13
        },
        "automatic_backups": {
          "type": "string",
          "title": "Automatic backups",
          "oneOf": [
            {
              "const": "disabled",
              "title": "Off"
            },
            {
              "const": "enabled",
              "title": "Enable automatic backups: ElastiCache creates a daily backup of the cache"
            }
          ],
          "default": "disabled",
          "editableOn": [
            "create",
            "update"
          ],
          "description": "A backup holds the cache's metadata and data. It can restore a cache or seed a new one.",
          "order": 14
        },
        "backup_retention_days": {
          "type": "integer",
          "title": "Backup retention (days)",
          "default": 1,
          "minimum": 1,
          "maximum": 35,
          "editableOn": [
            "create",
            "update"
          ],
          "description": "Days each automatic backup is kept. 35 days maximum.",
          "order": 15
        },
        "backup_window_start": {
          "type": "string",
          "title": "Backup start time (UTC) - optional",
          "pattern": "^([01][0-9]|2[0-3]):[0-5][0-9]$",
          "editableOn": [
            "create",
            "update"
          ],
          "description": "Time the daily backup starts, as HH:MM in UTC. Leave empty to let AWS choose; once set it can be changed but not emptied.",
          "order": 16
        },
        "usage_limits": {
          "type": "string",
          "title": "Usage limits - optional",
          "oneOf": [
            {
              "const": "not_set",
              "title": "Not set: the cache scales without limits"
            },
            {
              "const": "set",
              "title": "Set limits: the cache will not scale beyond them"
            }
          ],
          "default": "not_set",
          "editableOn": [
            "create",
            "update"
          ],
          "description": "Choose a minimum or maximum data storage and requests limits for your cache. Choosing Not set again removes every limit.",
          "order": 17
        },
        "data_storage_minimum_gb": {
          "type": "integer",
          "title": "Data storage minimum (GB)",
          "minimum": 0,
          "maximum": 5000,
          "editableOn": [
            "create",
            "update"
          ],
          "description": "Minimum cached data capacity, from 1 GB. When set, the cache is billed for at least this much. 0 means no limit.",
          "order": 18
        },
        "data_storage_maximum_gb": {
          "type": "integer",
          "title": "Data storage maximum (GB)",
          "minimum": 0,
          "maximum": 5000,
          "editableOn": [
            "create",
            "update"
          ],
          "description": "Maximum cached data capacity, up to 5,000 GB. The cache does not scale beyond it. 0 means no limit.",
          "order": 19
        },
        "ecpu_minimum": {
          "type": "integer",
          "title": "Requests minimum (ECPUs per second)",
          "minimum": 0,
          "maximum": 15000000,
          "editableOn": [
            "create",
            "update"
          ],
          "description": "Minimum ECPUs per second, from 1,000. 0 means no limit.",
          "order": 20
        },
        "ecpu_maximum": {
          "type": "integer",
          "title": "Requests maximum (ECPUs per second)",
          "minimum": 0,
          "maximum": 15000000,
          "editableOn": [
            "create",
            "update"
          ],
          "description": "Maximum ECPUs per second, up to 15,000,000. The cache does not scale beyond it. 0 means no limit.",
          "order": 21
        },
        "tags": {
          "type": "array",
          "title": "Tags - optional",
          "items": {
            "type": "object",
            "properties": {
              "key": {
                "type": "string",
                "title": "Key"
              },
              "value": {
                "type": "string",
                "title": "Value"
              }
            },
            "required": [
              "key"
            ]
          },
          "description": "A tag is a metadata label that you can assign to the cache. Each tag consists of a key and an optional value.",
          "editableOn": [
            "create",
            "update"
          ],
          "order": 22
        }
      }
    },
    "values": {}
  }
}
