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

use_inline_resources

def get_version_sql
  if new_resource.driver_key == 'sql_server'
    <<-SQL
        IF EXISTS (SELECT * FROM sys.databases WHERE name = '#{new_resource.database_name}')
BEGIN
  EXEC('
    USE [#{new_resource.database_name}]
    SELECT
      E1.value AS Dbt_MajorVersion,
      E2.value AS Dbt_MinorVersion
    FROM
      sys.extended_properties AS E1, sys.extended_properties AS E2
    WHERE E1.class_desc = ''DATABASE'' AND E1.name = ''Dbt_MajorVersion'' AND
          E2.class_desc = ''DATABASE'' AND E2.name = ''Dbt_MinorVersion''
  ')
END
ELSE
BEGIN
  SELECT NULL AS Dbt_MajorVersion, NULL AS Dbt_MinorVersion
END
    SQL
  else
    raise "Unsupported driver #{new_resource.driver_key}"
  end
end

action :create do

  database_name = new_resource.database_name
  artifact_key = new_resource.artifact_key || new_resource.database_key

  archive = archive artifact_key do
    url new_resource.package_url
    version new_resource.version
    prefix new_resource.prefix_dir if new_resource.prefix_dir
    owner new_resource.system_user if new_resource.system_user
    group new_resource.system_group if new_resource.system_group
  end

  base_dir = archive.base_directory
  database_jar_location = archive.target_artifact

  [base_dir, "#{base_dir}/config"].each do |dir|
    directory dir do
      if node['platform'] != 'windows'
        owner new_resource.system_user if new_resource.system_user
        group new_resource.system_group if new_resource.system_group
        mode '0700'
      end
      action :create
    end
  end

  template "#{base_dir}/config/database.yml" do
    cookbook 'dbt'
    source "database.yml.erb"
    if node['platform'] != 'windows'
      owner new_resource.system_user if new_resource.system_user
      group new_resource.system_group if new_resource.system_group
      mode '0600'
    end
    variables(:username => new_resource.admin_user,
              :password => new_resource.admin_password,
              :host => new_resource.host,
              :port => new_resource.port,
              :database_name => database_name,
              :last_database_name => new_resource.last_database_name,
              :recreate => new_resource.recreate_on_minor_version_delta,
              :linked_databases => new_resource.linked_databases)
  end

  jdbc_url = jdbc_driver = jdbc_properties = nil
  if new_resource.driver_key == 'sql_server'
    jdbc_url = "jdbc:jtds:sqlserver://#{new_resource.host}:#{new_resource.port}/master"
    jdbc_driver = 'net.sourceforge.jtds.jdbc.Driver'
    jdbc_properties = {'user' => new_resource.admin_user, 'password' => new_resource.admin_password}
  else
    raise "Postgres support not yet provided."
  end

  major_version = new_resource.major_version
  minor_version = new_resource.minor_version
  enforce_version_match = new_resource.enforce_version_match
  import_on_create = new_resource.import_on_create
  recreate_on_minor_version_delta = new_resource.recreate_on_minor_version_delta
  extra_classpath = ["file://#{database_jar_location}"]

  sqlshell_exec "Create or migrate database #{database_name}" do
    jdbc_url jdbc_url
    jdbc_driver jdbc_driver
    extra_classpath extra_classpath
    jdbc_properties jdbc_properties
    command get_version_sql
    block do
      migrations_supported = false
      dbt_jar_version_match = true

      java_exe =
        if node['platform'] == 'windows'
          "\"#{node['java']['java_home']}\\bin\\java.exe\""
        else
          "#{node['java']['java_home']}/bin/java"
        end

      # Check alignment of major version in database_jar, and abort
      command = "#{java_exe} -Xmx100M -jar #{database_jar_location} --environment production --config-file #{base_dir}/config/database.yml status"
      puts command
      cmd = Mixlib::ShellOut.new(command)
      cmd.timeout = 7200
      cmd.live_stream = STDOUT
      cmd.run_command
      begin
        cmd.error!
        version_from_match = /Database Version: (?<version>.+)/.match(cmd.stdout)
        dbjar_version = version_from_match.nil? ? nil : version_from_match[:version]
        dbt_jar_version_match = dbjar_version && major_version.to_s.eql?(dbjar_version.to_s)
        migrations_supported = !!/Migrations Supported: Yes/.match(cmd.stdout)
        puts "Migration support within DbJar: #{migrations_supported}"
        version_hash_match = /Database Schema Hash: (?<hash>.+)/.match(cmd.stdout)
        unless version_hash_match.nil?
          minor_version = version_hash_match[:hash]
          puts "Database Minor Version has been overriden to align with database schema hash: #{minor_version}"
        end
      rescue Exception => e
        puts '*********************** WARNING ***********************'
        puts 'WARNING: Unable to determine support for migrations or Database Major Version'
        puts e.to_s
        puts '*********************** WARNING ***********************'
      end
      unless dbt_jar_version_match
        if enforce_version_match
          raise "Database Major Version is expected to be [#{major_version.inspect}] but DbJar contains [#{dbjar_version.inspect}]"
        else
          puts '*********************** WARNING ***********************'
          puts "WARNING: Mismatch in Database Major Version.  Chef expects [#{major_version.inspect}], DbJar contains [#{dbjar_version.inspect}]"
          puts '*********************** WARNING ***********************'
        end
      end

      db_major_version = @sql_results.size == 0 ? 'Unset' : @sql_results[0]['Dbt_MajorVersion']
      db_minor_version = @sql_results.size == 0 ? 'Unset' : @sql_results[0]['Dbt_MinorVersion']
      major_version_differs = major_version.to_s != db_major_version
      minor_version_differs = minor_version.to_s != db_minor_version

      action = nil

      if major_version_differs || (recreate_on_minor_version_delta && minor_version_differs)
        if major_version_differs
          puts "Major version differs [#{db_major_version} vs #{major_version.to_s}], recreating db."
        else
          puts "Minor version differs [#{db_minor_version} vs #{minor_version.to_s}], recreating db."
        end
        if import_on_create
          action = 'create_by_import'
        else
          action = 'create'
        end
      elsif minor_version_differs && migrations_supported
        puts "Minor version differs [#{db_minor_version} vs #{minor_version.to_s}], performing migration."
        action = 'migrate'
      end

      if action
        command = "#{java_exe} -Xmx100M -jar #{database_jar_location} --environment production --config-file #{base_dir}/config/database.yml #{action}"
        puts command
        cmd = Mixlib::ShellOut.new(command)
        cmd.timeout = 7200
        cmd.live_stream = STDOUT
        cmd.run_command
        cmd.error!

        if 'migrate' == action
          sqlshell_exec "Update minor version on database #{database_name}" do
            jdbc_url jdbc_url
            jdbc_driver jdbc_driver
            extra_classpath extra_classpath
            jdbc_properties jdbc_properties
            command "EXEC [#{database_name}].sys.sp_updateextendedproperty @name = N'Dbt_MinorVersion', @value = N'#{minor_version}'"
          end
        else
          sqlshell_exec "Set major version on database #{database_name}" do
            jdbc_url jdbc_url
            jdbc_driver jdbc_driver
            extra_classpath extra_classpath
            jdbc_properties jdbc_properties
            command "EXEC [#{database_name}].sys.sp_addextendedproperty @name = N'Dbt_MajorVersion', @value = N'#{major_version}'"
          end

          sqlshell_exec "Set minor version on database #{database_name}" do
            jdbc_url jdbc_url
            jdbc_driver jdbc_driver
            extra_classpath extra_classpath
            jdbc_properties jdbc_properties
            command "EXEC [#{database_name}].sys.sp_addextendedproperty @name = N'Dbt_MinorVersion', @value = N'#{minor_version}'"
          end
        end
      else
        sqlshell_exec "Update minor version on unchanged database #{database_name}" do
          jdbc_url jdbc_url
          jdbc_driver jdbc_driver
          extra_classpath extra_classpath
          jdbc_properties jdbc_properties
          command "EXEC [#{database_name}].sys.sp_updateextendedproperty @name = N'Dbt_MinorVersion', @value = N'#{minor_version}'"
        end
      end
    end
  end
end
