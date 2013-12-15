
action :before_compile do
end

action :before_deploy do
  directory ::File.join(new_resource.shared_path, 'node_modules') do
    owner new_resource.owner
    group new_resource.group
    mode "0755"
    action :create
  end
  directory ::File.join(new_resource.shared_path, 'client_modules') do
    owner new_resource.owner
    group new_resource.group
    mode "0755"
    action :create
  end
end

action :before_migrate do

  # Create symlink for root NPM dependecies
  link ::File.join(new_resource.release_path, 'node_modules') do
    to ::File.join(new_resource.shared_path, 'node_modules')
  end

  # Install root app dependencies
  execute 'npm install' do
    cwd   new_resource.release_path
    user  new_resource.owner
    group new_resource.group
    environment new_resource.environment.merge({ 'HOME' => new_resource.shared_path })
  end

  # Client app dependecies
  ruby_block "install dependencies for client apps" do
    block do

      client_dir  = ::File.join(new_resource.release_path, 'client')
      client_apps = []

      # Find client apps that will need dependencies
      Dir.foreach(client_dir) do |f|
        if f == "." or f == ".."
          next
        end
        if ::File.directory? ::File.join(client_dir, f)
          Dir.foreach(::File.join(client_dir, f)) do |cf|
            if !client_apps.include?(f) and cf === 'package.json'
              client_apps.push(f)
            end
          end
        end
      end

      # Let's install those dependecies
      client_apps.each do |app|

        app_modules_dir = ::File.join(new_resource.shared_path, 'client_modules', app)

        # Create the modules directory
        d = Chef::Resource::Directory.new(app_modules_dir, run_context)
        d.owner new_resource.owner
        d.group new_resource.group
        d.mode  "0755"
        d.run_action :create

        # Symlink the modules directory
        sym = Chef::Resource::Link.new(::File.join(client_dir, app, 'node_modules'), run_context)
        sym.to app_modules_dir
        sym.run_action :create

        # Install NPM dependencies
        ex = Chef::Resource::Execute.new("install npm dependecies for: #{app}", run_context)
        ex.cwd          ::File.join(client_dir, app)
        ex.command      "npm install"
        ex.user         new_resource.owner
        ex.group        new_resource.group
        ex.environment  new_resource.environment.merge({ 'HOME' => new_resource.shared_path })
        ex.run_action :run

      end

    end
  end
end

action :before_symlink do

  # Build client apps
  execute 'grunt build' do
    cwd   new_resource.release_path
    user  new_resource.owner
    group new_resource.group
  end

end

action :before_restart do
end

action :after_restart do
end
