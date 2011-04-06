require 'bundler/capistrano'
require 'capfire/capistrano'


set :application, 'itrakt'
set :branch, 'toystore'
set :deploy_to, "/home/#{application}/app"

role :app, 'itrakt.matsimitsu.com'
role :web, 'itrakt.matsimitsu.com'
role :db,  'itrakt.matsimitsu.com', :primary => true

ssh_options[:username] = application


set :scm, :git
set :repository, "."
set :deploy_via, :copy
set :copy_strategy, :export

set :use_sudo, false
default_run_options[:pty] = true
ssh_options[:forward_agent] = true

after 'deploy:update_code', 'deploy:ln_uploads'
after 'deploy:update_code', 'deploy:link_api_keys'

namespace :deploy do
  task :start, :roles => :app do
    run "touch #{current_path}/tmp/restart.txt"
  end

  task :restart, :roles => :app do
    run "touch #{current_path}/tmp/restart.txt"
  end

  task :ln_uploads do
    run "mkdir -p #{shared_path}/uploads && ln -s #{shared_path}/uploads #{release_path}/public/uploads"
  end

  task :link_api_keys do
    run "ln -s #{shared_path}/config/api_keys.rb #{release_path}/lib/api_keys.rb"
  end
end