# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-dashboard::horizon' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge('openstack-dashboard::server')
    end

    let(:chef_run_session_sql) do
      node.set['openstack']['dashboard']['session_backend'] = 'sql'
      runner.converge('openstack-dashboard::server')
    end

    include_context 'non_redhat_stubs'
    include_context 'dashboard_stubs'

    it 'installs packages' do
      expect(chef_run).to upgrade_package('node-less')
      expect(chef_run).to upgrade_package('openstack-dashboard')
      expect(chef_run).to upgrade_package('python-mysqldb')
    end

    describe 'local_settings.py' do
      let(:file) { chef_run.template('/etc/openstack-dashboard/local_settings.py') }

      it 'creates local_settings' do
        expect(chef_run).to create_template(file.name).with(
          sensitive: true,
          user: 'root',
          group: 'horizon',
          mode: 0640
          )
      end

      it 'notifies web service to restart delayed' do
        expect(file).to notify('service[apache2]').to(:restart).delayed
      end

      context 'template contents' do
        it 'has the customer banner' do
          node.set['openstack']['dashboard']['custom_template_banner'] = 'custom_template_banner_value'
          expect(chef_run).to render_file(file.name).with_content(/^custom_template_banner_value$/)
        end

        context 'misc settings' do
          before do
            node.set['openstack']['dashboard']['misc_local_settings'] = {
              'CUSTOM_CONFIG_A' => {
                'variable1' => 'value1',
                'variable2' => 'value2'
              },
              'CUSTOM_CONFIG_B' => {
                'variable1' => 'value1',
                'variable2' => 'value2'
              }
            }
          end

          it 'sets misc settings properly' do
            [
              ['CUSTOM_CONFIG_A = {',
               '  \'variable1\': \'value1\',',
               '  \'variable2\': \'value2\',',
               '}'],
              ['CUSTOM_CONFIG_B = {',
               '  \'variable1\': \'value1\',',
               '  \'variable2\': \'value2\',',
               '}']
            ].each do |content|
              expect(chef_run).to render_file(file.name).with_content(build_section(content))
            end
          end
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

        context 'config ssl_no_verify' do
          context 'set to the default value' do
            it 'has a True value for the OPENSTACK_SSL_NO_VERIFY attribute' do
              expect(chef_run).to render_file(file.name).with_content(/^OPENSTACK_SSL_NO_VERIFY = True$/)
            end
          end

          context 'set to False' do
            before do
              node.set['openstack']['dashboard']['ssl_no_verify'] = 'False'
            end

            it 'has a False value for the OPENSTACK_SSL_NO_VERIFY attribute' do
              expect(chef_run).to render_file(file.name).with_content(/^OPENSTACK_SSL_NO_VERIFY = False$/)
            end
          end

          context 'not set when ssl disabled' do
            it 'has a True value for the OPENSTACK_SSL_NO_VERIFY attribute' do
              node.set['openstack']['dashboard']['use_ssl'] = false
              expect(chef_run).not_to render_file(file.name).with_content(/^OPENSTACK_SSL_NO_VERIFY = True$/)
            end
          end
        end

        it 'config ssl_cacert' do
          node.set['openstack']['dashboard']['ssl_cacert'] = '/path_to_cacert.pem'
          expect(chef_run).to render_file(file.name).with_content(/^OPENSTACK_SSL_CACERT = '\/path_to_cacert.pem'$/)
        end

        it 'does not config ssl_cacert when ssl disabled' do
          node.set['openstack']['dashboard']['use_ssl'] = false
          node.set['openstack']['dashboard']['ssl_cacert'] = '/path_to_cacert.pem'
          expect(chef_run).not_to render_file(file.name).with_content(/^OPENSTACK_SSL_CACERT = '\/path_to_cacert.pem'$/)
        end

        it 'has some allowed hosts set' do
          node.set['openstack']['dashboard']['allowed_hosts'] = ['dashboard.example.net']
          expect(chef_run).to render_file(file.name).with_content(/^ALLOWED_HOSTS = \["dashboard.example.net"\]$/)
        end

        context 'config hash_algorithm' do
          context 'set to the default value' do
            it 'has the default value for the OPENSTACK_TOKEN_HASH_ALGORITHM attribute' do
              expect(chef_run).to render_file(file.name).with_content(/^OPENSTACK_TOKEN_HASH_ALGORITHM = 'md5'$/)
            end
          end

          context 'set to sha256' do
            before do
              node.set['openstack']['dashboard']['hash_algorithm'] = 'sha256'
            end

            it 'has a sha256 value for the OPENSTACK_TOKEN_HASH_ALGORITHM attribute' do
              expect(chef_run).to render_file(file.name).with_content(/^OPENSTACK_TOKEN_HASH_ALGORITHM = 'sha256'$/)
            end
          end
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

        context 'temp dir override' do
          context 'temp dir is nil' do
            it 'does not override temp dir when it is nil' do
              node.set['openstack']['dashboard']['file_upload_temp_dir'] = nil
              expect(chef_run).not_to render_file(file.name).with_content(/^FILE_UPLOAD_TEMP_DIR =/)
            end
            it 'does override temp dir when it is not nil' do
              node.set['openstack']['dashboard']['file_upload_temp_dir'] = '/foobar'
              expect(chef_run).to render_file(file.name).with_content(/^FILE_UPLOAD_TEMP_DIR = "\/foobar"$/)
            end
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

        it 'does have webroot set' do
          expect(chef_run).to render_file(file.name).with_content(/^WEBROOT = \'\/\'$/)
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

        context 'identity and volume api version setting' do
          it 'is configurable directly' do
            node.set['openstack']['dashboard']['identity_api_version'] = 'identity_api_version_value'
            node.set['openstack']['dashboard']['volume_api_version'] = 'volume_api_version_value'
            [
              /^\s*"identity": identity_api_version_value,$/,
              /^\s*"volume": volume_api_version_value$/
            ].each do |line|
              expect(chef_run).to render_file(file.name).with_content(line)
            end
          end

          it 'sets the proper value for identity v2.0 with volume default v2 from common attributes' do
            node.set['openstack']['api']['auth']['version'] = 'v2.0'
            [
              /^\s*"identity": 2\.0,$/,
              /^\s*"volume": 2$/
            ].each do |line|
              expect(chef_run).to render_file(file.name).with_content(line)
            end
          end

          it 'sets the proper value for identity v3.0 with volume default v2 from common attributes' do
            node.set['openstack']['api']['auth']['version'] = 'v3.0'
            [
              /^\s*"identity": 3,$/,
              /^\s*"volume": 2$/
            ].each do |line|
              expect(chef_run).to render_file(file.name).with_content(line)
            end
          end
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

        it 'allows HORIZON_CONFIG to use INSTALLED_APPS to determine default dashboards' do
          expect(chef_run).not_to render_file(file.name).with_content(/\s*'dashboards':/)
          expect(chef_run).not_to render_file(file.name).with_content(/\s*'default_dashboard':/)
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
                  allow_any_instance_of(Chef::Recipe).to receive(:memcached_servers)
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
          expect(chef_run).to render_file(file.name).with_content(%r{OPENSTACK_KEYSTONE_URL = "http://127.0.0.1:5000/v2.0"})
        end

        it 'has a keystone admin url' do
          expect(chef_run).to render_file(file.name).with_content(%r{OPENSTACK_KEYSTONE_ADMIN_URL = "http://127.0.0.1:35357/v2.0"})
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
          %w(enable_lb enable_quotas enable_firewall enable_vpn).each do |neutron_setting|
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
              allow_any_instance_of(Chef::Recipe).to receive(:db)
                .with('dashboard')
                .and_return('service_type' => service_type,
                            'db_name' => "#{service_type}_db",
                            'host' => "#{service_type}_host",
                            'port' => "#{service_type}_port")
              node.set['openstack']['db']['dashboard']['username'] = "#{service_type}_user"
              node.set['openstack']['db']['python_packages'][service_type] = ['pkg1', 'pkg2']
            end

            [/^\s*'ENGINE': '#{backend}',$/,
             /^\s*'NAME': '#{service_type}_db',$/].each do |cfg|
              it "configures the #{service_type} backend with #{cfg}" do
                expect(chef_run).to render_file(file.name).with_content(cfg)
              end
            end

            [/^\s*'USER': '#{service_type}_user',$/,
             /^\s*'PASSWORD': 'test-passes',$/,
             /^\s*'HOST': '#{service_type}_host',$/,
             /^\s*'PORT': '#{service_type}_port',$/].each do |cfg|
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

    it 'removes openstack-dashboard-ubuntu-theme package' do
      expect(chef_run).to purge_package('openstack-dashboard-ubuntu-theme')
    end

    it 'has group write mode on path' do
      path = chef_run.directory("#{chef_run.node['openstack']['dashboard']['dash_path']}/local")
      expect(path.mode).to eq(02770)
      expect(path.group).to eq(chef_run.node['openstack']['dashboard']['horizon_group'])
    end
  end
end
