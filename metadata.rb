maintainer       "AT&T, Inc."
license          "Apache 2.0"
description      "Installs/Configures the OpenStack Dasboard (Horizon)"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "2012.2.0"
name             "horizon"

supports         "ubuntu"

depends          "apache2"
depends          "database"
depends          "mysql"
depends          "openstack-common", ">= 0.1.7"
