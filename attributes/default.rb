default["horizon"]["db"]["username"] = "dash"                                               # node_attribute
default["horizon"]["db"]["password"] = "dash"                                               # node_attribute
default["horizon"]["db"]["name"] = "dash"                                                   # node_attribute

default["horizon"]["use_ssl"] = true                                                        # node_attribute
default["horizon"]["ssl"]["cert"] = "horizon.pem"                                           # node_attribute
default["horizon"]["ssl"]["key"] = "horizon.key"                                            # node_attribute

default["horizon"]["theme"] = "default"

case node["platform"]
when "fedora", "centos", "redhat", "amazon", "scientific"
  default["horizon"]["ssl"]["dir"] = "/etc/pki/tls"                                         # node_attribute
  default["horizon"]["local_settings_path"] = "/etc/openstack-dashboard/local_settings"     # node_attribute
  # TODO(shep) - Fedora does not generate self signed certs by default
  default["horizon"]["platform"] = {                                                   # node_attribute
    "horizon_packages" => ["openstack-dashboard"],
    "package_overrides" => ""
  }
when "ubuntu", "debian"
  default["horizon"]["ssl"]["dir"] = "/etc/ssl"                                             # node_attribute
  default["horizon"]["local_settings_path"] = "/etc/openstack-dashboard/local_settings.py"  # node_attribute
  default["horizon"]["platform"] = {                                                   # node_attribute
    "horizon_packages" => ["lessc","openstack-dashboard"],
    "package_overrides" => "-o Dpkg::Options::='--force-confold' -o Dpkg::Options::='--force-confdef'"
  }
end

default["horizon"]["dash_path"] = "/usr/share/openstack-dashboard/openstack_dashboard"      # node_attribute
default["horizon"]["stylesheet_path"] = "/usr/share/openstack-dashboard/openstack_dashboard/templates/_stylesheets.html"
default["horizon"]["wsgi_path"] = node["horizon"]["dash_path"] + "/wsgi"                    # node_attribute
