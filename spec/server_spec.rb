# encoding: UTF-8
require_relative 'spec_helper'

shared_examples 'virtualhost port configurator' do |port_attribute_name, port_attribute_value|
  let(:virtualhost_directive) { "<VirtualHost \\*:#{port_attribute_value}>" }
  before do
    node.set['openstack']['dashboard'][port_attribute_name] = port_attribute_value
  end

  it "sets Listen and NameVirtualHost directives when apache's listen_ports does not include #{port_attribute_value}" do
    node.set['apache']['listen_ports'] = [port_attribute_value.to_i + 1]
    %w(Listen NameVirtualHost).each do |directive|
      expect(chef_run).to render_file(file.name).with_content(/^#{directive} \*:#{port_attribute_value}$/)
    end
  end

  it "does not set Listen and NameVirtualHost directives when apache's listen_ports include #{port_attribute_value}" do
    node.set['apache']['listen_ports'] = [port_attribute_value]
    chef_run.converge(described_recipe)
    %w(Listen NameVirtualHost).each do |directive|
      expect(chef_run).not_to render_file(file.name).with_content(/^#{directive} \*:#{port_attribute_value}$/)
    end
  end

  it 'sets the VirtualHost directive' do
    expect(chef_run).to render_file(file.name).with_content(/^#{virtualhost_directive}$/)
  end

  context 'server_hostname' do
    it 'sets the value if the server_hostname is present' do
      node.set['openstack']['dashboard']['server_hostname'] = 'server_hostname_value'
      expect(chef_run).to render_file(file.name).with_content(/^#{virtualhost_directive}\s*ServerName server_hostname_value$/)
    end

    it 'does not set the value if the server_hostname is not present' do
      node.set['openstack']['dashboard']['server_hostname'] = nil
      expect(chef_run).not_to render_file(file.name).with_content(/^#{virtualhost_directive}\s*ServerName$/)
    end
  end
end

describe 'openstack-dashboard::server' do

  describe 'ubuntu' do

    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    let(:chef_run_session_sql) do
      node.set['openstack']['dashboard']['session_backend'] = 'sql'
      runner.converge(described_recipe)
    end

    include_context 'non_redhat_stubs'
    include_context 'dashboard_stubs'

    it 'does not execute set-selinux-permissive' do
      cmd = '/sbin/setenforce Permissive'
      expect(chef_run).not_to run_execute(cmd)
    end

    it 'installs apache packages' do
      expect(chef_run).to include_recipe('apache2')
      expect(chef_run).to include_recipe('apache2::mod_wsgi')
      expect(chef_run).to include_recipe('apache2::mod_rewrite')
      expect(chef_run).to include_recipe('apache2::mod_ssl')
    end

    it 'does not execute set-selinux-enforcing' do
      cmd = '/sbin/setenforce Enforcing ; restorecon -R /etc/httpd'
      expect(chef_run).not_to run_execute(cmd)
    end

    it 'installs packages' do
      expect(chef_run).to upgrade_package('lessc')
      expect(chef_run).to upgrade_package('openstack-dashboard')
      expect(chef_run).to upgrade_package('python-mysqldb')
    end

    describe 'local_settings.py' do
      let(:file) { chef_run.template('/etc/openstack-dashboard/local_settings.py') }

      it 'has proper owner' do
        expect(file.owner).to eq('root')
        expect(file.group).to eq('root')
      end

      it 'has proper modes' do
        expect(sprintf('%o', file.mode)).to eq('644')
      end

      context 'template contents' do
        it 'has the customer banner' do
          node.set['openstack']['dashboard']['custom_template_banner'] = 'custom_template_banner_value'
          expect(chef_run).to render_file(file.name).with_content(/^custom_template_banner_value$/)
        end

        context 'debug setting' do
          context 'set to true' do
            before do
              node.set['openstack']['dashboard']['debug'] = true
            end

            it 'has a true value for the DEBUG attribute' do
              expect(chef_run).to render_file(file.name).with_content(/^DEBUG = True$/)
            end

            it 'sets the console logging level to DEBUG' do
              expect(chef_run).to render_file(file.name).with_content(/^\s*'level': 'DEBUG',$/)
            end
          end

          context 'set to false' do
            before do
              node.set['openstack']['dashboard']['debug'] = false
            end

            it 'has a false value for the DEBUG attribute' do
              expect(chef_run).to render_file(file.name).with_content(/^DEBUG = False$/)
            end

            it 'sets the console logging level to INFO' do
              expect(chef_run).to render_file(file.name).with_content(/^\s*'level': 'INFO',$/)
            end
          end
        end

        it 'has some allowed hosts set' do
          node.set['openstack']['dashboard']['allowed_hosts'] = ['dashboard.example.net']
          expect(chef_run).to render_file(file.name).with_content(/^ALLOWED_HOSTS = \["dashboard.example.net"\]$/)
        end

        context 'ssl offload' do
          let(:secure_proxy_string) { 'SECURE_PROXY_SSL_HEADER = \(\'HTTP_X_FORWARDED_PROTOCOL\', \'https\'\)' }
          it 'does not configure ssl proxy when ssl_offload is false' do
            node.set['openstack']['dashboard']['ssl_offload'] = false
            expect(chef_run).not_to render_file(file.name).with_content(/^#{secure_proxy_string}$/)
          end

          it 'configures ssl proxy when ssl_offload is set to true' do
            node.set['openstack']['dashboard']['ssl_offload'] = true
            expect(chef_run).to render_file(file.name).with_content(/^#{secure_proxy_string}$/)
          end
        end

        context 'ssl settings' do
          context 'use_ssl enabled' do
            before do
              node.set['openstack']['dashboard']['use_ssl'] = true
            end

            context 'csrf_cookie_secure setting' do
              it 'sets secure csrf cookie to true when the attribute is enabled' do
                node.set['openstack']['dashboard']['csrf_cookie_secure'] = true
                expect(chef_run).to render_file(file.name).with_content(/^CSRF_COOKIE_SECURE = True$/)
              end

              it 'sets secure csrf cookie to false when the attribute is disabled' do
                node.set['openstack']['dashboard']['csrf_cookie_secure'] = false
                expect(chef_run).to render_file(file.name).with_content(/^CSRF_COOKIE_SECURE = False$/)
              end
            end

            context 'session_cookie_secure setting' do
              it 'set secure csrf cookie to true when the sttribute is enabled' do
                node.set['openstack']['dashboard']['session_cookie_secure'] = true
                expect(chef_run).to render_file(file.name).with_content(/^SESSION_COOKIE_SECURE = True$/)
              end

              it 'set secure csrf cookie to false when the sttribute is disabled' do
                node.set['openstack']['dashboard']['session_cookie_secure'] = false
                expect(chef_run).to render_file(file.name).with_content(/^SESSION_COOKIE_SECURE = False$/)
              end
            end
          end

          it 'does not set secure csrf nor secure session cookie settings when use_ssl is disabled' do
            node.set['openstack']['dashboard']['use_ssl'] = false
            [/^CSRF_COOKIE_SECURE$/, /^SESSION_COOKIE_SECURE$/].each do |setting|
              expect(chef_run).not_to render_file(file.name).with_content(setting)
            end
          end
        end

        it 'does not have urls set' do
          [
            /^LOGIN_URL =$/,
            /^LOGOUT_URL =$/,
            /^LOGIN_REDIRECT_URL =$/
          ].each do |line|
            expect(chef_run).to_not render_file(file.name).with_content(line)
          end
        end

        it 'has a identity api verision setting' do
          node.set['openstack']['dashboard']['identity_api_version'] = 'identity_api_version_value'
          expect(chef_run).to render_file(file.name).with_content(/^\s*"identity": identity_api_version_value$/)
        end

        context 'keystone multidomain support' do
          it 'sets to true when the attribute is enabled' do
            node.set['openstack']['dashboard']['keystone_multidomain_support'] = true
            expect(chef_run).to render_file(file.name).with_content(/^OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True$/)
          end

          it 'sets to false when the attribute is disabled' do
            node.set['openstack']['dashboard']['keystone_multidomain_support'] = false
            expect(chef_run).to render_file(file.name).with_content(/^OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = False$/)
          end
        end

        it 'has a keystone default domain setting if identity api version is 3' do
          node.set['openstack']['dashboard']['identity_api_version'] = 3
          node.set['openstack']['dashboard']['keystone_default_domain'] = 'keystone_default_domain_value'
          expect(chef_run).to render_file(file.name).with_content(/^OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "keystone_default_domain_value"$/)
        end

        it 'has a console_type setting' do
          node.set['openstack']['dashboard']['console_type'] = 'console_type_value'
          expect(chef_run).to render_file(file.name).with_content(/^CONSOLE_TYPE = "console_type_value"$/)
        end

        it 'has a help_url setting' do
          node.set['openstack']['dashboard']['help_url'] = 'help_url_value'
          expect(chef_run).to render_file(file.name).with_content(/\s*'help_url': "help_url_value",$/)
        end

        context 'simple ip management' do
          it 'enables the setting when the attribute is set' do
            node.set['openstack']['dashboard']['simple_ip_management'] = true
            expect(chef_run).to render_file(file.name).with_content('HORIZON_CONFIG["simple_ip_management"] = True')
          end

          it 'disables the setting when the attribute is not set' do
            node.set['openstack']['dashboard']['simple_ip_management'] = false
            expect(chef_run).to render_file(file.name).with_content('HORIZON_CONFIG["simple_ip_management"] = False')
          end
        end

        it 'has default password_autocomplete setting' do
          node.set['openstack']['dashboard']['password_autocomplete'] = 'password_autocomplete_value'
          expect(chef_run).to render_file(file.name).with_content(/^HORIZON_CONFIG\["password_autocomplete"\] = "password_autocomplete_value"$/)
        end

        it 'has configurable secret_key_path setting' do
          node.set['openstack']['dashboard']['secret_key_path'] = 'secret_key_path_value'
          expect(chef_run).to render_file(file.name).with_content(/^SECRET_KEY = secret_key.generate_or_read_from_file\(os.path.realpath\('secret_key_path_value'\)\)$/)
        end

        context 'session backend' do
          it 'sets the session engine to file when it is the session backend' do
            node.set['openstack']['dashboard']['session_backend'] = 'file'
            expect(chef_run).to render_file(file.name).with_content(/^SESSION_ENGINE = 'django.contrib.sessions.backends.file'$/)
          end

          context 'memcached as session backend' do
            let(:memcached_session_engine_setting) { /^SESSION_ENGINE = 'django.contrib.sessions.backends.cache'$/ }
            context 'with memcache servers' do
              it 'sets the session engine attribute' do
                expect(chef_run).to render_file(file.name).with_content(memcached_session_engine_setting)
              end

              it 'sets the location of the caches to the memcached servers addresses' do
                expect(chef_run).to render_file(file.name).with_content(/^\s*'LOCATION': \[\s*'hostA:port',\s*'hostB:port',\s*\]$/)
              end
            end

            context 'without memcache servers' do
              [nil, []].each do |empty_value|
                it "does not configure caching when backend == memcache and #{empty_value} provided as memcache servers" do
                  Chef::Recipe.any_instance.stub(:memcached_servers)
                    .and_return(empty_value)

                  expect(chef_run).not_to render_file(file.name)
                    .with_content(memcached_session_engine_setting)
                end
              end
            end
          end

          it 'sets the session engine to db when sql is the session backend' do
            node.set['openstack']['dashboard']['session_backend'] = 'sql'
            expect(chef_run).to render_file(file.name).with_content(/^SESSION_ENGINE = 'django.contrib.sessions.backends.db'$/)
          end
        end

        it 'has a keystone url' do
          expect(chef_run).to render_file(file.name).with_content(%r(OPENSTACK_KEYSTONE_URL = "http://127.0.0.1:5000/v2.0"))
        end

        it 'has a keystone admin url' do
          expect(chef_run).to render_file(file.name).with_content(%r(OPENSTACK_KEYSTONE_ADMIN_URL = "http://127.0.0.1:35357/v2.0"))
        end

        it 'has a keystone default role' do
          node.set['openstack']['dashboard']['keystone_default_role'] = 'keystone_default_role_value'
          expect(chef_run).to render_file(file.name).with_content(/^OPENSTACK_KEYSTONE_DEFAULT_ROLE = "keystone_default_role_value"$/)
        end

        context 'keystone_backend settings' do
          %w(native ldap).each do |keystone_backend_name|
            it "sets the backend name to #{keystone_backend_name}" do
              node.set['openstack']['dashboard']['keystone_backend']['name'] = keystone_backend_name
              expect(chef_run).to render_file(file.name).with_content(/^\s*'name': '#{keystone_backend_name}',$/)
            end
          end

          %w(can_edit_user can_edit_group can_edit_project can_edit_domain can_edit_role).each do |keystone_setting|
            it "enables the #{keystone_setting} keystone backend setting when the attribute is True" do
              node.set['openstack']['dashboard']['keystone_backend'][keystone_setting] = true
              expect(chef_run).to render_file(file.name).with_content(/^\s*\'#{keystone_setting}\': True,$/)
            end

            it "disables the #{keystone_setting} keystone backend setting when the attribute is False" do
              node.set['openstack']['dashboard']['keystone_backend'][keystone_setting] = false
              expect(chef_run).to render_file(file.name).with_content(/^\s*\'#{keystone_setting}\': False,$/)
            end
          end
        end

        context 'neutron settings' do
          %w(enable_lb enable_quotas).each do |neutron_setting|
            it "enables the #{neutron_setting} setting when the attributes is True" do
              node.set['openstack']['dashboard']['neutron'][neutron_setting] = true
              expect(chef_run).to render_file(file.name).with_content(/^\s*\'#{neutron_setting}\': True,$/)
            end

            it "disables the #{neutron_setting} setting when the attributes is False" do
              node.set['openstack']['dashboard']['neutron'][neutron_setting] = false
              expect(chef_run).to render_file(file.name).with_content(/^\s*\'#{neutron_setting}\': False,$/)
            end
          end
        end

        %w(horizon openstack_dashboard novaclient cinderclient keystoneclient
           glanceclient neutronclient heatclient ceilometerclient troveclient
           swiftclient openstack_auth nose.plugins.manager django).each do |component|
          it "sets the logger level for #{component}" do
            node.set['openstack']['dashboard']['log_level'][component] = "#{component}_log_level_value"
            expect(chef_run).to render_file(file.name).with_content(
              /^\s*'#{component}': {\s*'handlers': \['console'\],\s*'level': '#{component}_log_level_value',$/)
          end
        end

        { 'mysql' => 'django.db.backends.mysql',
          'sqlite' => 'django.db.backends.sqlite3',
          'postgresql' => 'django.db.backends.postgresql_psycopg2',
          'db2' => 'ibm_db_django' }.each do |service_type, backend|
          context "#{service_type} database settings" do
            before do
              Chef::Recipe.any_instance.stub(:db)
                .with('dashboard')
                .and_return('service_type' => service_type,
                            'db_name' => "#{service_type}_db",
                            'host' => "#{service_type}_host")
              node.set['openstack']['db']['dashboard']['username'] = "#{service_type}_user"
              node.set['openstack']['dashboard']['platform'] = { "#{service_type}_python_packages" => %w(pkg1 pkg2) }
            end

            [/^\s*'ENGINE': '#{backend}',$/,
             /^\s*'NAME': '#{service_type}_db',$/].each do |cfg|
              it "configures the #{service_type} backend with #{cfg}" do
                expect(chef_run).to render_file(file.name).with_content(cfg)
              end
            end

            [/^\s*'USER': '#{service_type}_user',$/,
             /^\s*'PASSWORD': 'test-passes',$/,
             /^\s*'HOST': '#{service_type}_host',$/].each do |cfg|
              unless service_type == 'sqlite'
                it "configures the #{service_type} backend with #{cfg}" do
                  expect(chef_run).to render_file(file.name).with_content(cfg)
                end
              end
            end
          end
        end

        context 'plugins' do
          let(:mod_regex) { /^mod = sys.modules\['openstack_dashboard.settings'\]$/ }
          context 'plugins enabled' do
            let(:plugins) { %w(testPlugin1 testPlugin2) }
            before do
              node.set['openstack']['dashboard']['plugins'] = plugins
            end

            it 'shows the mod setting' do
              expect(chef_run).to render_file(file.name).with_content(mod_regex)
            end

            it 'shows enabled plugins as installed apps' do
              plugins.each do |plugin|
                expect(chef_run).to render_file(file.name).with_content(/^mod\.INSTALLED_APPS \+= \('#{plugin}', \)$/)
              end
            end
          end

          it 'does not show the mod setting if there are no plugins' do
            node.set['openstack']['dashboard']['plugins'] = nil
            expect(chef_run).not_to render_file(file.name).with_content(mod_regex)
          end
        end
      end

      it 'notifies apache2 restart' do
        expect(file).to notify('service[apache2]').to(:restart)
      end

    end

    describe 'openstack-dashboard syncdb' do
      sync_db_cmd = 'python manage.py syncdb --noinput'
      sync_db_environment = {
        'PYTHONPATH' => '/etc/openstack-dashboard:' \
                        '/usr/share/openstack-dashboard:' \
                        '$PYTHONPATH'
      }

      it 'does not execute when session_backend is not sql' do
        expect(chef_run).not_to run_execute(sync_db_cmd).with(
          cwd: node['openstack']['dashboard']['django_path'],
          environment: sync_db_environment
          )
      end

      it 'executes when session_backend is sql' do
        expect(chef_run_session_sql).to run_execute(sync_db_cmd).with(
          cwd: node['openstack']['dashboard']['django_path'],
          environment: sync_db_environment
          )
      end

      it 'does not execute when the migrate attribute is set to false' do
        node.set['openstack']['db']['dashboard']['migrate'] = false
        expect(chef_run_session_sql).not_to run_execute(sync_db_cmd).with(
          cwd: node['openstack']['dashboard']['django_path'],
          environment: sync_db_environment
          )
      end

      it 'executes when database backend is sqlite' do
        node.set['openstack']['db']['dashboard']['service_type'] = 'sqlite'
        expect(chef_run_session_sql).to run_execute(sync_db_cmd).with(
          cwd: node['openstack']['dashboard']['django_path'],
          environment: sync_db_environment
          )
      end
    end

    describe 'certs' do
      let(:crt) { chef_run.cookbook_file('/etc/ssl/certs/horizon.pem') }
      let(:key) { chef_run.cookbook_file('/etc/ssl/private/horizon.key') }
      let(:remote_key) { chef_run.remote_file('/etc/ssl/private/horizon.key') }

      it 'has proper owner' do
        expect(crt.owner).to eq('root')
        expect(crt.group).to eq('root')
        expect(key.owner).to eq('root')
        expect(key.group).to eq('ssl-cert')
      end

      it 'has proper modes' do
        expect(sprintf('%o', crt.mode)).to eq('644')
        expect(sprintf('%o', key.mode)).to eq('640')
      end

      it 'notifies restore-selinux-context' do
        expect(crt).to notify('execute[restore-selinux-context]').to(:run)
        expect(key).to notify('execute[restore-selinux-context]').to(:run)
      end

      it 'does not download certs if not needed' do
        expect(chef_run).not_to create_remote_file('/etc/ssl/certs/horizon.pem')
        expect(chef_run).not_to create_remote_file('/etc/ssl/private/horizon.key')
      end

      it 'downloads certs if needed and restarts apache' do
        node.set['openstack']['dashboard']['ssl']['cert_url'] = 'http://server/mycert.pem'
        node.set['openstack']['dashboard']['ssl']['key_url'] = 'http://server/mykey.key'
        expect(chef_run).to create_remote_file('/etc/ssl/certs/horizon.pem')
        expect(chef_run).to create_remote_file('/etc/ssl/private/horizon.key')
        expect(remote_key).to notify('service[apache2]').to(:restart)
      end
    end

    it 'creates .blackhole dir with proper owner' do
      dir = '/usr/share/openstack-dashboard/openstack_dashboard/.blackhole'

      expect(chef_run.directory(dir).owner).to eq('root')
    end

    describe 'openstack-dashboard virtual host' do
      let(:file) { chef_run.template('/etc/apache2/sites-available/openstack-dashboard') }

      it 'has proper owner' do
        expect(file.owner).to eq('root')
        expect(file.group).to eq('root')
      end

      it 'has proper modes' do
        expect(sprintf('%o', file.mode)).to eq('644')
      end

      context 'template content' do
        let(:rewrite_ssl_directive) { /^\s*RewriteEngine On\s*RewriteCond \%\{HTTPS\} off$/ }
        let(:default_rewrite_rule) { %r(^\s*RewriteRule \^\(\.\*\)\$ https\://%\{HTTP_HOST\}%\{REQUEST_URI\} \[L,R\]$) }

        it 'has the default banner' do
          node.set['openstack']['dashboard']['custom_template_banner'] = 'custom_template_banner_value'
          expect(chef_run).to render_file(file.name).with_content(/^custom_template_banner_value$/)
        end

        it_should_behave_like 'virtualhost port configurator', 'http_port', 8080

        context 'with use_ssl enabled' do
          before do
            node.set['openstack']['dashboard']['use_ssl'] = true
          end

          it_should_behave_like 'virtualhost port configurator', 'https_port', 4433

          it 'shows rewrite ssl directive' do
            expect(chef_run).to render_file(file.name).with_content(rewrite_ssl_directive)
          end

          context 'rewrite rule' do
            it 'shows the default rewrite rule when http_port is 80 and https_port is 443' do
              node.set['openstack']['dashboard']['http_port'] = 80
              node.set['openstack']['dashboard']['https_port'] = 443
              expect(chef_run).to render_file(file.name).with_content(default_rewrite_rule)
            end

            it 'shows the parameterized rewrite rule when http_port is different from 80' do
              https_port_value = 443
              node.set['openstack']['dashboard']['http_port'] = 81
              node.set['openstack']['dashboard']['https_port'] = https_port_value
              expect(chef_run).to render_file(file.name)
                .with_content(%r(^\s*RewriteRule \^\(\.\*\)\$ https://%\{SERVER_NAME\}:#{https_port_value}%\{REQUEST_URI\} \[L,R\]$))
            end

            it 'shows the parameterized rewrite rule when https_port is different from 443' do
              https_port_value = 444
              node.set['openstack']['dashboard']['http_port'] = 80
              node.set['openstack']['dashboard']['https_port'] = https_port_value
              expect(chef_run).to render_file(file.name)
                .with_content(%r(^\s*RewriteRule \^\(\.\*\)\$ https://%\{SERVER_NAME\}:#{https_port_value}%\{REQUEST_URI\} \[L,R\]$))
            end
          end

          it 'shows ssl certificate related directives' do
            node.set['openstack']['dashboard']['ssl']['dir'] = 'ssl_dir_value'
            node.set['openstack']['dashboard']['ssl']['cert'] = 'ssl_cert_value'
            node.set['openstack']['dashboard']['ssl']['key'] = 'ssl_key_value'

            [/^\s*SSLEngine on$/,
             %r(^\s*SSLCertificateFile ssl_dir_value/certs/ssl_cert_value$),
             %r(^\s*SSLCertificateKeyFile ssl_dir_value/private/ssl_key_value$)].each do |ssl_certificate_directive|
              expect(chef_run).to render_file(file.name).with_content(ssl_certificate_directive)
            end
          end
        end

        context 'with use_ssl disabled' do
          before do
            node.set['openstack']['dashboard']['use_ssl'] = false
          end

          it 'does not show rewrite ssl directive' do
            expect(chef_run).not_to render_file(file.name).with_content(rewrite_ssl_directive)
          end

          it 'does not show the default rewrite rule' do
            node.set['openstack']['dashboard']['http_port'] = 80
            node.set['openstack']['dashboard']['https_port'] = 443
            expect(chef_run).not_to render_file(file.name).with_content(default_rewrite_rule)
          end

          it 'does not show ssl certificate related directives' do
            [/^\s*SSLEngine on$/,
             /^\s*SSLCertificateFile/,
             /^\s*SSLCertificateKeyFile/].each do |ssl_certificate_directive|
              expect(chef_run).not_to render_file(file.name).with_content(ssl_certificate_directive)
            end
          end
        end

        it 'shows the ServerAdmin' do
          node.set['apache']['contact'] = 'apache_contact_value'
          expect(chef_run).to render_file(file.name).with_content(/\s*ServerAdmin apache_contact_value$/)
        end

        it 'sets the WSGI script alias defaults' do
          expect(chef_run).to render_file(file.name).with_content(%r(^\s*WSGIScriptAlias / /usr/share/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi$))
        end

        it 'sets the WSGI script alias' do
          node.set['openstack']['dashboard']['wsgi_path'] = 'wsgi_path_value'
          node.set['openstack']['dashboard']['webroot'] = 'root'
          expect(chef_run).to render_file(file.name).with_content(/^\s*WSGIScriptAlias root wsgi_path_value$/)
        end

        it 'sets the WSGI daemon process' do
          node.set['openstack']['dashboard']['horizon_user'] = 'horizon_user_value'
          node.set['openstack']['dashboard']['horizon_group'] = 'horizon_group_value'
          node.set['openstack']['dashboard']['dash_path'] = 'dash_path_value'
          expect(chef_run).to render_file(file.name).with_content(
           /^\s*WSGIDaemonProcess dashboard user=horizon_user_value group=horizon_group_value processes=3 threads=10 python-path=dash_path_value$/)
        end

        it 'has the default DocRoot' do
          node.set['openstack']['dashboard']['dash_path'] = 'dash_path_value'
          expect(chef_run).to render_file(file.name)
            .with_content(%r(\s*DocumentRoot dash_path_value/.blackhole/$))
        end

        it 'sets the right Alias path for /static' do
          node.set['openstack']['dashboard']['static_path'] = 'static_path_value'
          expect(chef_run).to render_file(file.name).with_content(/^\s+Alias \/static static_path_value$/)
        end

        %w(dash_path static_path).each do |dir_attribute|
          it "sets the #{dir_attribute} directory directive" do
            node.set['openstack']['dashboard'][dir_attribute] = "#{dir_attribute}_value"
            expect(chef_run).to render_file(file.name).with_content(/^\s*<Directory #{dir_attribute}_value>$/)
          end
        end

        context 'log directives' do
          before do
            node.set['apache']['log_dir'] = 'log_dir_value'
          end

          it 'sets de ErrorLog directive' do
            node.set['openstack']['dashboard']['error_log'] = 'error_log_value'
            expect(chef_run).to render_file(file.name).with_content(/^\s*ErrorLog log_dir_value\/error_log_value$/)
          end

          it 'sets de CustomLog directive' do
            node.set['openstack']['dashboard']['access_log'] = 'access_log_value'
            expect(chef_run).to render_file(file.name).with_content(/^\s*CustomLog log_dir_value\/access_log_value combined$/)
          end
        end

        it 'sets wsgi socket prefix if wsgi_socket_prefix attribute is preset' do
          node.set['openstack']['dashboard']['wsgi_socket_prefix'] = '/var/run/wsgi'
          expect(chef_run).to render_file(file.name).with_content(%r(^WSGISocketPrefix /var/run/wsgi$))
        end

        it 'omits wsgi socket prefix if wsgi_socket_prefix attribute is not preset' do
          node.set['openstack']['dashboard']['wsgi_socket_prefix'] = nil
          expect(chef_run).not_to render_file(file.name).with_content(/^WSGISocketPrefix $/)
        end
      end

      it 'notifies restore-selinux-context' do
        expect(file).to notify('execute[restore-selinux-context]').to(:run)
      end
    end

    describe 'secret_key_path file' do
      secret_key_path = '/var/lib/openstack-dashboard/secret_key'
      let(:file) { chef_run.file(secret_key_path) }

      it 'has correct ownership' do
        expect(file.owner).to eq('horizon')
        expect(file.group).to eq('horizon')
      end

      it 'has correct mode' do
        expect(file.mode).to eq(00600)
      end

      it 'does not notify apache2 restart' do
        expect(file).not_to notify('service[apache2]').to(:restart)
      end

      it 'has configurable path and ownership settings' do
        node.set['openstack']['dashboard']['secret_key_path'] = 'somerandompath'
        node.set['openstack']['dashboard']['horizon_user'] = 'somerandomuser'
        node.set['openstack']['dashboard']['horizon_group'] = 'somerandomgroup'
        file = chef_run.file('somerandompath')
        expect(file.owner).to eq('somerandomuser')
        expect(file.group).to eq('somerandomgroup')
      end

      describe 'secret_key_content set' do
        before do
          node.set['openstack']['dashboard']['secret_key_content'] = 'somerandomcontent'
        end

        it 'has configurable secret_key_content setting' do
          expect(chef_run).to render_file(file.name).with_content('somerandomcontent')
        end

        it 'notifies apache2 restart when secret_key_content set' do
          expect(file).to notify('service[apache2]').to(:restart)
        end
      end
    end

    it 'does not delete openstack-dashboard.conf' do
      file = '/etc/httpd/conf.d/openstack-dashboard.conf'

      expect(chef_run).not_to delete_file(file)
    end

    it 'removes openstack-dashboard-ubuntu-theme package' do
      expect(chef_run).to purge_package('openstack-dashboard-ubuntu-theme')
    end

    it 'calls apache_site to disable 000-default virtualhost' do

      resource = chef_run.find_resource('execute',
                                        'a2dissite 000-default').to_hash
      expect(resource).to include(
        action: 'run',
        params: {
          enable: false,
          name: '000-default'
        }
      )
    end

    it 'calls apache_site to enable openstack-dashboard virtualhost' do

      resource = chef_run.find_resource('execute',
                                        'a2ensite openstack-dashboard').to_hash
      expect(resource).to include(
        action: 'run',
        params: {
          enable: true,
          notifies: [:reload, 'service[apache2]', :immediately],
          name: 'openstack-dashboard'
        }
      )
    end

    it 'notifies apache2 restart' do
      pending 'TODO: how to test when tied to an LWRP'
    end

    it 'does not execute restore-selinux-context' do
      cmd = 'restorecon -Rv /etc/httpd /etc/pki; chcon -R -t httpd_sys_content_t /usr/share/openstack-dashboard || :'

      expect(chef_run).not_to run_execute(cmd)
    end

    it 'has group write mode on path' do
      path = chef_run.directory("#{chef_run.node['openstack']['dashboard']['dash_path']}/local")
      expect(path.mode).to eq(02770)
      expect(path.group).to eq(chef_run.node['openstack']['dashboard']['horizon_group'])
    end
  end
end
