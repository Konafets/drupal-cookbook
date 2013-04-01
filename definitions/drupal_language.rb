#
# Author:: Stefano Kowalke <blueduck@gmx.net>
# Cookbook Name:: drupal
# Definition:: drupal_language
#
# Copyright 2013, Stefano Kowalke
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

define :drupal_language, :action => :add, :name => nil, :dir => nil do
  execute "drush_install_language_module" do
    command "#{node['drupal']['drush']['dir']}/drush -y dl drush_language"
    not_if "#{node['drupal']['drush']['dir']}/drush | grep language:"
  end
  
  case params[:action]
  when :add
    execute "drush_add_language #{params[:name]}" do
      cwd params[:dir]
      command "#{node['drupal']['drush']['dir']}/drush -y language-add #{params[:name]}"
    end
  when :enable
    execute "drush_enable_language #{params[:name]}" do
      cwd params[:dir]
      command "#{node['drupal']['drush']['dir']}/drush -y language-enable #{params[:name]}"
    end
  when :disable
    execute "drush_disable_language #{params[:name]}" do
      cwd params[:dir]
      command "#{node['drupal']['drush']['dir']}/drush -y language-disable #{params[:name]}"
    end
  when :setdefault
    execute "drush_set_default_language #{params[:name]}" do
      cwd params[:dir]
      command "#{node['drupal']['drush']['dir']}/drush -y language-default #{params[:name]}"
    end
  else
    log "drush_language action #{params[:name]} is unreconized."
  end
end