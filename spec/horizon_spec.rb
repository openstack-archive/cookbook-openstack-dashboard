require_relative 'spec_helper'

describe 'openstack-dashboard::horizon' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      node.override['openstack']['dashboard']['custom_template_banner'] = 'custom_template_banner_value'
      node.override['openstack']['dashboard']['allowed_hosts'] = ['dashboard.example.net']
      node.override['openstack']['dashboard']['ssl_cacert'] = '/path_to_cacert.pem'
      node.override['openstack']['dashboard']['identity_api_version'] = 'identity_api_version_value'
      node.override['openstack']['dashboard']['volume_api_version'] = 'volume_api_version_value'
      node.override['openstack']['dashboard']['keystone_default_domain'] = 'keystone_default_domain_value'
      node.override['openstack']['dashboard']['console_type'] = 'console_type_value'
      node.override['openstack']['dashboard']['help_url'] = 'help_url_value'
      node.override['openstack']['dashboard']['password_autocomplete'] = 'password_autocomplete_value'
      node.override['openstack']['dashboard']['secret_key_path'] = 'secret_key_path_value'
      node.override['openstack']['dashboard']['use_ssl'] = true
      node.override['openstack']['dashboard']['keystone_backend']['name'] = 'native'
      node.override['openstack']['dashboard']['misc_local_settings'] = {
        'CUSTOM_CONFIG_A' => {
          'variable1' => 'value1',
          'variable2' => 'value2',
        },
        'CUSTOM_CONFIG_B' => {
          'variable1' => 'value1',
          'variable2' => 'value2',
        },
      }
      runner.converge('openstack-identity::server-apache', described_recipe)
    end

    cached(:chef_run2) do
      node.override['openstack']['dashboard']['debug'] = true
      node.override['openstack']['dashboard']['ssl_no_verify'] = 'False'
      node.override['openstack']['dashboard']['use_ssl'] = false
      node.override['openstack']['dashboard']['ssl_offload'] = false
      node.override['openstack']['dashboard']['file_upload_temp_dir'] = '/foobar'
      node.override['openstack']['dashboard']['keystone_multidomain_support'] = true
      node.override['openstack']['dashboard']['simple_ip_management'] = true
      node.override['openstack']['dashboard']['session_backend'] = 'file'
      node.override['openstack']['dashboard']['keystone_default_role'] = 'keystone_default_role_value'
      node.override['openstack']['dashboard']['keystone_backend']['name'] = 'ldap'
      node.override['openstack']['dashboard']['neutron']['enable_quotas'] = false
      node.override['openstack']['dashboard']['neutron']['enable_lb'] = true
      node.override['openstack']['dashboard']['plugins'] = %w(testPlugin1 testPlugin2)
      node.override['openstack']['db']['dashboard']['migrate'] = false
      runner.converge('openstack-identity::server-apache', described_recipe)
    end

    cached(:chef_run_sql) do
      node.override['openstack']['dashboard']['session_backend'] = 'sql'
      runner.converge('openstack-identity::server-apache', described_recipe)
    end

    include_context 'non_redhat_stubs'
    include_context 'dashboard_stubs'

    it 'installs packages' do
      expect(chef_run).to upgrade_package %w(node-less libapache2-mod-wsgi-py3 python3-django-horizon openstack-dashboard python3-mysqldb)
    end

    describe 'local_settings.py' do
      let(:file) { chef_run.template('/etc/openstack-dashboard/local_settings.py') }

      it 'creates local_settings' do
        expect(chef_run).to create_template(file.name).with(
          sensitive: true,
          user: 'root',
          group: 'horizon',
          mode: '640'
        )
      end

      it 'notifies web service to restart delayed' do
        expect(file).to notify('service[apache2]').to(:restart).delayed
      end

      describe 'template contents' do
        it 'has the customer banner' do
          expect(chef_run).to render_file(file.name).with_content(/^custom_template_banner_value$/)
        end

        it 'sets misc settings properly' do
          [
            ['CUSTOM_CONFIG_A = {',
             '  \'variable1\': \'value1\',',
             '  \'variable2\': \'value2\',',
             '}',
            ],
            ['CUSTOM_CONFIG_B = {',
             '  \'variable1\': \'value1\',',
             '  \'variable2\': \'value2\',',
             '}',
            ],
          ].each do |content|
            expect(chef_run).to render_file(file.name).with_content(build_section(content))
          end
        end

        describe 'debug setting' do
          describe 'set to true' do
            it 'has a true value for the DEBUG attribute' do
              expect(chef_run2).to render_file(file.name).with_content(/^DEBUG = True$/)
            end

            it 'sets the console logging level to DEBUG' do
              expect(chef_run2).to render_file(file.name).with_content(/^\s*'level': 'DEBUG',$/)
            end
          end

          describe 'set to false' do
            it 'has a false value for the DEBUG attribute' do
              expect(chef_run).to render_file(file.name).with_content(/^DEBUG = False$/)
            end

            it 'sets the console logging level to INFO' do
              expect(chef_run).to render_file(file.name).with_content(/^\s*'level': 'INFO',$/)
            end
          end
        end

        describe 'config ssl_no_verify' do
          describe 'set to the default value' do
            it 'has a True value for the OPENSTACK_SSL_NO_VERIFY attribute' do
              expect(chef_run).to render_file(file.name).with_content(/^OPENSTACK_SSL_NO_VERIFY = True$/)
            end
          end

          context 'set to False' do
            cached(:chef_run) do
              node.override['openstack']['dashboard']['use_ssl'] = true
              node.override['openstack']['dashboard']['ssl_no_verify'] = 'False'
              runner.converge('openstack-identity::server-apache', described_recipe)
            end
            it 'has a False value for the OPENSTACK_SSL_NO_VERIFY attribute' do
              expect(chef_run).to render_file(file.name).with_content(/^OPENSTACK_SSL_NO_VERIFY = False$/)
            end
          end

          describe 'not set when ssl disabled' do
            it 'has a True value for the OPENSTACK_SSL_NO_VERIFY attribute' do
              expect(chef_run2).not_to render_file(file.name).with_content(/^OPENSTACK_SSL_NO_VERIFY = True$/)
            end
          end
        end

        it 'config ssl_cacert' do
          expect(chef_run).to render_file(file.name).with_content(%r{^OPENSTACK_SSL_CACERT = '/path_to_cacert.pem'$})
        end

        it 'does not config ssl_cacert when ssl disabled' do
          expect(chef_run2).not_to render_file(file.name)
            .with_content(%r{^OPENSTACK_SSL_CACERT = '/path_to_cacert.pem'$})
        end

        it 'has some allowed hosts set' do
          expect(chef_run).to render_file(file.name).with_content(/^ALLOWED_HOSTS = \["dashboard.example.net"\]$/)
        end

        describe 'ssl offload' do
          let(:secure_proxy_string) { 'SECURE_PROXY_SSL_HEADER = \(\'HTTP_X_FORWARDED_PROTOCOL\', \'https\'\)' }

          it 'configures ssl proxy when ssl_offload is set to true' do
            expect(chef_run).to render_file(file.name).with_content(/^#{secure_proxy_string}$/)
          end

          it 'does not configure ssl proxy when ssl_offload is false' do
            expect(chef_run2).not_to render_file(file.name).with_content(/^#{secure_proxy_string}$/)
          end
        end

        describe 'temp dir override' do
          describe 'temp dir is nil' do
            it 'does not override temp dir when it is nil' do
              expect(chef_run).not_to render_file(file.name).with_content(/^FILE_UPLOAD_TEMP_DIR =/)
            end
            it 'does override temp dir when it is not nil' do
              expect(chef_run2).to render_file(file.name).with_content(%r{^FILE_UPLOAD_TEMP_DIR = "/foobar"$})
            end
          end
        end

        describe 'ssl settings' do
          describe 'use_ssl enabled' do
            it 'sets secure csrf cookie to true when the attribute is enabled' do
              expect(chef_run).to render_file(file.name).with_content(/^CSRF_COOKIE_SECURE = True$/)
            end

            it 'set secure csrf cookie to true when the attribute is enabled' do
              expect(chef_run).to render_file(file.name).with_content(/^SESSION_COOKIE_SECURE = True$/)
            end

            context 'sets secure csrf & session cookie to false when the attribute is disabled' do
              cached(:chef_run) do
                node.override['openstack']['dashboard']['csrf_cookie_secure'] = false
                node.override['openstack']['dashboard']['session_cookie_secure'] = false
                runner.converge('openstack-identity::server-apache', described_recipe)
              end
              it do
                expect(chef_run).to render_file(file.name).with_content(/^CSRF_COOKIE_SECURE = False$/)
              end
              it do
                expect(chef_run).to render_file(file.name).with_content(/^SESSION_COOKIE_SECURE = False$/)
              end
            end
          end

          it 'does not set secure csrf nor secure session cookie settings when use_ssl is disabled' do
            [
              /^CSRF_COOKIE_SECURE$/,
              /^SESSION_COOKIE_SECURE$/,
            ].each do |setting|
              expect(chef_run2).not_to render_file(file.name).with_content(setting)
            end
          end
        end

        it 'does have webroot set' do
          expect(chef_run).to render_file(file.name).with_content(%r{^WEBROOT = '/'$})
        end

        it 'does not have urls set' do
          [
            /^LOGIN_URL =$/,
            /^LOGOUT_URL =$/,
            /^LOGIN_REDIRECT_URL =$/,
          ].each do |line|
            expect(chef_run).to_not render_file(file.name).with_content(line)
          end
        end

        it 'has policy file path set' do
          expect(chef_run).to render_file(file.name)
            .with_content(%r{^POLICY_FILES_PATH = '/usr/share/openstack-dashboard/openstack_dashboard/conf'$})
        end

        describe 'identity and volume api version setting' do
          it 'is configurable directly' do
            [
              /^\s*"identity": identity_api_version_value,$/,
              /^\s*"volume": volume_api_version_value$/,
            ].each do |line|
              expect(chef_run).to render_file(file.name).with_content(line)
            end
          end
        end

        describe 'keystone multidomain support' do
          it 'sets to true when the attribute is enabled' do
            expect(chef_run2).to render_file(file.name).with_content(/^OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True$/)
          end
          it 'sets to false when the attribute is disabled' do
            expect(chef_run).to render_file(file.name)
              .with_content(/^OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = False$/)
          end
        end

        it 'has a keystone default domain setting' do
          expect(chef_run).to render_file(file.name)
            .with_content(/^OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "keystone_default_domain_value"$/)
        end

        it 'has a console_type setting' do
          expect(chef_run).to render_file(file.name).with_content(/^CONSOLE_TYPE = "console_type_value"$/)
        end

        it 'has a help_url setting' do
          expect(chef_run).to render_file(file.name).with_content(/\s*'help_url': "help_url_value",$/)
        end

        it 'allows HORIZON_CONFIG to use INSTALLED_APPS to determine default dashboards' do
          expect(chef_run).not_to render_file(file.name).with_content(/\s*'dashboards':/)
          expect(chef_run).not_to render_file(file.name).with_content(/\s*'default_dashboard':/)
        end

        describe 'simple ip management' do
          it 'disables the setting when the attribute is not set' do
            expect(chef_run).to render_file(file.name).with_content('HORIZON_CONFIG["simple_ip_management"] = False')
          end
          it 'enables the setting when the attribute is set' do
            expect(chef_run2).to render_file(file.name).with_content('HORIZON_CONFIG["simple_ip_management"] = True')
          end
        end

        it 'has default password_autocomplete setting' do
          expect(chef_run).to render_file(file.name)
            .with_content(/^HORIZON_CONFIG\["password_autocomplete"\] = "password_autocomplete_value"$/)
        end

        it 'has configurable secret_key_path setting' do
          expect(chef_run).to render_file(file.name)
            .with_content(
              /^SECRET_KEY = secret_key.generate_or_read_from_file\(os.path.realpath\('secret_key_path_value'\)\)$/
            )
        end

        describe 'session backend' do
          describe 'file as session backend' do
            it 'sets the session engine to file when it is the session backend' do
              expect(chef_run2).to render_file(file.name)
                .with_content(/^SESSION_ENGINE = 'django.contrib.sessions.backends.file'$/)
            end
          end

          describe 'memcached as session backend' do
            let(:memcached_session_engine_setting) { /^SESSION_ENGINE = 'django.contrib.sessions.backends.cache'$/ }
            describe 'with memcache servers' do
              it 'sets the session engine attribute' do
                expect(chef_run).to render_file(file.name).with_content(memcached_session_engine_setting)
              end

              it 'sets the location of the caches to the memcached servers addresses' do
                expect(chef_run).to render_file(file.name)
                  .with_content(/^\s*'LOCATION': \[\s*'hostA:port',\s*'hostB:port',\s*\]$/)
              end
            end

            context 'without memcache servers' do
              cached(:chef_run) do
                allow_any_instance_of(Chef::Recipe).to receive(:memcached_servers).and_return([])
                runner.converge('openstack-identity::server-apache', described_recipe)
              end
              it 'does not configure caching when backend == memcache and memcached_servers == []' do
                expect(chef_run).to_not render_file(file.name)
                  .with_content(/^\s*'LOCATION': \[\s*'hostA:port',\s*'hostB:port',\s*\]$/)
              end
            end
          end

          it 'sets the session engine to db when sql is the session backend' do
            expect(chef_run_sql).to render_file(file.name)
              .with_content(/^SESSION_ENGINE = 'django.contrib.sessions.backends.db'$/)
          end
        end

        it 'has a keystone url' do
          expect(chef_run).to render_file(file.name)
            .with_content(%r{OPENSTACK_KEYSTONE_URL = "http://127.0.0.1:5000/v3"})
        end

        it 'has a keystone default role' do
          expect(chef_run2).to render_file(file.name)
            .with_content(/^OPENSTACK_KEYSTONE_DEFAULT_ROLE = "keystone_default_role_value"$/)
        end

        it 'sets the backend name to native' do
          expect(chef_run).to render_file(file.name).with_content(/^\s*'name': 'native',$/)
        end

        it 'sets the backend name to ldap' do
          expect(chef_run2).to render_file(file.name).with_content(/^\s*'name': 'ldap',$/)
        end

        keystone_settings = %w(can_edit_user can_edit_group can_edit_project can_edit_domain can_edit_role)
        context 'enables the keystone backend settings when the attribute is True' do
          cached(:chef_run) do
            keystone_settings.each do |keystone_setting|
              node.override['openstack']['dashboard']['keystone_backend'][keystone_setting] = true
            end
            runner.converge('openstack-identity::server-apache', described_recipe)
          end
          keystone_settings.each do |keystone_setting|
            it do
              expect(chef_run).to render_file(file.name).with_content(/^\s*\'#{keystone_setting}\': True,$/)
            end
          end
        end

        context 'disables the keystone backend settings when the attribute is False' do
          cached(:chef_run) do
            keystone_settings.each do |keystone_setting|
              node.override['openstack']['dashboard']['keystone_backend'][keystone_setting] = false
            end
            runner.converge('openstack-identity::server-apache', described_recipe)
          end
          keystone_settings.each do |keystone_setting|
            it do
              expect(chef_run).to render_file(file.name).with_content(/^\s*\'#{keystone_setting}\': False,$/)
            end
          end
        end

        describe 'neutron settings' do
          it 'enables the enable_quotas setting when the attributes is True' do
            expect(chef_run).to render_file(file.name).with_content(/^\s*'enable_quotas': True,$/)
          end

          it 'disables the enable_quotas setting when the attributes is False' do
            expect(chef_run2).to render_file(file.name).with_content(/^\s*'enable_quotas': False,$/)
          end

          describe 'lbaas setting' do
            it 'enables the enable_lb setting when the attribute is true' do
              expect(chef_run2).to render_file(file.name).with_content(/^\s*'enable_lb': True,$/)
            end
            it 'disables the enable_lb setting when the attribute is false' do
              expect(chef_run).to render_file(file.name).with_content(/^\s*'enable_lb': False,$/)
            end
          end
        end

        context 'sets the logger level for components' do
          components = %w(
            ceilometerclient
            cinderclient
            django
            glanceclient
            heatclient
            horizon
            keystoneclient
            neutronclient
            nose.plugins.manager
            novaclient
            openstack_auth
            openstack_dashboard
            swiftclient
            troveclient
          )
          cached(:chef_run) do
            components.each do |component|
              node.override['openstack']['dashboard']['log_level'][component] = "#{component}_log_level_value"
            end
            runner.converge('openstack-identity::server-apache', described_recipe)
          end
          components.each do |component|
            it do
              expect(chef_run).to render_file(file.name).with_content(
                /^\s*'#{component}': {\s*'handlers': \['console'\],\s*'level': '#{component}_log_level_value',$/
              )
            end
          end
        end

        {
          'mysql' => 'django.db.backends.mysql',
          'sqlite' => 'django.db.backends.sqlite3',
        }.each do |service_type, backend|
          context "#{service_type} database settings" do
            cached(:chef_run) do
              node.override['openstack']['db']['dashboard']['username'] = "#{service_type}_user"
              node.override['openstack']['db']['python_packages'][service_type] = %w(pkg1 pkg2)
              runner.converge('openstack-identity::server-apache', described_recipe)
            end
            before do
              allow_any_instance_of(Chef::Recipe).to receive(:db)
                .with('dashboard')
                .and_return(
                  'service_type' => service_type,
                  'db_name' => "#{service_type}_db",
                  'host' => "#{service_type}_host",
                  'port' => "#{service_type}_port"
                )
            end

            [
              /^\s*'ENGINE': '#{backend}',$/,
              /^\s*'NAME': '#{service_type}_db',$/,
            ].each do |cfg|
              it "configures the #{service_type} backend with #{cfg}" do
                expect(chef_run).to render_file(file.name).with_content(cfg)
              end
            end

            [
              /^\s*'USER': '#{service_type}_user',$/,
              /^\s*'PASSWORD': 'test-passes',$/,
              /^\s*'HOST': '#{service_type}_host',$/,
              /^\s*'PORT': '#{service_type}_port',$/,
            ].each do |cfg|
              next if service_type == 'sqlite'
              it "configures the #{service_type} backend with #{cfg}" do
                expect(chef_run).to render_file(file.name).with_content(cfg)
              end
            end
          end
        end

        describe 'plugins' do
          let(:mod_regex) { /^mod = sys.modules\['openstack_dashboard.settings'\]$/ }
          describe 'plugins enabled' do
            it 'shows the mod setting' do
              expect(chef_run2).to render_file(file.name).with_content(mod_regex)
            end

            it 'shows enabled plugins as installed apps' do
              %w(testPlugin1 testPlugin2).each do |plugin|
                expect(chef_run2).to render_file(file.name)
                  .with_content(/^mod\.INSTALLED_APPS \+= \('#{plugin}', \)$/)
              end
            end
          end

          it 'does not show the mod setting if there are no plugins' do
            expect(chef_run).not_to render_file(file.name).with_content(mod_regex)
          end
        end
      end
    end

    describe 'openstack-dashboard syncdb' do
      sync_db_cmd = 'python manage.py syncdb --noinput'
      sync_db_environment = {
        'PYTHONPATH' => '/etc/openstack-dashboard:' \
                        '/usr/share/openstack-dashboard:' \
                        '$PYTHONPATH',
      }

      it 'does not execute when session_backend is not sql' do
        expect(chef_run).not_to run_execute(sync_db_cmd).with(
          cwd: '/usr/share/openstack-dashboard',
          environment: sync_db_environment
        )
      end

      describe 'with sql session' do
        it 'executes when session_backend is sql' do
          expect(chef_run_sql).to run_execute(sync_db_cmd).with(
            cwd: '/usr/share/openstack-dashboard',
            environment: sync_db_environment
          )
        end

        it 'does not execute when the migrate attribute is set to false' do
          expect(chef_run2).not_to run_execute(sync_db_cmd).with(
            cwd: '/usr/share/openstack-dashboard',
            environment: sync_db_environment
          )
        end
      end

      context 'executes when database backend is sqlite' do
        cached(:chef_run) do
          node.override['openstack']['db']['dashboard']['service_type'] = 'sqlite'
          runner.converge('openstack-identity::server-apache', described_recipe)
        end
        it do
          expect(chef_run).to run_execute(sync_db_cmd).with(
            cwd: '/usr/share/openstack-dashboard',
            environment: sync_db_environment
          )
        end
      end
    end

    it 'has group write mode on path' do
      expect(chef_run).to create_directory('/usr/share/openstack-dashboard/openstack_dashboard/local')
        .with(
          owner: 'root',
          group: 'horizon',
          mode: '2770'
        )
    end
  end
end
