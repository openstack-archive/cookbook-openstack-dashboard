require_relative 'spec_helper'

shared_examples 'virtualhost port configurator' do |port_attribute_name, port_attribute_value|
  let(:virtualhost_directive) { "<VirtualHost 0.0.0.0:#{port_attribute_value}>" }
  cached(:chef_run) do
    node.override['openstack']['endpoints'][port_attribute_name]['port'] = port_attribute_value
    node.override['openstack']['dashboard']['server_aliases'] = %w(server_aliases_value)
    node.override['openstack']['dashboard']['server_hostname'] = 'server_hostname_value'
    runner.converge(described_recipe)
  end

  it 'does not set NameVirtualHost directives when apache 2.4' do
    expect(chef_run).not_to render_file(file.name).with_content(/^NameVirtualHost/)
  end

  it 'sets the VirtualHost directive' do
    expect(chef_run).to render_file(file.name).with_content(/^#{virtualhost_directive}$/)
  end

  describe 'server_hostname' do
    it 'sets the value if the server_hostname is present' do
      expect(chef_run).to render_file(file.name)
        .with_content(/^#{virtualhost_directive}\s*ServerName server_hostname_value$/)
    end

    it 'does not set the value if the server_hostname is not present' do
      expect(chef_run).not_to render_file(file.name).with_content(/^#{virtualhost_directive}\s*ServerName$/)
    end
  end
  describe 'server_aliases' do
    it 'sets the value if the server_aliases is present' do
      expect(chef_run).to render_file(file.name)
        .with_content(/^#{virtualhost_directive}\s*ServerName.*\s*ServerAlias server_aliases_value$/)
    end
    context 'sets the value if multiple server_aliases is present' do
      cached(:chef_run) do
        node.override['openstack']['dashboard']['server_aliases'] = %w(server_aliases_value1 server_aliases_value2)
        runner.converge(described_recipe)
      end
      it do
        expect(chef_run).to render_file(file.name)
          .with_content(/^#{virtualhost_directive}\s*ServerAlias server_aliases_value1 server_aliases_value2$/)
      end
    end
    it 'does not set the value if the server_aliases is not present' do
      expect(chef_run).not_to render_file(file.name).with_content(/^#{virtualhost_directive}\s*ServerAlias$/)
    end
  end
end

describe 'openstack-dashboard::apache2-server' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      node.override['openstack']['dashboard']['custom_template_banner'] = 'custom_template_banner_value'
      node.override['openstack']['dashboard']['traceenable'] = 'value'
      node.override['openstack']['dashboard']['error_log'] = 'error_log_value'
      node.override['openstack']['dashboard']['access_log'] = 'access_log_value'
      runner.converge(described_recipe)
    end

    cached(:chef_run_no_ssl) do
      node.override['openstack']['dashboard']['use_ssl'] = false
      node.override['openstack']['dashboard']['ssl']['chain'] = 'horizon-chain.pem'
      runner.converge(described_recipe)
    end

    cached(:chef_run_chain) do
      node.override['openstack']['dashboard']['ssl']['chain'] = 'horizon-chain.pem'
      runner.converge(described_recipe)
    end

    include_context 'non_redhat_stubs'
    include_context 'dashboard_stubs'

    it do
      expect(chef_run).to install_apache2_install('openstack').with(listen: %w(0.0.0.0:80 0.0.0.0:443))
    end

    it 'enables apache modules' do
      expect(chef_run).to enable_apache2_module('wsgi')
      expect(chef_run).to enable_apache2_module('rewrite')
      expect(chef_run).to enable_apache2_module('headers')
    end

    it 'does not include the apache mod_ssl package when ssl disabled' do
      expect(chef_run_no_ssl).not_to enable_apache2_module('ssl')
    end

    describe 'certs' do
      describe 'get secret' do
        let(:pem) { chef_run.file('/etc/ssl/certs/horizon.pem') }
        let(:key) { chef_run.file('/etc/ssl/private/horizon.key') }

        it 'create files and restarts apache' do
          expect(chef_run).to create_file('/etc/ssl/certs/horizon.pem').with(
            content: 'horizon_pem_value',
            user: 'root',
            group: 'root',
            mode: '644'
          )
          expect(chef_run).to create_file('/etc/ssl/private/horizon.key').with(
            content: 'horizon_key_value',
            user: 'root',
            group: 'ssl-cert',
            mode: '640'
          )
        end
      end
      describe 'set ssl chain' do
        let(:chain) { chef_run_chain.file('/etc/ssl/certs/horizon-chain.pem') }

        it 'create files and restarts apache' do
          expect(chef_run_chain).to create_file('/etc/ssl/certs/horizon-chain.pem').with(
            content: 'horizon_chain_pem_value',
            user: 'root',
            group: 'root',
            mode: '644'
          )
        end
      end
      describe 'get secret with only one pem' do
        let(:key) { chef_run.file('/etc/ssl/private/horizon.pem') }

        cached(:chef_run) do
          node.override['openstack']['dashboard']['ssl'].tap do |ssl|
            ssl['cert_dir'] = ssl['key_dir'] = '/etc/ssl/private'
            ssl['cert'] = ssl['key'] = 'horizon.pem'
          end
          runner.converge(described_recipe)
        end

        it do
          expect(chef_run).not_to create_file('/etc/ssl/private/horizon.pem')
            .with(
              content: 'horizon_pem_value',
              user: 'root',
              group: 'root',
              mode: '644'
            )
        end

        it do
          expect(chef_run).to create_file('/etc/ssl/private/horizon.pem').with(
            content: 'horizon_pem_value',
            user: 'root',
            group: 'ssl-cert',
            mode: '640'
          )
        end

        it 'does not mess with certs if ssl not enabled' do
          expect(chef_run_no_ssl).not_to create_file('/etc/ssl/certs/horizon.pem')
          expect(chef_run_no_ssl).not_to create_file('/etc/ssl/certs/horizon.key')
          expect(chef_run_no_ssl).not_to create_file('/etc/ssl/certs/horizon-chain.pem')
        end
      end

      context 'get different secret' do
        let(:pem) { chef_run.file('/etc/anypath/any.pem') }
        let(:key) { chef_run.file('/etc/anypath/any.key') }

        cached(:chef_run) do
          node.override['openstack']['dashboard']['ssl']['cert_dir'] = '/etc/anypath'
          node.override['openstack']['dashboard']['ssl']['key_dir'] = '/etc/anypath'
          node.override['openstack']['dashboard']['ssl']['cert'] = 'any.pem'
          node.override['openstack']['dashboard']['ssl']['key'] = 'any.key'
          node.override['openstack']['dashboard']['ssl']['chain'] = 'any-chain.pem'
          runner.converge(described_recipe)
        end

        before do
          allow_any_instance_of(Chef::Recipe).to receive(:secret)
            .with('certs', 'any.pem')
            .and_return('any_pem_value')
          allow_any_instance_of(Chef::Recipe).to receive(:secret)
            .with('certs', 'any.key')
            .and_return('any_key_value')
          allow_any_instance_of(Chef::Recipe).to receive(:secret)
            .with('certs', 'any-chain.pem')
            .and_return('any_chain_pem_value')
          node.override['openstack']['dashboard']
        end
        it 'create files and restarts apache' do
          expect(chef_run).to create_file('/etc/anypath/any.pem').with(
            content: 'any_pem_value',
            user: 'root',
            group: 'root',
            mode: '644'
          )
          expect(chef_run).to create_file('/etc/anypath/any.key').with(
            content: 'any_key_value',
            user: 'root',
            group: 'ssl-cert',
            mode: '640'
          )
        end
        describe 'set ssl chain' do
          let(:chain) { chef_run.file('/etc/anypath/any-chain.pem') }
          it 'create files and restarts apache' do
            expect(chef_run).to create_file('/etc/anypath/any-chain.pem').with(
              content: 'any_chain_pem_value',
              user: 'root',
              group: 'root',
              mode: '644'
            )
          end
        end
        it 'does not mess with certs if ssl not enabled' do
          expect(chef_run_no_ssl).not_to create_file('/etc/anypath/any.key')
          expect(chef_run_no_ssl).not_to create_file('/etc/anypath/any.pem')
          expect(chef_run_no_ssl).not_to create_file('/etc/anypath/any-chain.pem')
        end
        context 'does not create certs if certs data bag is disabled' do
          cached(:chef_run) do
            node.override['openstack']['dashboard']['ssl']['use_data_bag'] = false
            node.override['openstack']['dashboard']['ssl']['chain'] = 'horizon-chain.pem'
            runner.converge(described_recipe)
          end
          it do
            expect(chef_run).not_to create_file('/etc/ssl/certs/horizon.pem')
            expect(chef_run).not_to create_file('/etc/ssl/certs/horizon.key')
            expect(chef_run).not_to create_file('/etc/ssl/certs/horizon-chain.pem')
          end
        end
      end
    end

    it 'creates .blackhole dir with proper owner' do
      dir = '/usr/share/openstack-dashboard/openstack_dashboard/.blackhole'

      expect(chef_run.directory(dir).owner).to eq('root')
    end

    describe 'openstack-dashboard virtual host' do
      let(:file) { chef_run.template('/etc/apache2/sites-available/openstack-dashboard.conf') }

      it 'creates openstack-dashboard.conf' do
        expect(chef_run).to create_template('/etc/apache2/sites-available/openstack-dashboard.conf').with(
          source: 'dash-site.erb',
          variables: {
            apache_admin: 'root@localhost',
            http_bind_address: '0.0.0.0',
            http_bind_port: 80,
            https_bind_address: '0.0.0.0',
            https_bind_port: 443,
            log_dir: '/var/log/apache2',
            ssl_cert_file: '/etc/ssl/certs/horizon.pem',
            ssl_chain_file: '',
            ssl_key_file: '/etc/ssl/private/horizon.key',
          }
        )
      end

      it do
        expect(chef_run.template('/etc/apache2/sites-available/openstack-dashboard.conf')).to \
          notify('service[apache2]').to(:reload).immediately
      end

      describe 'template content' do
        let(:rewrite_ssl_directive) { /^\s*RewriteEngine On\s*RewriteCond \%\{HTTPS\} off$/ }
        let(:default_rewrite_rule) { %r(^\s*RewriteRule \^\(\.\*\)\$ https\://%\{HTTP_HOST\}%\{REQUEST_URI\} \[L,R\]$) }

        it 'has the default banner' do
          expect(chef_run).to render_file(file.name).with_content(/^custom_template_banner_value$/)
        end

        describe 'cache_html' do
          it 'prevents html page caching' do
            expect(chef_run).to render_file(file.name)
              .with_content(%r{^\s*SetEnvIfExpr "req\('accept'\) =~/html/" NO_CACHE$})
            expect(chef_run).to render_file(file.name)
              .with_content(/^\s*Header merge Cache-Control no-cache env=NO_CACHE$/)
            expect(chef_run).to render_file(file.name)
              .with_content(/^\s*Header merge Cache-Control no-store env=NO_CACHE$/)
          end

          context 'allows html page caching' do
            cached(:chef_run) do
              node.override['openstack']['dashboard']['cache_html'] = true
              runner.converge(described_recipe)
            end
            it do
              expect(chef_run).not_to render_file(file.name)
                .with_content(%r{^\s*SetEnvIfExpr "req\('accept'\) =~/html/" NO_CACHE$})
              expect(chef_run).not_to render_file(file.name)
                .with_content(/^\s*Header merge Cache-Control no-cache env=NO_CACHE$/)
              expect(chef_run).not_to render_file(file.name)
                .with_content(/^\s*Header merge Cache-Control no-store env=NO_CACHE$/)
            end
          end
        end

        it_should_behave_like 'virtualhost port configurator', 'dashboard-http-bind', 80

        describe 'with use_ssl enabled' do
          it_should_behave_like 'virtualhost port configurator', 'dashboard-https-bind', 443

          it 'shows rewrite ssl directive' do
            expect(chef_run).to render_file(file.name).with_content(rewrite_ssl_directive)
          end

          describe 'rewrite rule' do
            it 'shows the default SSL rewrite rule when http_port is 80 and https_port is 443' do
              expect(chef_run).to render_file(file.name).with_content(default_rewrite_rule)
            end

            context 'shows the parameterized SSL rewrite rule when http_port is different from 80' do
              https_port_value = 443
              cached(:chef_run) do
                node.override['openstack']['dashboard']['use_ssl'] = true
                node.override['openstack']['bind_service']['dashboard_http']['port'] = 81
                node.override['openstack']['bind_service']['dashboard_https']['port'] = https_port_value
                runner.converge(described_recipe)
              end
              it do
                expect(chef_run).to render_file(file.name)
                  .with_content(%r{^\s*RewriteRule \^\(\.\*\)\$ https://%\{SERVER_NAME\}:#{https_port_value}%\{REQUEST_URI\} \[L,R\]$})
              end
            end

            context 'shows the parameterized SSL rewrite rule when https_port is different from 443' do
              https_port_value = 444
              cached(:chef_run) do
                node.override['openstack']['dashboard']['use_ssl'] = true
                node.override['openstack']['bind_service']['dashboard_http']['port'] = 80
                node.override['openstack']['bind_service']['dashboard_https']['port'] = https_port_value
                runner.converge(described_recipe)
              end
              it do
                expect(chef_run).to render_file(file.name)
                  .with_content(%r{^\s*RewriteRule \^\(\.\*\)\$ https://%\{SERVER_NAME\}:#{https_port_value}%\{REQUEST_URI\} \[L,R\]$})
              end
            end
          end

          it 'shows ssl certificate related directives defaults' do
            [
              /^\s*SSLEngine on$/,
              %r{^\s*SSLCertificateFile /etc/ssl/certs/horizon.pem$},
              %r{^\s*SSLCertificateKeyFile /etc/ssl/private/horizon.key$},
              /^\s*SSLProtocol All -SSLv2 -SSLv3$/,
            ].each do |ssl_certificate_directive|
              expect(chef_run).to render_file(file.name).with_content(ssl_certificate_directive)
            end
            expect(chef_run).to_not render_file(file.name).with_content(/SSLCertificateChainFile/)
          end
          describe 'set ssl chain' do
            it 'shows chain directive' do
              expect(chef_run_chain).to render_file(file.name)
                .with_content(%r{^\s*SSLCertificateChainFile /etc/ssl/certs/horizon-chain.pem$})
            end
          end
          context 'set use_data_bag to false' do
            cached(:chef_run) do
              node.override['openstack']['dashboard']['ssl']['use_data_bag'] = false
              runner.converge(described_recipe)
            end
            it 'shows ssl certificate related directives defaults' do
              [
                /^\s*SSLEngine on$/,
                %r{^\s*SSLCertificateFile /etc/ssl/certs/horizon.pem$},
                %r{^\s*SSLCertificateKeyFile /etc/ssl/private/horizon.key$},
                /^\s*SSLProtocol All -SSLv2 -SSLv3$/,
              ].each do |ssl_certificate_directive|
                expect(chef_run).to render_file(file.name).with_content(ssl_certificate_directive)
              end
              expect(chef_run).to_not render_file(file.name).with_content(/SSLCertificateChainFile/)
            end
            context 'set ssl chain' do
              cached(:chef_run) do
                node.override['openstack']['dashboard']['ssl']['use_data_bag'] = false
                node.override['openstack']['dashboard']['ssl']['chain'] = 'horizon-chain.pem'
                runner.converge(described_recipe)
              end
              it 'shows chain directive' do
                expect(chef_run).to render_file(file.name)
                  .with_content(%r{^\s*SSLCertificateChainFile /etc/ssl/certs/horizon-chain.pem$})
              end
            end
          end
          it 'has no ssl ciphers configured by default' do
            expect(chef_run).not_to render_file(file.name).with_content(/^\s*SSLCipherSuite.*$/)
          end
          # noinspection CookbookSourceRoot
          context 'override attributes' do
            cached(:chef_run) do
              node.override['openstack']['dashboard']['ssl']['cert'] = 'ssl.cert'
              node.override['openstack']['dashboard']['ssl']['key'] = 'ssl.key'
              node.override['openstack']['dashboard']['ssl']['cert_dir'] = 'ssl_dir_value/certs'
              node.override['openstack']['dashboard']['ssl']['key_dir'] = 'ssl_dir_value/private'
              node.override['openstack']['dashboard']['ssl']['protocol'] = 'ssl_protocol_value'
              node.override['openstack']['dashboard']['ssl']['ciphers'] = 'ssl_ciphers_value'
              runner.converge(described_recipe)
            end
            before do
              allow_any_instance_of(Chef::Recipe).to receive(:secret)
                .with('certs', 'ssl.cert')
                .and_return('ssl_cert_value')
              allow_any_instance_of(Chef::Recipe).to receive(:secret)
                .with('certs', 'ssl.key')
                .and_return('ssl_key_value')
            end
            it 'shows ssl related directives overrides' do
              [
                /^\s*SSLEngine on$/,
                %r{^\s*SSLCertificateFile ssl_dir_value/certs/ssl.cert$},
                %r{^\s*SSLCertificateKeyFile ssl_dir_value/private/ssl.key$},
                /^\s*SSLProtocol ssl_protocol_value$/,
                /^\s*SSLCipherSuite ssl_ciphers_value$/,
              ].each do |ssl_directive|
                expect(chef_run).to render_file(file.name).with_content(ssl_directive)
              end
              expect(chef_run).to_not render_file(file.name).with_content(/SSLCertificateChainFile/)
            end
          end
        end
        context 'with use_ssl disabled' do
          cached(:chef_run) do
            node.override['openstack']['dashboard']['use_ssl'] = false
            runner.converge(described_recipe)
          end

          it 'does not show rewrite ssl directive' do
            expect(chef_run).not_to render_file(file.name).with_content(rewrite_ssl_directive)
          end

          context 'does not show the default rewrite rule' do
            cached(:chef_run) do
              node.override['openstack']['dashboard']['use_ssl'] = false
              node.override['openstack']['endpoints']['dashboard-http-bind']['port'] = 80
              node.override['openstack']['endpoints']['dashboard-https-bind']['port'] = 443
              runner.converge(described_recipe)
            end
            it do
              expect(chef_run).not_to render_file(file.name).with_content(default_rewrite_rule)
            end
          end

          it 'does not show ssl certificate related directives' do
            [
              /^\s*SSLEngine on$/,
              /^\s*SSLCertificateFile/,
              /^\s*SSLCertificateKeyFile/,
            ].each do |ssl_certificate_directive|
              expect(chef_run).not_to render_file(file.name).with_content(ssl_certificate_directive)
            end
            expect(chef_run).to_not render_file(file.name).with_content(/SSLCertificateChainFile/)
          end
        end

        it 'shows the ServerAdmin' do
          expect(chef_run).to render_file(file.name).with_content(/\s*ServerAdmin root@localhost$/)
        end

        it 'sets the WSGI script alias defaults' do
          expect(chef_run).to render_file(file.name)
            .with_content(%r{^\s*WSGIScriptAlias / /usr/share/openstack-dashboard/openstack_dashboard/wsgi.py$})
        end

        context 'sets the WSGI script alias' do
          cached(:chef_run) do
            node.override['openstack']['dashboard']['wsgi_path'] = 'wsgi_path_value'
            node.override['openstack']['dashboard']['webroot'] = 'root'
            runner.converge(described_recipe)
          end
          it do
            expect(chef_run).to render_file(file.name).with_content(/^\s*WSGIScriptAlias root wsgi_path_value$/)
          end
        end

        context 'sets the WSGI daemon process' do
          cached(:chef_run) do
            node.override['openstack']['dashboard']['horizon_user'] = 'horizon_user_value'
            node.override['openstack']['dashboard']['horizon_group'] = 'horizon_group_value'
            node.override['openstack']['dashboard']['dash_path'] = 'dash_path_value'
            runner.converge(described_recipe)
          end
          it do
            expect(chef_run).to render_file(file.name).with_content(
              /^\s*WSGIDaemonProcess dashboard user=horizon_user_value group=horizon_group_value processes=3 threads=10 python-path=dash_path_value$/
            )
          end
        end

        context 'has the default DocRoot' do
          cached(:chef_run) do
            node.override['openstack']['dashboard']['dash_path'] = 'dash_path_value'
            runner.converge(described_recipe)
          end
          it do
            expect(chef_run).to render_file(file.name).with_content(%r{\s*DocumentRoot dash_path_value/.blackhole/$})
          end
        end

        it 'has TraceEnable set' do
          expect(chef_run).to render_file(file.name).with_content(/^  TraceEnable value$/)
        end

        context 'sets the right Alias path for /static' do
          cached(:chef_run) do
            node.override['openstack']['dashboard']['static_path'] = 'static_path_value'
            runner.converge(described_recipe)
          end
          it do
            expect(chef_run).to render_file(file.name).with_content(%r{^\s+Alias /static static_path_value$})
          end
        end

        context 'sets the directory directive' do
          cached(:chef_run) do
            %w(dash_path static_path).each do |dir_attribute|
              node.override['openstack']['dashboard'][dir_attribute] = "#{dir_attribute}_value"
            end
            runner.converge(described_recipe)
          end
          %w(dash_path static_path).each do |dir_attribute|
            it do
              expect(chef_run).to render_file(file.name).with_content(/^\s*<Directory #{dir_attribute}_value>$/)
            end
          end
        end

        describe 'directory options' do
          it 'sets default options for apache 2.4' do
            expect(chef_run).to render_file(file.name).with_content(/^\s*Require all granted$/)
          end
        end

        context 'sets wsgi socket prefix if wsgi_socket_prefix attribute is preset' do
          cached(:chef_run) do
            node.override['openstack']['dashboard']['wsgi_socket_prefix'] = '/var/run/wsgi'
            runner.converge(described_recipe)
          end
          it do
            expect(chef_run).to render_file(file.name).with_content(%r{^WSGISocketPrefix /var/run/wsgi$})
          end
        end

        it 'omits wsgi socket prefix if wsgi_socket_prefix attribute is not preset' do
          expect(chef_run).not_to render_file(file.name).with_content(/^WSGISocketPrefix $/)
        end
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
        expect(file.mode).to eq('600')
      end

      it 'does not notify apache2 restart' do
        expect(file).not_to notify('service[apache2]').to(:restart)
      end

      context 'has configurable path and ownership settings' do
        cached(:chef_run) do
          node.override['openstack']['dashboard']['secret_key_path'] = 'somerandompath'
          node.override['openstack']['dashboard']['horizon_user'] = 'somerandomuser'
          node.override['openstack']['dashboard']['horizon_group'] = 'somerandomgroup'
          node.override['openstack']['dashboard']['secret_key_content'] = 'somerandomcontent'
          runner.converge(described_recipe)
        end
        it do
          file = chef_run.file('somerandompath')
          expect(file.owner).to eq('somerandomuser')
          expect(file.group).to eq('somerandomgroup')
        end

        describe 'secret_key_content set' do
          it 'has configurable secret_key_content setting' do
            expect(chef_run).to render_file('somerandompath').with_content('somerandomcontent')
          end

          it 'notifies apache2 restart when secret_key_content set' do
            expect(chef_run.file('somerandompath')).to notify('service[apache2]').to(:restart)
          end
        end
      end
    end

    it 'does not delete openstack-dashboard.conf' do
      file = '/etc/httpd/conf.d/openstack-dashboard.conf'

      expect(chef_run).not_to delete_file(file)
    end

    it do
      expect(chef_run).to disable_apache2_site('000-default')
    end

    it do
      expect(chef_run).to_not disable_apache2_site('default')
    end

    it do
      expect(chef_run).to enable_apache2_site('openstack-dashboard')
    end

    it do
      expect(chef_run.apache2_site('openstack-dashboard')).to notify('service[apache2]').to(:reload).immediately
    end
  end
end
