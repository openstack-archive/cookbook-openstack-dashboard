Team and repository tags
========================

[![Team and repository tags](http://governance.openstack.org/badges/cookbook-openstack-dashboard.svg)](http://governance.openstack.org/reference/tags/index.html)

<!-- Change things from this point on -->

![Chef OpenStack Logo](https://www.openstack.org/themes/openstack/images/project-mascots/Chef%20OpenStack/OpenStack_Project_Chef_horizontal.png)

Description
===========

Installs the OpenStack Dashboard service **Horizon** as part of the OpenStack
reference deployment Chef for OpenStack. The
https://github.com/openstack/openstack-chef-repo contains documentation for using
this cookbook in the context of a full OpenStack deployment. Horizon is
currently installed from packages.

http://docs.openstack.org/mitaka/config-reference/dashboard.html

Requirements
============

- Chef 12 or higher
- chefdk 0.9.0 or higher for testing (also includes berkshelf for cookbook
  dependency resolution)

Platform
========

- ubuntu
- redhat
- centos

Cookbooks
=========

The following cookbooks are dependencies:

- 'apache2', '~> 3.1'
- 'openstack-common', '>= 14.0.0'
- 'openstack-identity', '>= 14.0.0'

Attributes
==========

Please see the extensive inline documentation in `attributes/*.rb` for
descriptions of all the settable attributes for this cookbook.

Note that all attributes are in the `default['openstack']` "namespace"

Recipes
=======

## openstack-dashboard::horizon
- Sets up the packages needed to run the Horizon dashboard and its dependencies.
  Includes openstack-dashboard::apache2-server recipe.

## openstack-dashboard::apache2-server
- Installs the Apache webserver and sets up an `mod_wsgi` container to run the
  Horizon dashboard.

## openstack-dashboard::neutron-lbaas-dashboard
- Installs the python neutron-lbaas-dashboard package. Includes
  openstack-dashboard::horizon recipe at the beginning.


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
| **Author**           |  Jan Klare (<j.klare@cloudbau.de>)                 |
| **Author**           |  Christoph Albers (<c.albers@x-ion.de>)            |
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
