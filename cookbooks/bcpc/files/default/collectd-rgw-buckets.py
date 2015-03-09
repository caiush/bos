#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""For use with collectd.

Gathers stats about buckets sizes. Note it doesnt give stats abuot IO
into these buckets. For that see the rgw-buckets-usage.py

         Import "collectd-ceph"
         <Module collectd-ceph>
           aws_key "Xxxxxxxxxx"
           secret "xxxxxxxxx"
           admin_url "http://127.0.0.1:8080"
         </Module>
"""

import collectd
import requests
from awsauth import S3Auth
import sys

aws_key = 'fillmein' 
secret = 'fillmein' 
server = '127.0.0.1:8080' #'192.168.100.12:8045'

def my_config(conf):
    """
    Accept module configuration from CollectD.
    """
    global server
    global aws_key
    global secret
    collectd.error("calling config")
    for c in conf.children:
        if c.key == 'aws_key':
            aws_key = c.values[0]
        if c.key == 'secret':
            secret = c.values[0]
        if c.key == 'admin_url':
            server = c.values[0]
    collectd.notice("rgw-buckets: aws_key: %s admin_url: %s " % (aws_key, server ))

def read():
    url = 'http://%s/admin/bucket?stats=True' % server
    try:
        r = requests.get(url, auth=S3Auth(aws_key, secret, server))
        if r.status_code!=200:
            collectd.notice("rgw-buckets: Request to %s failed: (%d) %s" % (url, r.status_code, r.text ))
            return
    except requests.exceptions.RequestException as e:
        collectd.error("Failed to connect to %s: %s " % (url, str(e)))
        return 

    rr = r.json()
    v = collectd.Values()
    v.plugin = "rgw"

    for bucket in rr:
        if type(bucket) !=dict:
            continue
        bucket_name = bucket[u"bucket"]
        owner_name = bucket[u"owner"]
        v.type_instance =  "%s.%s.%s" %(owner_name, bucket_name, "mtime")
        v.values = [bucket[u"mtime"]]
        v.type = 'gauge'
        v.dispatch()

        v.type_instance = "%s.%s.%s" %(owner_name, bucket_name, "ver")
        v.values = [bucket[u"ver"]]
        v.type = 'gauge'
        v.dispatch()

        for stat in [u'size_kb_actual', u'num_objects', u'size_kb']:
            v.type_instance = "%s.%s.%s" %(owner_name, bucket_name, stat)
            v.values = [bucket[u"usage"][u"rgw.main"][stat]]
            v.type = 'gauge'
            v.dispatch()


collectd.register_config(my_config)
collectd.register_read(read)

