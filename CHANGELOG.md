openstack-dashboard Cookbook CHANGELOG
==============================
This file is used to list changes made in each version of the openstack-dashboard cookbook.

## 10.0.0
* Upgrading to Juno
* Upgrading berkshelf from 2.0.18 to 3.1.5
* Allow enable_filewall and enable_vpn to be configured via attributes
* Sync conf files with Juno

## 9.1
* python_packages database client attributes have been moved to the -common cookbook
* bump berkshelf to 2.0.18 to allow Supermarket support
* fix fauxhai version for suse

## 9.0.3
* Fix LOGIN_REDIRECT_URL to be configurable on rhel

## 9.0.2
* Add support for configuring OPENSTACK_KEYSTONE_BACKEND

## 9.0.1
### Bug
* Fix openstack_keystone_default_role default
* Fix the depends cookbook version issue in metadata.rb

## 9.0.0
* Upgrade to Icehouse

## 8.1.1
### Bug
* Fix the DB2 ODBC driver issue

## 8.1.0
### Blue print
* Use the library method auth_uri_transform

## 8.0.0
### New version
* Upgrade to upstream Havana release
