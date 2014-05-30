#
# Cookbook Name:: bcpc
# Recipe:: networking-gw-test
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

storagegw=[]
floatinggw=[]
isvm=false
virttype=nil


if node[:bcpc][:virt_type] != "kvm"
  isvm=true
  virrtype=node[:bcpc][:virt_type]
end

# prepare tests for storage gateway
ruby_block "setup-storage-gw" do
  block do
    if storagegw.empty? then
      storagegw.push node
    end
  end
end

template "/etc/storage-gw" do
  source "storage-gw.erb"
  mode 0644
  variables( :servers => storagegw)
end

# prepare tests for floating gatway
ruby_block "setup-floating-gw" do
  block do
    if floatinggw.empty? then
      floatinggw.push node
      somenode = node
    end
  end
end

template "/etc/floating-gw" do
  source "floating-gw.erb"
  mode 0644
  variables( :servers => floatinggw)
end


# test that we can ping the storage gateway
bash "ping-storage-gw" do
  code <<-EOH
    # return 0 if ANY IP address responds
    while read IP; do
      ping -c1 ${IP} > /dev/null 2>&1
        if [[ $? = 0 ]]; then
          # this IP responds, storage gateway reachable
          exit 0
        fi
    done < /etc/storage-gw
    # if none found, cannot proceed
    echo "-----------------------------------------------------------------------------"
    echo "-----------------------------------------------------------------------------"
    echo "- Network test failed : storage gateway unreachable                         -"
    echo "-----------------------------------------------------------------------------"
    echo "-----------------------------------------------------------------------------"
    exit 1
  EOH
  not_if do 
    if isvm then
      message = "Warning : storage gateway test bypassed due to virtualised environment " 
      Chef::Log.info(message)
      true
    end
  end
end


# test that we can ping the floating gateway
bash "ping-floating-gw" do
  code <<-EOH
    # return 0 if ANY IP address responds
    while read IP; do
      ping -c1 ${IP} > /dev/null 2>&1
        if [[ $? = 0 ]]; then
          # this IP responds, floating gateway reachable
          exit 0
        fi
    done < /etc/floating-gw
    # if none found, cannot proceed
    echo "-----------------------------------------------------------------------------"
    echo "-----------------------------------------------------------------------------"
    echo "- Network test failed : floating gateway unreachable                        -"
    echo "-----------------------------------------------------------------------------"
    echo "-----------------------------------------------------------------------------"
    exit 1
  EOH
  not_if do 
    if isvm then
      message = "Warning : floating gateway test bypassed due to virtualised environment " 
      Chef::Log.info(message)
      true
    end
  end
end





