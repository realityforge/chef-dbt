# Description

[![Build Status](https://secure.travis-ci.org/realityforge/chef-dbt.png?branch=master)](http://travis-ci.org/realityforge/chef-dbt)

# Requirements

## Platform:

*No platforms defined*

## Cookbooks:

* archive

# Attributes

*No attributes defined*

# Recipes

*No recipes defined*

# Resources

* [dbt](#dbt)

## dbt

### Actions

- create:  Default action.

### Attribute Parameters

- database_key:
- major_version:
- minor_version:
- last_database:  Defaults to <code>nil</code>.
- import_on_create:  Defaults to <code>true</code>.
- reindex_on_import:  Defaults to <code>true</code>.
- shrink_on_import:  Defaults to <code>true</code>.
- import_spec:  Defaults to <code>nil</code>.
- recreate_on_minor_version_delta:  Defaults to <code>false</code>.
- package_url:
- admin_user:
- admin_password:
- host:
- port:
- driver_key:  Defaults to <code>"sql_server"</code>.
- artifact_key:  Defaults to <code>nil</code>.
- prefix_dir:  Defaults to <code>nil</code>.
- system_user:  Defaults to <code>nil</code>.
- system_group:  Defaults to <code>nil</code>.
- linked_databases:  Defaults to <code>{}</code>.
- java_memory:  In megabytes. Defaults to <code>100</code>.

# License and Maintainer

Maintainer:: Peter Donald (<peter@realityforge.org>)

License:: Apache 2.0
