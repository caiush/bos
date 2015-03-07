Overview
========

A fork of [chef-bcpc](http://www.github.com/bloomberg/chef-bcpc) but targeted directly at an fast and robust object store. After running chef-bcpc object store in production for 18months, i decided to rip out justt he ceph object store. The reduction in scope allows us to focus to make some simplifcations to the system to get the best perfomance out fo the system.


Currently, these changes are:

* Removal of all openstack components, this is *just* object store.
* Rewrite of the networking system to remove much of the complexity that was required to make openstack go. 
* Dedicated roles. chef-bcpc has "headnodes" and "workernodes". In BOS each node has a dedicated purpose, e.g. OSD storage or ceph monitors, reducing burden on mons and allowing the specalization of hardware. 



