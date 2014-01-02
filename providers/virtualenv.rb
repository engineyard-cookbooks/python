#
# Author:: Seth Chisamore <schisamo@opscode.com>
# Cookbook Name:: python
# Provider:: virtualenv
#
# Copyright:: 2011, Opscode, Inc <legal@opscode.com>
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

require 'chef/mixin/shell_out'
require 'chef/mixin/language'
include Chef::Mixin::ShellOut

def whyrun_supported?
  true
end

action :create do
  unless exists?
    directory new_resource.path do
      user new_resource.owner if new_resource.owner
      group new_resource.group if new_resource.group
    end
    Chef::Log.info("Creating virtualenv #{new_resource} at #{new_resource.path}")
    interpreter = new_resource.interpreter ? " --python=#{new_resource.interpreter}" : ""
    execute "#{virtualenv_cmd}#{interpreter} #{new_resource.options} #{new_resource.path}" do
      env = {}
      if new_resource.owner
        env['HOME'] = begin
                        require 'etc'
                        Etc.getpwnam(new_resource.owner).dir
                      rescue ArgumentError # user not found
                        raise Chef::Exceptions::User, "Could not determine HOME for specified user '#{new_resource.owner}' for resource '#{new_resource.name}'"
                      end
      end
      user new_resource.owner if new_resource.owner
      group new_resource.group if new_resource.group
      environment env unless env.empty?
    end
    new_resource.updated_by_last_action(true)
  end
end

action :delete do
  if exists?
    description = "delete virtualenv #{new_resource} at #{new_resource.path}"
    converge_by(description) do
       Chef::Log.info("Deleting virtualenv #{new_resource} at #{new_resource.path}")
       FileUtils.rm_rf(new_resource.path)
    end
  end
end

def load_current_resource
  @current_resource = Chef::Resource::PythonVirtualenv.new(new_resource.name)
  @current_resource.path(new_resource.path)

  if exists?
    cstats = ::File.stat(current_resource.path)
    @current_resource.owner(cstats.uid)
    @current_resource.group(cstats.gid)
  end
  @current_resource
end

def virtualenv_cmd()
  if ::File.exists?(node['python']['virtualenv_location'])
    node['python']['virtualenv_location']
  else
    "virtualenv"
  end
end

private
def exists?
  ::File.exist?(current_resource.path) && ::File.directory?(current_resource.path) \
    && ::File.exists?("#{current_resource.path}/bin/activate")
end
