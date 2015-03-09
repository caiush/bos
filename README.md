Overview
========

A fork of [chef-bcpc](http://www.github.com/bloomberg/chef-bcpc) but targeted directly at a fast and robust object store. After running chef-bcpc object store in production for 18months, for fun I decided to rip out just the ceph object store. 

Currently this differs from BCPC in the following ways:

* Removal of all openstack components, this is *just* object store.
* Rewrite of the networking system to remove much of the complexity that was required to make openstack go. 
* Dedicated roles. chef-bcpc has "headnodes" and "workernodes". In BOS each node has a dedicated purpose, e.g. OSD storage or ceph monitors, reducing burden on mons and allowing the specalization of hardware. 
* Collectd based monitoring, in painful detail, of the health of ceph. 
* Changes in the RGW configurations, e.g. civetweb rather than apache, varnish rather than haproxy.  

Monitoring
==========

BOS uses collectd to monitor the state of the system. Currently, all perf counters are monitored and stats about each bucket. Per bucket stats are labeled like so, `<username>.<bucket_name>.<stat>`.

Stats are reported every 5 mins by default. 
