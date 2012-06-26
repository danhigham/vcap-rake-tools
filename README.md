vcap-rake-tools
===============

A collection of rake tasks specific too development with Cloudfoundry.com and private vcap instances.

__Gem Dependencies__

* vmc
* caldecott

like this ;

	group :development do
	  gem 'vmc'
	  gem 'caldecott', '>=0.0.5'
	end

__Tasks__

* vcap:db_connect (Rails)

Rather than running MySQL or MongoDB on my laptop whilst developing rails projects I think it's much tidier to run them all on a VM running VCAP (CloudFoundry). This rake task does three things; if a service doesn't exist on the VCAP instance with the same name as the Rails application it creates one, prompting the user for the type of service, it modifies the database.yml file of the project for the current environment and then creates a tunnel to the service. When the rake task has finished, it leaves the tunnel open for use within the application waiting for the user to kill the process manually (hitting ctrl-c in the console).