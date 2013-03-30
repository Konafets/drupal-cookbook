#
# Author:: Marius Ducea (marius@promethost.com)
# Cookbook Name:: drupal
# Recipe:: default
#
# Copyright 2010, Promet Solutions
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

include_recipe %w{apache2 apache2::mod_php5 apache2::mod_rewrite apache2::mod_expires}
include_recipe %w{php php::module_gd}
include_recipe "drupal::drush"

# Centos does not include the php-dom extension in it's minimal php install.
case node['platform_family']
when 'rhel', 'fedora'
  package 'php-dom' do
    action :install
  end
end

# Setting up a database engine
if node['drupal']['db']['driver'] == 'mysql'
  include_recipe %w{php::module_mysql database::mysql}
  
  if node['drupal']['site']['host'] == "localhost"
    include_recipe "mysql::server"
  else
    include_recipe "mysql::client"
  end
else
  log("Only databases currently supported: mysql. You have: #{node['drupal']['db']['driver']}") {level :warn}
end

# Create database
connection_info = {:host => node['drupal']['db']['host'], :username => 'root', :password => node['mysql']['server_root_password']}

mysql_database node['drupal']['db']['database'] do
  connection connection_info
  action :create
  not_if "mysql -h #{node['drupal']['db']['host']} -u root -p#{node['mysql']['server_root_password']} --silent --skip-column-names --execute=\"SHOW DATABASES LIKE '#{node['drupal']['db']['database']}';\""
end

# Create user and grant all rights
mysql_database_user node['drupal']['db']['user'] do
  connection connection_info
  password node['drupal']['db']['password']
  database_name node['drupal']['db']['database']
  host node['drupal']['db']['host']
  privileges [:all]
  action :grant
end

mysql_database_user node['drupal']['db']['user'] do
  connection connection_info
  password node['drupal']['db']['password']
  database_name node['drupal']['db']['database']
  host '%'
  privileges [:all]
  action :grant
end

mysql_database node['drupal']['db']['database'] do
  connection connection_info
  sql "flush privileges"
  action :query
end

execute "download-and-install-drupal" do
  cwd  File.dirname(node['drupal']['dir'])
  command "#{node['drupal']['drush']['dir']}/drush -y dl drupal-#{node['drupal']['version']} --destination=#{File.dirname(node['drupal']['dir'])} --drupal-project-rename=#{File.basename(node['drupal']['dir'])} && \
  #{node['drupal']['drush']['dir']}/drush -y site-install -r #{node['drupal']['dir']} --account-name=#{node['drupal']['site']['admin']} --account-pass=#{node['drupal']['site']['pass']} --site-name=\"#{node['drupal']['site']['name']}\" \
  --db-url=mysql://#{node['drupal']['db']['user']}:'#{node['drupal']['db']['password']}'@#{node['drupal']['db']['host']}/#{node['drupal']['db']['database']}"
  not_if "#{node['drupal']['drush']['dir']}/drush -r #{node['drupal']['dir']} status | grep #{node['drupal']['version']}"
end

if node.has_key?("ec2")
  server_fqdn = node['ec2']['public_hostname']
else
  server_fqdn = node['fqdn']
end

directory "#{node['drupal']['dir']}/sites/default/files" do
  mode "0777"
  action :create
end

template "#{node['drupal']['dir']}/sites/default/settings.php" do
  source "d#{node['drupal']['version'][0..0]}.settings.php.erb"
  mode "0644"
  variables(
    'database'        => node['drupal']['db']['database'],
    'user'            => node['drupal']['db']['user'],
    'password'        => node['drupal']['db']['password'],
    'host'            => node['drupal']['db']['host']
  )
end

if node['drupal']['modules']
  node['drupal']['modules'].each do |m|
    if m.is_a?Array
      drupal_module m.first do
        version m.last
        dir node['drupal']['dir']
      end
    else
      drupal_module m do
        dir node['drupal']['dir']
      end
    end
  end
end

web_app "drupal" do
  template "drupal.conf.erb"
  docroot node['drupal']['dir']
  server_name server_fqdn
  server_aliases node['fqdn']
end

include_recipe "drupal::cron"

execute "disable-default-site" do
   command "sudo a2dissite default"
   notifies :reload, "service[apache2]", :delayed
   only_if do File.exists? "#{node['apache']['dir']}/sites-enabled/default" end
end
