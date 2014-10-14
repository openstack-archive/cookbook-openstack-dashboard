name             'openstack-dashboard'
maintainer       'openstack-chef'
maintainer_email 'opscode-chef-openstack@googlegroups.com'
license          'Apache 2.0'
description      'Installs/Configures the OpenStack Dasboard (Horizon)'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '10.0'

recipe           'openstack-dashboard::server', 'Sets up the Horizon dashboard within an Apache `mod_wsgi` container.'

%w{ ubuntu fedora redhat centos suse }.each do |os|
  supports os
end

depends          'apache2', '< 2.0.0'
depends          'openstack-common', '~> 10.0'
