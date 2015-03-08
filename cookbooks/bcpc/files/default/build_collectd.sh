#!/bin/bash -e

# if you need a proxy set them here:
# export http_proxy=http://myproxy.example.com:80
# export https_proxy=http://myproxy.example.com:80

set -x
cwd=$PWD
build_dir=/tmp/build/
mkdir -p  $build_dir 
cd $build_dir
wget --no-check-certificate https://collectd.org/files/collectd-5.4.1.tar.gz
tar zxf collectd-5.4.1.tar.gz 

sudo apt-get install build-essential  
mkdir -p /tmp/collectd
sudo apt-get -y install libcurl3 librrd2-dev libsnmp-dev
cd collectd-5.4.1
 ./configure --prefix=/tmp/collectd 
make install

tar zcf /tmp/collectd.tgz ./*
cd $cwd
mkdir -p bins 
cd bins
mv /tmp/collectd.tgz .
