require 'cli'

module ServiceExtension
  
  def services_data
    ss = client.services_info
    ps = client.services

    ps.sort! {|a, b| a[:name] <=> b[:name] }

    { :system => ss, :provisioned => ps }
  end

  def do_tunnel(service, update)

    ps = client.services
    info = ps.select { |s| s[:name] == service }.first

    err "Unknown service '#{service}'" unless info
 
    raise VMC::Client::AuthError unless client.logged_in?

    if not tunnel_pushed?
      puts "Deploying tunnel application '#{tunnel_appname}'."
      auth = UUIDTools::UUID.random_create.to_s
      push_caldecott(auth)
      bind_service_banner(service, tunnel_appname, false)
      start_caldecott
    else
      auth = tunnel_auth
    end

    port = pick_tunnel_port(@options[:port] || 10000) 

    if not tunnel_healthy?(auth)
      puts "Redeploying tunnel application '#{tunnel_appname}'."

      # We don't expect caldecott not to be running, so take the
      # most aggressive restart method.. delete/re-push
      client.delete_app(tunnel_appname)
      invalidate_tunnel_app_info

      push_caldecott(auth)
      bind_service_banner(service, tunnel_appname, false)
      start_caldecott
    end

    bind_service_banner(service, tunnel_appname) if not tunnel_bound?(service)

    conn_info = tunnel_connection_info info[:vendor], service, auth

    start_tunnel(port, conn_info, auth)
    
    blah = { 'adapter' => conn_info['adapter'], 
        'database' => conn_info['name'], 
        'port' => port,  
        'username' => conn_info['username'], 
        'password' => conn_info['password'] }

    update.call blah
    puts "Waiting for tunnel to close..."
    wait_for_tunnel_end

  end

end

ADAPTERS = { 'mysql' => 'mysql2' }

namespace :vcap do

  task :db_connect => :environment do
    
    db_conf_path = "config/database.yml"

    VMC::Cli::Command::Services.send :include, ServiceExtension
    service_name = Rails.application.class.to_s.split("::").first.underscore

    # create service
    service_client = VMC::Cli::Command::Services.new
    provisioned = service_client.services_data[:provisioned]
    
    service_exists = provisioned.select { |s| s[:name] == service_name }.length > 0

    service_client.create_service nil, service_name if not service_exists
    service = service_client.services_data[:provisioned].select{ |s| s[:name] == service_name }.first
    vendor = service[:vendor]

    puts "Opening tunnel, press ctrl+c to disconnect..."

    update_db = Proc.new do |connection|

      # change database connection details for current environment
      env = Rails.env

      db_config = YAML.load File.read(db_conf_path)
      File.open("#{db_conf_path}.old", 'w') {|f| f.write(db_config.to_yaml) }

      db_config_obj = { 'adapter' => ADAPTERS[vendor], 
        'database' => connection['database'], 
        'host' => '127.0.0.1', 
        'port' => connection['port'],  
        'username' => connection['username'], 
        'password' => connection['password'] }

      puts "Writing new config to #{db_conf_path}."

      db_config[env] = db_config_obj
      
      File.open(db_conf_path, 'w') {|f| f.write(db_config.to_yaml) }

    end

    service_client.do_tunnel(service_name, update_db)

  end

end


