#
# Cookbook Name:: bcpc
# Recipe:: ceph-work
#
# Copyright 2013, Bloomberg Finance L.P.
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

include_recipe "bcpc::ceph-common"

bash "write-bootstrap-osd-key" do
    code <<-EOH
        BOOTSTRAP_KEY=`ceph --name mon. --keyring /etc/ceph/ceph.mon.keyring auth get-or-create-key client.bootstrap-osd mon 'allow profile bootstrap-osd'`
        ceph-authtool "/var/lib/ceph/bootstrap-osd/ceph.keyring" \
            --create-keyring \
            --name=client.bootstrap-osd \
            --add-key="$BOOTSTRAP_KEY"
    EOH
    not_if "test -f /var/lib/ceph/bootstrap-osd/ceph.keyring"
end

%w{ssd hdd}.each do |type|
    node['bcpc']['ceph']["#{type}_disks"].each do |disk|
        execute "ceph-disk-prepare-#{type}-#{disk}" do
            command <<-EOH
                ceph-disk-prepare /dev/#{disk}
                ceph-disk-activate /dev/#{disk}
                sleep 2
                INFO=`df -k | grep /dev/#{disk} | awk '{print $2,$6}' | sed -e 's/\\/var\\/lib\\/ceph\\/osd\\/ceph-//'`
                OSD=${INFO#* }
                WEIGHT=`echo "scale=4; ${INFO% *}/1000000000.0" | bc -q`
                ceph osd crush create-or-move $OSD $WEIGHT root=#{type} rack=#{node['bcpc']['rack_name']}-#{type} host=#{node['hostname']}-#{type}
            EOH
            not_if "sgdisk -i1 /dev/#{disk} | grep -i 4fbd7e29-9d25-41b8-afd0-062c0ceff05d"
        end
    end
end

execute "trigger-osd-startup" do
    command "udevadm trigger --subsystem-match=block --action=add"
end

ruby_block "reap-ceph-disks-from-dead-servers" do
    block do
        storage_ips = search_nodes("recipe", "ceph-work").collect { |x| x['bcpc']['storage']['ip'] }
        status = JSON.parse(%x[ceph osd dump --format=json])
        status['osds'].select { |x| x['up']==0 && x['in']==0 }.each do |osd|
            osd_ip = osd['public_addr'][/[^:]*/]
            if osd_ip != "" and not storage_ips.include?(osd_ip)
                %x[
                    ceph osd crush remove osd.#{osd['osd']}
                    ceph osd rm osd.#{osd['osd']}
                    ceph auth del osd.#{osd['osd']}
                ]
            end
        end
    end
end

execute "cephfs-in-fstab" do
    command <<-EOH
        echo "-- /mnt fuse.ceph-fuse rw,nosuid,nodev,noexec,noatime,noauto 0 2" >> /etc/fstab
    EOH
    not_if "cat /etc/fstab | grep ceph-fuse"
end

execute "cephfs-mount-fs" do
    command <<-EOH
        mount -a
    EOH
    not_if "mount | grep ceph-fuse"
end
