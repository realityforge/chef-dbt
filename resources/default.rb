#
# Copyright 2012, Peter Donald
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

actions :create

attribute :database_name, :kind_of => String, :name_attribute => true
attribute :module_group, :kind_of => [String, NilClass], :default => nil

attribute :major_version, :kind_of => Integer, :required => true
attribute :minor_version, :kind_of => String, :required => true
# Enforce match between nominated major version and version from dbt jar
attribute :enforce_version_match, :kind_of => [TrueClass, FalseClass], :required => false
attribute :recreate_on_minor_version_delta, :kind_of => [TrueClass, FalseClass], :default => false

attribute :last_database, :kind_of => [String, NilClass], :default => nil
attribute :import_on_create, :kind_of => [TrueClass, FalseClass], :default => true
attribute :reindex_on_import, :kind_of => [TrueClass, FalseClass], :default => true
attribute :shrink_on_import, :kind_of => [TrueClass, FalseClass], :default => true

attribute :import_spec, :kind_of => [String, NilClass], :default => nil

attribute :package_url, :kind_of => String, :required => true

attribute :admin_user, :kind_of => String, :required => true
attribute :admin_password, :kind_of => String, :required => true
attribute :host, :kind_of => String, :required => true
attribute :port, :kind_of => Integer, :required => true

attribute :driver_key, :equal_to => ['sql_server', 'postgres'], :default => 'sql_server'

attribute :artifact_key, :kind_of => String, :default => nil
attribute :prefix_dir, :kind_of => String, :default => nil

attribute :system_user, :kind_of => String, :default => nil
attribute :system_group, :kind_of => String, :default => nil

attribute :linked_databases, :kind_of => Hash, :default => {}

attribute :java_memory, :kind_of => Integer, :default => 100

default_action :create

def version
  "#{major_version}.#{minor_version}"
end

def no_create?
  !module_group.nil?
end
