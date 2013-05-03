name             "horizon"
maintainer       "AT&T Services, Inc."
maintainer_email "cookbooks@lists.tfoundry.com"
license          "Apache 2.0"
description      "Installs/Configures the OpenStack Dasboard (Horizon)"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "2012.2.0"

recipe           "horizon::db", "Configures database for use with Horizon"
recipe           "horizon::server", "Sets up the Horizon dashboard within an Apache `mod_wsgi` container."

supports         "centos"
supports         "fedora"
supports         "redhat"
supports         "ubuntu"

depends          "apache2"
depends          "database"
depends          "mysql"
depends          "openstack-common", ">= 0.1.8"
