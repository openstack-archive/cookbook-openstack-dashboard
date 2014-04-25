Description
===========

Installs the OpenStack Dashboard service **Horizon** as part of the OpenStack reference deployment Chef for OpenStack. The http://github.com/mattray/chef-openstack-repo contains documentation for using this cookbook in the context of a full OpenStack deployment. Horizon is currently installed from packages.

http://horizon.openstack.org

Requirements
============

* Chef 0.10.0 or higher required (for Chef environment use).

Cookbooks
---------

The following cookbooks are dependencies:

* apache2
* openstack-common

Usage
=====

server
------

Sets up the Horizon dashboard within an Apache `mod_wsgi` container.

```json
"run_list": [
    "recipe[openstack-dashboard::server]"
]
```

Attributes
==========

* `openstack["dashboard"]["db"]["username"]` - username for horizon database access
* `openstack["dashboard"]["server_hostname"]` - sets the ServerName in the Apache config.
* `openstack["dashboard"]["use_ssl"]` - toggle for using ssl with dashboard (default true)
* `openstack["dashboard"]["ssl"]["dir"]` - directory where ssl certs are stored on this system
* `openstack["dashboard"]["dash_path"]` - base path for dashboard files (document root)
* `openstack["dashboard"]["wsgi_path"]` - path for wsgi dir
* `openstack["dashboard"]["wsgi_socket_prefix"]` - Location that will override the standard Apache runtime directory
* `openstack["dashboard"]["ssl_offload"]` - Set SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTOCOL', 'https') flag for offloading SSL
* `openstack["dashboard"]["plugins"]` - Array of plugins to include via INSTALED\_APPS
* `openstack["dashboard"]["simple_ip_management"]` - Boolean to enable or disable simplified floating IP address management
TODO: Add DB2 support on other platforms
* `openstack["dashboard"]["platform"]["db2_python_packages"]` - Array of DB2 python packages, only available on redhat platform
* `openstack['openstack']['dashboard']['http_port']` - Port that httpd should listen on. Default is 80.
* `openstack['openstack']['dashboard']['https_port']` - Port that httpd should listen on for using ssl. Default is 443.

Certificate
-----------
* `openstack["dashboard"]["ssl"]["cert"]` - name to use when creating the ssl certificate
* `openstack["dashboard"]["ssl"]["cert_url"]` - if using an existing certificate, this is the URL to its location
* `openstack["dashboard"]["ssl"]["key"]` - name to use when creating the ssl key
* `openstack["dashboard"]["ssl"]["key_url"]` - if using an existing certificate key, this is the URL to its location

By default the openstack-dashboard cookbook ships with a self-signed certificate from a fake organization.
It is possible to use a real production certificate from your organization by putting that certificate
somewhere where the cookbook can download it from then simply passing in the URL of the certificate, and its
corresponding key, using the 'cert_url' and 'key_url' attributes.

Testing
=====

Please refer to the [TESTING.md](TESTING.md) for instructions for testing the cookbook.

Berkshelf
=====

Berks will resolve version requirements and dependencies on first run and
store these in Berksfile.lock. If new cookbooks become available you can run
`berks update` to update the references in Berksfile.lock. Berksfile.lock will
be included in stable branches to provide a known good set of dependencies.
Berksfile.lock will not be included in development branches to encourage
development against the latest cookbooks.

License and Author
==================

|                      |                                                    |
|:---------------------|:---------------------------------------------------|
| **Author**           |  Justin Shepherd (<justin.shepherd@rackspace.com>) |
| **Author**           |  Jason Cannavale (<jason.cannavale@rackspace.com>) |
| **Author**           |  Ron Pedde (<ron.pedde@rackspace.com>)             |
| **Author**           |  Joseph Breu (<joseph.breu@rackspace.com>)         |
| **Author**           |  William Kelly (<william.kelly@rackspace.com>)     |
| **Author**           |  Darren Birkett (<darren.birkett@rackspace.co.uk>) |
| **Author**           |  Evan Callicoat (<evan.callicoat@rackspace.com>)   |
| **Author**           |  Jay Pipes (<jaypipes@att.com>)                    |
| **Author**           |  John Dewey (<jdewey@att.com>)                     |
| **Author**           |  Matt Ray (<matt@opscode.com>)                     |
| **Author**           |  Sean Gallagher (<sean.gallagher@att.com>)         |
| **Author**           |  Chen Zhiwei (<zhiwchen@cn.ibm.com>)               |
| **Author**           |  Jian Hua Geng (<gengjh@cn.ibm.com>)               |
| **Author**           |  Ionut Artarisi (<iartarisi@suse.cz>)              |
| **Author**           |  Eric Zhou (<iartarisi@suse.cz>)                   |
|                      |                                                    |
| **Copyright**        |  Copyright (c) 2012, Rackspace US, Inc.            |
| **Copyright**        |  Copyright (c) 2012-2013, AT&T Services, Inc.      |
| **Copyright**        |  Copyright (c) 2013, Opscode, Inc.                 |
| **Copyright**        |  Copyright (c) 2013-2014, IBM, Corp.               |
| **Copyright**        |  Copyright (c) 2013-2014, SUSE Linux GmbH.         |

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
