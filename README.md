Description
===========

Installs the Openstack dashboard (codename: Horizon) from packages.

http://horizon.openstack.org

Requirements
============

Chef 0.10.0 or higher required (for Chef environment use).

Platforms
--------

* Ubuntu-12.04
* Fedora-17

Cookbooks
---------

The following cookbooks are dependencies:

* apache2
* database
* mysql

Recipes
=======

server
------
* Sets up the Horizon dashboard within an Apache `mod_wsgi` container. 

Attributes 
==========

* `horizon["db"]["username"]` - username for horizon database access

* `horizon["use_ssl"]` - toggle for using ssl with dashboard (default true)
* `horizon["ssl"]["dir"]` - directory where ssl certs are stored on this system
* `horizon["ssl"]["cert"]` - name to use when creating the ssl certificate
* `horizon["ssl"]["key"]` - name to use when creating the ssl key

* `horizon["dash_path"]` - base path for dashboard files (document root)
* `horizon["wsgi_path"]` - path for wsgi dir

Templates
=====

* `dash-site.erb` - the apache config file for the dashboard vhost
* `local_settings.py.erb` - config file for the dashboard application


License and Author
==================

Author:: Justin Shepherd (<justin.shepherd@rackspace.com>)  
Author:: Jason Cannavale (<jason.cannavale@rackspace.com>)  
Author:: Ron Pedde (<ron.pedde@rackspace.com>)  
Author:: Joseph Breu (<joseph.breu@rackspace.com>)  
Author:: William Kelly (<william.kelly@rackspace.com>)  
Author:: Darren Birkett (<darren.birkett@rackspace.co.uk>)  
Author:: Evan Callicoat (<evan.callicoat@rackspace.com>)  

Copyright 2012, Rackspace US, Inc.  
