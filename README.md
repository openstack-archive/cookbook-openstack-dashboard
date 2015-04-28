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

horizon
-------

Sets up the packages needed to run the Horizon dashboard and its dependencies.
Will be included from the `server` recipe.

apache2-server
--------------

Installs the Apache webserver and sets up an `mod_wsgi` container to run the
Horizon dashboard.  Will be included from the `server` recipe.

server
------

Sets up the Horizon dashboard and a webserver of type `['openstack']['dashboard']['server_type']`
to run it, default type is 'apache2'.

```json
"run_list": [
    "recipe[openstack-dashboard::server]"
]
```

Attributes
==========

* `openstack['dashboard']['server_type']` - Selects the type of webserver to install
* `openstack['dashboard']['db']['username']` - Username for horizon database access
* `openstack['dashboard']['server_hostname']` - Sets the ServerName in the webserver config
* `openstack['dashboard']['allowed_hosts']` - List of host/domain names we can service (default: '\[\*\]')
* `openstack['dashboard']['dash_path']` - Base path for dashboard files (document root)
* `openstack['dashboard']['wsgi_path']` - Path for wsgi dir
* `openstack['dashboard']['wsgi_socket_prefix']` - Location that will override the standard Apache runtime directory
* `openstack['dashboard']['ssl_offload']` - Set SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTOCOL', 'https') flag for offloading SSL
* `openstack['dashboard']['plugins']` - Array of plugins to include via INSTALED\_APPS
* `openstack['dashboard']['simple_ip_management']` - Boolean to enable or disable simplified floating IP address management
* `openstack['dashboard']['password_autocomplete']` - Toggle browser autocompletion for login form ('on' or 'off', default: 'off')
* `openstack['dashboard']['ssl_no_verify']` - Disable SSL certificate checks (useful for self-signed certificates)
* `openstack['dashboard']['ssl_cacert']` - The CA certificate to use to verify SSL connections
* `openstack['dashboard']['misc_local_settings']` - Additions to the local_settings conf file
* `openstack['dashboard']['hash_algorithm']` - Hash algorithm to use for hashing PKI tokens

For listen addresses and ports, there are http and https bind endpoints defined in Common.

Identity
--------
* `openstack['dashboard']['identity_api_version']` - Force a specific Identity API version ('2.0' or '3', default: '2.0')
* `openstack['dashboard']['volume_api_version']` - Force a specific Cinder API version (default: '2')
* `openstack['dashboard']['keystone_multidomain_support']` - Boolean to enable multi-Domain support
* `openstack['dashboard']['keystone_default_domain']` - Default Domain if using API v3 and on a single-domain model (default: 'Default')
* `openstack['dashboard']['keystone_default_role']` - Default Keystone role assigned to project members (default: '_member_')
* `openstack['dashboard']['keystone_backend']['name']` - Keystone backend in use ('native' or 'ldap', default: 'native')
* `openstack['dashboard']['keystone_backend']['can_edit_user']` - Boolean to allow some user-related identity operations (default: true)
* `openstack['dashboard']['keystone_backend']['can_edit_group']` - Boolean to allow some group-related identity operations (default: true)
* `openstack['dashboard']['keystone_backend']['can_edit_project']` - Boolean to allow some project-related identity operations (default: true)
* `openstack['dashboard']['keystone_backend']['can_edit_domain']` - Boolean to allow some domain-related identity operations (default: true)
* `openstack['dashboard']['keystone_backend']['can_edit_role']` - Boolean to allow some role-related identity operations (default: true)

Certificate
-----------
* `openstack['dashboard']['use_ssl']` - Toggle for using ssl with dashboard (default: true)
* `openstack['dashboard']['ssl']['dir']` - Directory where ssl certs are stored on this system (default: platform dependent)
* `openstack['dashboard']['ssl']['cert']` - Name to use when creating the ssl certificate
* `openstack['dashboard']['ssl']['cert_url']` - If using an existing certificate, this is the URL to its location
* `openstack['dashboard']['ssl']['key']` - Name to use when creating the ssl key
* `openstack['dashboard']['ssl']['key_url']` - If using an existing certificate key, this is the URL to its location

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
| **Author**           |  Jens Rosenboom (<j.rosenboom@x-ion.de>)           |
| **Author**           |  Mark Vanderwiel (<vanderwl@us.ibm.com>)           |
| **Author**           |  Jan Klare (<j.klare@x-ion.de>)                    |
|                      |                                                    |
| **Copyright**        |  Copyright (c) 2012, Rackspace US, Inc.            |
| **Copyright**        |  Copyright (c) 2012-2013, AT&T Services, Inc.      |
| **Copyright**        |  Copyright (c) 2013, Opscode, Inc.                 |
| **Copyright**        |  Copyright (c) 2013-2015, IBM, Corp.               |
| **Copyright**        |  Copyright (c) 2013-2014, SUSE Linux GmbH.         |
| **Copyright**        |  Copyright (c) 2014, x-ion GmbH.                   |

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
