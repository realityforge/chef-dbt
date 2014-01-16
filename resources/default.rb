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

attribute :database_key, :kind_of => String, :name_attribute => true

attribute :major_version, :kind_of => Integer, :required => true
attribute :minor_version, :kind_of => String, :required => true

attribute :last_database, :kind_of => [String, NilClass], :default => nil
attribute :import_on_create, :kind_of => [TrueClass, FalseClass], :default => true
attribute :recreate_on_minor_version_delta, :kind_of => [TrueClass, FalseClass], :default => false

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

default_action :create

def database_name
  "#{database_key}_#{major_version}"
end

def last_database_name
  last_database || "#{database_key}_#{major_version - 1}"
end

def version
  "#{major_version}.#{minor_version}"
end
