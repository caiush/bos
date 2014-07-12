#
# Cookbook Name:: bcpc
# Recipe:: stunnel
#
# Copyright 2014, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "bcpc::default"

package "stunnel4" do
    action :upgrade
end

bash "enable-defaults-stunnel4" do
    user "root"
    code <<-EOH
        sed --in-place '/^ENABLED=/d' /etc/default/stunnel4
        echo 'ENABLED=1' >> /etc/default/stunnel4
    EOH
    not_if "grep -e '^ENABLED=1' /etc/default/stunnel4"
end

template "/etc/stunnel/keystone.conf" do
    source "stunnel-keystone.conf.erb"
    mode 00644
    notifies :restart, "service[stunnel4]", :immediately
end

service "stunnel4" do
    action [:enable, :start]
end
