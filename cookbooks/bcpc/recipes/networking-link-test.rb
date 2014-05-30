#
# Cookbook Name:: bcpc
# Recipe:: networking-link-test
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

othernodes=[]

# prepare tests for ping testing peers
ruby_block "setup-other-hosts" do
  block do
    get_all_nodes.each do |host|
      host.roles.each do |role|
        if role == "BCPC-Worknode" || role == "BCPC-Headnode" then
          if host.hostname != node.hostname then
            unless othernodes.include? host then
              othernodes.push host
              message = "Found a peer : " + host.hostname
              Chef::Log.info(message)
            end
          end
        end
      end
    end
    # if there are no other nodes, then I am the first. If so, ensure
    # the tests will still pass by referencing myself
    if othernodes.empty? then
      message = "No peers, using self : " + node.hostname
      Chef::Log.info(message)
      othernodes.push node
    end
  end
end

template "/etc/floating-peers" do
  source "floating-peers.erb"
  mode 0644
  variables( :servers => othernodes) 
end


template "/etc/storage-peers" do
  source "storage-peers.erb"
  mode 0644
  variables( :servers => othernodes) 
end


# Run tests

# There is no test for the management network. It must be up if we can
# Chef it

#
# Test that we can ping at least one storage network peer.
#
# The aim of this test is to help during initial cluster build, when
# the network may not have been debugged. We do not want to join
# cluster members to the existing cluster unless they have the full
# complement of network links
#
# Later on, however, if perhaps there have been some failures, we do
# not want to prevent recovery by preventing chef from running in
# scenarios we can't anticipate. Therefore this test disables itself
# once it has passed once. To re-enable, simply remove the success
# file by hand

bash "ping-storage-peers" do
  code <<-EOH
    SUCCESSFILE=/etc/storage-test-success
    # bypass once this test has passed once
    if [[ -f "$SUCCESSFILE" ]]; then
      exit 0
    fi
    # return 0 if ANY IP address responds
    while read IP; do
      ping -c1 ${IP} > /dev/null 2>&1
        if [[ $? = 0 ]]; then
          # this IP responds, network link must work
          touch "$SUCCESSFILE"
          exit 0
        fi
    done < /etc/storage-peers
    # if none found, cannot proceed
    echo "-----------------------------------------------------------------------------"
    echo "-----------------------------------------------------------------------------"
    echo "- Network test failed : no storage peers respond, perhaps the cable is bad  -"
    echo "-----------------------------------------------------------------------------"
    echo "-----------------------------------------------------------------------------"
    exit 1
  EOH
end

#
# Test that we can ping at least one floating network peer.
#
# This test also self-disables after passing (see previous comments)
#
bash "ping-floating-peers" do
  code <<-EOH
    SUCCESSFILE=/etc/floating-test-success
    # bypass once this test has passed once
    if [[ -f "$SUCCESSFILE" ]]; then
      exit 0
    fi
    # return 0 if ANY IP address responds
    while read IP; do
      ping -c1 ${IP} > /dev/null 2>&1
        if [[ $? = 0 ]]; then
          # this IP responds, network link must work
          touch "$SUCCESSFILE"
          exit 0
        fi
    done < /etc/floating-peers
    # if none found, cannot proceed
    echo "-----------------------------------------------------------------------------"
    echo "-----------------------------------------------------------------------------"
    echo "- Network test failed : no floating peers respond, perhaps the cable is bad -"
    echo "-----------------------------------------------------------------------------"
    echo "-----------------------------------------------------------------------------"
    exit 1
  EOH
end




