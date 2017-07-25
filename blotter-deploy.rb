require 'yaml'
require 'optparse'

# global variables to store progress
$commit = ""
$is_updated = false
$is_built = false
$is_deployed = false

# starting directory
$basedir = Dir.pwd

module Hook

	# update main repo
	def self.update_site
		puts "start blotter update"
		Dir.chdir($basedir)
		if !Dir.exists?("blotter")											# start by cloning blotter repo
			unless system "git clone https://github.com/blab/blotter.git"
				raise "blotter update error"
			end
		end
		Dir.chdir($basedir + "/blotter")
		unless system "git clean -f"										# remove untracked files, but keep directories
			raise "blotter update error"
		end
		unless system "git reset --hard HEAD"								# bring back to head state
			raise "blotter update error"
		end
		unless system "git pull origin master"								# git pull
			raise "blotter update error"
		end
		puts "finish blotter update"
	end

	# update project repos
	def self.update_projects
		puts "start project update"
		Dir.chdir($basedir + "/blotter")
		config = YAML.load_file("_config.yml")
		config["projects"].each do |repo|
			name = repo.split('/').drop(1).join('')
			Dir.chdir($basedir + "/blotter/projects")
			if !Dir.exists?(name)											# clone project repo
				unless system "git clone https://github.com/#{repo}.git"
					raise "project update error"
				end
			end
			Dir.chdir($basedir + "/blotter/projects/" + name)
			unless system "git clean -f"									# remove untracked files, but keep directories
				raise "project update error"
			end
			unless system "git reset --hard HEAD"							# bring back to head state
				raise "project update error"
			end
			unless system "git pull origin master"							# git pull
				raise "project update error"
			end
		end
		$is_updated = true
		puts "finish project update"
	end

	# build with jekyll
	# don't rescue from within function
	def self.build
		puts "start build"
		Dir.chdir($basedir + "/blotter")
		unless system "ruby _scripts/preprocess-markdown.rb"
			raise "build error"
		end
		unless system "ruby _scripts/generate-project-data.rb"
			raise "build error"
		end
		unless system "bundle exec jekyll clean"
			raise "build error"
		end
		unless system "bundle exec jekyll build"
			raise "build error"
		end
		puts "finish build"
		$is_built = true
	end

	# deploy to s3
	def self.deploy
		puts "start deploy"
		Dir.chdir($basedir)
		unless system "bundle exec s3_website push --headless --site=blotter/_site"				# run s3_website
			raise "deploy error"
		end
		puts "finish deploy"
		$is_deployed = true
	end

	# run
	def self.run

		options = {}
		OptionParser.new do |opts|
			opts.banner = "Usage: blotter-deploy.rb [options]"
			opts.on("-t", "--[no-]test", "Test build, don't deploy") do |v|
				options[:test] = v
			end
		end.parse!

		update_site
		update_projects
		build
		unless options[:test] == true then
			deploy
		end

	end

end

# deploy
Hook.run
