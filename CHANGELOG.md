openstack-dashboard Cookbook CHANGELOG
==============================
This file is used to list changes made in each version of the openstack-dashboard cookbook.

## 9.1.2
* Set default to use only TLS for SSL. OpenStack security note OSSN-0039
* Fix python-ibm-db-django package polluting common package attribute

## 9.1.1
* Updated Berksfile.lock for the UTF8 issue in common

## 9.1.1
* pinned apache2 cookbook version to be < 2.0.0

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
