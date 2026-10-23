require 'yaml'
require 'optparse'
require 'find'

# global variables to store progress
$commit = ""
$is_updated = false
$is_built = false
$is_deployed = false

# starting directory
$basedir = Dir.pwd

module Hook

	# filenames that should never be published
	SENSITIVE_NAMES = [
		/\Aenvironment/i,														# environment_blotter_blab.sh
		/\A\.env/i,
		/\A\.?netrc\z/i,
		/\Acredentials\z/i,														# ~/.aws/credentials
		/\Aid_(rsa|dsa|ecdsa|ed25519)/,											# ssh keys
		/\.(pem|key|p12|pfx|ppk)\z/i
	]

	# file contents that should never be published
	SENSITIVE_CONTENTS = {
		"private key" => /-----BEGIN [A-Z ]*PRIVATE KEY-----/,
		"AWS access key ID" => /\b(AKIA|ASIA)[0-9A-Z]{16}\b/,
		"GitHub token" => /\b(gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,})\b/
	}

	# env vars whose values should never appear in the site
	SECRET_ENV_VARS = ["GITHUB_TOKEN", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_SESSION_TOKEN"]

	# only scan contents of files up to this size; credential files are small
	MAX_SCAN_BYTES = 1024 * 1024

	# update main repo
	def self.update_site
		puts "start blotter update"
		Dir.chdir($basedir)
		if !Dir.exist?("blotter")											# start by cloning blotter repo
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
			if !Dir.exist?(name)											# clone project repo
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

	# refuse to build if blotter or any project repo contains a symlink
	# jekyll follows symlinks outside of safe mode, so a committed link
	# (eg to ../../../environment_blotter_blab.sh) would publish its target
	def self.check_symlinks(dir = $basedir + "/blotter")
		puts "start symlink check"
		links = []
		Find.find(dir) do |path|
			if File.basename(path) == ".git"
				Find.prune
			elsif File.symlink?(path)
				links.push(path)
			end
		end
		links.each { |path| puts "symlink: #{path} -> #{File.readlink(path)}" }
		raise "symlink check error" unless links.empty?
		puts "finish symlink check"
	end

	# build with jekyll
	# don't rescue from within function
	def self.build
		puts "start build"
		Dir.chdir($basedir + "/blotter")
		unless system "ruby _scripts/generate-readmes.rb"
			raise "build error - generate-readmes"
		end
		unless system "ruby _scripts/preprocess-markdown.rb"
			raise "build error - preprocess-markdown"
		end
		unless system "ruby _scripts/generate-project-data.rb"
			raise "build error - generate-project-data"
		end
		unless system "bundle exec jekyll clean"
			raise "build error - jekyll clean"
		end
		unless system "bundle exec jekyll build"
			raise "build error - jekyll build"
		end
		puts "finish build"
		$is_built = true
	end

	# refuse to deploy if the built site contains anything that looks like a credential
	# reports file and reason only, never the matched text
	def self.check_site(site = $basedir + "/blotter/_site")
		puts "start site check"
		secrets = SECRET_ENV_VARS.map { |var| ENV[var] }.compact.select { |s| s.length >= 16 }.map(&:b)
		problems = []
		Find.find(site) do |path|
			next unless File.file?(path)
			relpath = path.delete_prefix(site + "/")
			if SENSITIVE_NAMES.any? { |pattern| File.basename(path) =~ pattern }
				problems.push("#{relpath}: sensitive filename")
			end
			next if File.size(path) > MAX_SCAN_BYTES
			contents = File.binread(path)
			SENSITIVE_CONTENTS.each do |label, pattern|
				problems.push("#{relpath}: contains #{label}") if contents =~ pattern
			end
			if secrets.any? { |secret| contents.include?(secret) }
				problems.push("#{relpath}: contains a secret from the environment")
			end
		end
		problems.each { |problem| puts problem }
		raise "site check error" unless problems.empty?
		puts "finish site check"
	end

	# deploy to s3
	def self.deploy
		puts "start deploy"
		Dir.chdir($basedir)
		puts "S3 sync"
		unless system "aws s3 sync blotter/_site/ s3://#{ENV['S3_BUCKET']} --size-only --delete --cache-control max-age=604800"
			raise "deploy error - aws s3 sync"
		end
		puts "CloudFront invalidation"
		unless system "aws cloudfront create-invalidation --distribution-id #{ENV['CLOUDFRONT_ID']} --paths '/*'"
			raise "deploy error - aws cloudfront"
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
		check_symlinks
		build
		check_site
		unless options[:test] == true then
			deploy
		end

	end

end

# deploy
Hook.run
