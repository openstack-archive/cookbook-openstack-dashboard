default["horizon"]["db"]["username"] = "dash"                                               # node_attribute
default["horizon"]["db"]["password"] = "dash"                                               # node_attribute
default["horizon"]["db"]["name"] = "dash"                                                   # node_attribute

default["horizon"]["use_ssl"] = true                                                        # node_attribute
default["horizon"]["ssl"]["cert"] = "horizon.pem"                                           # node_attribute
default["horizon"]["ssl"]["key"] = "horizon.key"                                            # node_attribute

case node["platform"]
when "fedora", "centos", "redhat", "amazon", "scientific"
  default["horizon"]["ssl"]["dir"] = "/etc/pki/tls"                                         # node_attribute
  default["horizon"]["local_settings_path"] = "/etc/openstack-dashboard/local_settings"     # node_attribute
  # TODO(shep) - Fedora does not generate self signed certs by default
when "ubuntu", "debian"
  default["horizon"]["ssl"]["dir"] = "/etc/ssl"                                             # node_attribute
  default["horizon"]["local_settings_path"] = "/etc/openstack-dashboard/local_settings.py"  # node_attribute
end

default["horizon"]["dash_path"] = "/usr/share/openstack-dashboard/openstack_dashboard"      # node_attribute
default["horizon"]["wsgi_path"] = node["horizon"]["dash_path"] + "/wsgi"                    # node_attribute
