# encoding: UTF-8
require_relative 'spec_helper'

shared_examples 'virtualhost port configurator' do |port_attribute_name, port_attribute_value|
  let(:virtualhost_directive) { "<VirtualHost 127.0.0.1:#{port_attribute_value}>" }
  before do
    node.set['openstack']['endpoints'][port_attribute_name]['port'] = port_attribute_value
  end

  it 'does not set NameVirtualHost directives when apache 2.4' do
    expect(chef_run).not_to render_file(file.name).with_content(/^NameVirtualHost/)
  end

  it 'sets NameVirtualHost directives when apache 2.2' do
    node.set['apache']['version'] = '2.2'
    expect(chef_run).to render_file(file.name).with_content(/^NameVirtualHost 127.0.0.1:#{port_attribute_value}$/)
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

describe 'openstack-dashboard::apache2-server' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
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

    it 'set apache addresses and ports' do
      expect(chef_run.node['apache']['listen_addresses']).to eq ['127.0.0.1']
      expect(chef_run.node['apache']['listen_ports']).to eq [80, 443]
    end

    it 'includes apache packages' do
      %w(apache2
         apache2::mod_headers
         apache2::mod_wsgi
         apache2::mod_rewrite
         apache2::mod_ssl).each do |recipe|
        expect(chef_run).to include_recipe(recipe)
      end
    end

    it 'does not include the apache mod_ssl package when ssl disabled' do
      node.set['openstack']['dashboard']['use_ssl'] = false
      expect(chef_run).not_to include_recipe('apache2::mod_ssl')
    end

    it 'does not execute set-selinux-enforcing' do
      cmd = '/sbin/setenforce Enforcing ; restorecon -R /etc/httpd'
      expect(chef_run).not_to run_execute(cmd)
    end

    describe 'certs' do
      let(:crt) { chef_run.cookbook_file('/etc/ssl/certs/horizon.pem') }
      let(:key) { chef_run.cookbook_file('/etc/ssl/private/horizon.key') }
      let(:remote_key) { chef_run.remote_file('/etc/ssl/private/horizon.key') }

      it 'has proper owner and group' do
        expect(crt.owner).to eq('root')
        expect(crt.group).to eq('root')
        expect(key.owner).to eq('root')
        expect(key.group).to eq('ssl-cert')
      end

      it 'has proper modes' do
        expect(crt.mode).to eq(0644)
        expect(key.mode).to eq(0640)
      end

      it 'has proper sensitvity' do
        expect(crt.sensitive).to eq(true)
        expect(key.sensitive).to eq(true)
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
        expect(chef_run).to create_remote_file('/etc/ssl/certs/horizon.pem').with(
          sensitive: true,
          user: 'root',
          group: 'root',
          mode: 0644
        )
        expect(chef_run).to create_remote_file('/etc/ssl/private/horizon.key').with(
          sensitive: true,
          user: 'root',
          group: 'ssl-cert',
          mode: 0640
        )
        expect(remote_key).to notify('service[apache2]').to(:restart)
      end

      it 'does not mess with certs if ssl not enabled' do
        node.set['openstack']['dashboard']['use_ssl'] = false
        expect(chef_run).not_to create_cookbook_file(crt)
        expect(chef_run).not_to create_cookbook_file(key)
      end
    end

    it 'creates .blackhole dir with proper owner' do
      dir = '/usr/share/openstack-dashboard/openstack_dashboard/.blackhole'

      expect(chef_run.directory(dir).owner).to eq('root')
    end

    describe 'openstack-dashboard virtual host' do
      let(:file) { chef_run.template('/etc/apache2/sites-available/openstack-dashboard.conf') }

      it 'creates openstack-dashboard.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'root',
          group: 'root',
          mode: 0644
          )
      end

      context 'template content' do
        let(:rewrite_ssl_directive) { /^\s*RewriteEngine On\s*RewriteCond \%\{HTTPS\} off$/ }
        let(:default_rewrite_rule) { %r(^\s*RewriteRule \^\(\.\*\)\$ https\://%\{HTTP_HOST\}%\{REQUEST_URI\} \[L,R\]$) }

        it 'has the default banner' do
          node.set['openstack']['dashboard']['custom_template_banner'] = 'custom_template_banner_value'
          expect(chef_run).to render_file(file.name).with_content(/^custom_template_banner_value$/)
        end

        it_should_behave_like 'virtualhost port configurator', 'dashboard-http-bind', 8080

        context 'cache_html' do
          it 'prevents html page caching' do
            expect(chef_run).to render_file(file.name).with_content(%r{^\s*SetEnvIfExpr "req\('accept'\) =~/html/" NO_CACHE$})
            expect(chef_run).to render_file(file.name).with_content(/^\s*Header merge Cache-Control no-cache env=NO_CACHE$/)
            expect(chef_run).to render_file(file.name).with_content(/^\s*Header merge Cache-Control no-store env=NO_CACHE$/)
          end

          it 'allows html page caching' do
            node.set['openstack']['dashboard']['cache_html'] = true
            expect(chef_run).not_to render_file(file.name).with_content(%r{^\s*SetEnvIfExpr "req\('accept'\) =~/html/" NO_CACHE$})
            expect(chef_run).not_to render_file(file.name).with_content(/^\s*Header merge Cache-Control no-cache env=NO_CACHE$/)
            expect(chef_run).not_to render_file(file.name).with_content(/^\s*Header merge Cache-Control no-store env=NO_CACHE$/)
          end
        end

        context 'with use_ssl enabled' do
          before do
            node.set['openstack']['dashboard']['use_ssl'] = true
          end

          it_should_behave_like 'virtualhost port configurator', 'dashboard-https-bind', 4433

          it 'shows rewrite ssl directive' do
            expect(chef_run).to render_file(file.name).with_content(rewrite_ssl_directive)
          end

          context 'rewrite rule' do
            it 'shows the default SSL rewrite rule when http_port is 80 and https_port is 443' do
              node.set['openstack']['endpoints']['dashboard-http-bind']['port'] = 80
              node.set['openstack']['endpoints']['dashboard-https-bind']['port'] = 443
              expect(chef_run).to render_file(file.name).with_content(default_rewrite_rule)
            end

            it 'shows the parameterized SSL rewrite rule when http_port is different from 80' do
              https_port_value = 443
              node.set['openstack']['endpoints']['dashboard-http-bind']['port'] = 81
              node.set['openstack']['endpoints']['dashboard-https-bind']['port'] = https_port_value
              expect(chef_run).to render_file(file.name)
                .with_content(%r{^\s*RewriteRule \^\(\.\*\)\$ https://%\{SERVER_NAME\}:#{https_port_value}%\{REQUEST_URI\} \[L,R\]$})
            end

            it 'shows the parameterized SSL rewrite rule when https_port is different from 443' do
              https_port_value = 444
              node.set['openstack']['endpoints']['dashboard-http-bind']['port'] = 80
              node.set['openstack']['endpoints']['dashboard-https-bind']['port'] = https_port_value
              expect(chef_run).to render_file(file.name)
                .with_content(%r{^\s*RewriteRule \^\(\.\*\)\$ https://%\{SERVER_NAME\}:#{https_port_value}%\{REQUEST_URI\} \[L,R\]$})
            end
          end

          it 'shows ssl certificate related directives defaults' do
            [/^\s*SSLEngine on$/,
             %r{^\s*SSLCertificateFile /etc/ssl/certs/horizon.pem$},
             %r{^\s*SSLCertificateKeyFile /etc/ssl/private/horizon.key$},
             /^\s*SSLProtocol All -SSLv2 -SSLv3$/].each do |ssl_certificate_directive|
              expect(chef_run).to render_file(file.name).with_content(ssl_certificate_directive)
            end
          end

          it 'has no ssl ciphers configured by default' do
            expect(chef_run).not_to render_file(file.name).with_content(/^\s*SSLCipherSuite.*$/)
          end

          it 'shows ssl related directives overrides' do
            node.set['openstack']['dashboard']['ssl']['dir'] = 'ssl_dir_value'
            node.set['openstack']['dashboard']['ssl']['cert'] = 'ssl_cert_value'
            node.set['openstack']['dashboard']['ssl']['key'] = 'ssl_key_value'
            node.set['openstack']['dashboard']['ssl']['protocol'] = 'ssl_protocol_value'
            node.set['openstack']['dashboard']['ssl']['ciphers'] = 'ssl_ciphers_value'

            [/^\s*SSLEngine on$/,
             %r{^\s*SSLCertificateFile ssl_dir_value/certs/ssl_cert_value$},
             %r{^\s*SSLCertificateKeyFile ssl_dir_value/private/ssl_key_value$},
             /^\s*SSLProtocol ssl_protocol_value$/,
             /^\s*SSLCipherSuite ssl_ciphers_value$/].each do |ssl_directive|
              expect(chef_run).to render_file(file.name).with_content(ssl_directive)
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
            node.set['openstack']['endpoints']['dashboard-http-bind']['port'] = 80
            node.set['openstack']['endpoints']['dashboard-https-bind']['port'] = 443
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
          expect(chef_run).to render_file(file.name).with_content(%r{^\s*WSGIScriptAlias / /usr/share/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi$})
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
            .with_content(%r{\s*DocumentRoot dash_path_value/.blackhole/$})
        end

        it 'has TraceEnable set' do
          node.set['openstack']['dashboard']['traceenable'] = 'value'
          expect(chef_run).to render_file(file.name)
            .with_content(/^  TraceEnable value$/)
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

        context 'directory options' do
          it 'sets default options for apache 2.2' do
            node.set['apache']['version'] = '2.2'
            expect(chef_run).to render_file(file.name).with_content(/^\s*Order allow,deny\n\s*allow from all$/)
          end

          it 'sets default options for apache 2.4' do
            expect(chef_run).to render_file(file.name).with_content(/^\s*Require all granted$/)
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
          expect(chef_run).to render_file(file.name).with_content(%r{^WSGISocketPrefix /var/run/wsgi$})
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

    it 'calls apache_site to disable 000-default virtualhost' do
      resource = chef_run.find_resource('execute',
                                        'a2dissite 000-default.conf').to_hash
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
                                        'a2ensite openstack-dashboard.conf').to_hash
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
      skip 'TODO: how to test when tied to an LWRP'
    end

    it 'does not execute restore-selinux-context' do
      cmd = 'restorecon -Rv /etc/httpd /etc/pki; chcon -R -t httpd_sys_content_t /usr/share/openstack-dashboard || :'

      expect(chef_run).not_to run_execute(cmd)
    end
  end
end
