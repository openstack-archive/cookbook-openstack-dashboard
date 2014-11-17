# encoding: UTF-8
#
# Cookbook Name:: openstack-dashboard
# Recipe:: server
#
# Copyright 2012, Rackspace US, Inc.
# Copyright 2012-2013, AT&T Services, Inc.
# Copyright 2013-2014, IBM, Corp.
# Copyright 2014, SUSE Linux, GmbH.
# Copyright 2014, x-ion GmbH.
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

include_recipe 'openstack-dashboard::horizon'
include_recipe "openstack-dashboard::#{node['openstack']['dashboard']['server_type']}-server"
