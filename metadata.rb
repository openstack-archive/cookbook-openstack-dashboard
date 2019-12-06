name             'openstack-dashboard'
maintainer       'openstack-chef'
maintainer_email 'openstack-discuss@lists.openstack.org'
license          'Apache-2.0'
description      'Installs/Configures the OpenStack Dashboard (Horizon)'
version          '18.0.0'

recipe 'horizon', 'Sets up the packages needed to run the Horizon dashboard and its dependencies.'
recipe 'apache2-server', 'Installs the Apache webserver to run the Horizon dashboard.'
recipe 'neutron-fwaas-dashboard', 'Installs the python neutron-fwaas-dashboard package.'
recipe 'neutron-lbaas-dashboard', 'Installs the python neutron-lbaas-dashboard package.'

%w(ubuntu redhat centos).each do |os|
  supports os
end

depends 'openstack-common', '>= 18.0.0'
depends 'openstack-identity', '>= 18.0.0'
depends 'apache2', '5.0.1'
depends 'poise-python'

issues_url 'https://launchpad.net/openstack-chef'
source_url 'https://opendev.org/openstack/cookbook-openstack-dashboard'
chef_version '>= 14.0'
