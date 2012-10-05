gem 'albacore', '~> 0.2.7'
gem 'net-sftp', '~> 2.0.5'

require 'albacore'
require 'net/sftp'
require 'uri'

include Rake::DSL

# The default task prints all possible tasks.
task :default do sh %{rake --describe} end

# Zip files will be placed below this directory.
RedistDirName = "redist"
BitsquidRevision = "r0"
UpstreamVersion = "1.14.0"
ProductName = "openal-soft-#{UpstreamVersion}-#{BitsquidRevision}"

# --------------------------------------------------
# Utility functions.
# --------------------------------------------------

# Configures the supplied Albacore Output task.
def configure_redist_dir(output, zip_file_name)
	working_dir = File.join(RedistDirName, zip_file_name)
	makedirs working_dir

	output.from "."
	output.to File.join(working_dir, zip_file_name)
	
	output.file "build/libopenal.#{UpstreamVersion}.dylib", :as => "lib/libopenal.dylib"
	output.dir "include"
	output.file "COPYING"
	output.file "README"
end

# Configures the supplied Albacore Zip task.
def configure_redist_zip(zip, zip_file_name)
	zip.directories_to_zip File.join(RedistDirName, zip_file_name)
	zip.output_file = zip_file_name + ".zip"
	zip.output_path = RedistDirName
end

# --------------------------------------------------
# Define common rake tasks.
# --------------------------------------------------

desc "Delete all staging directories."
task :clean do |task|
	rm_rf RedistDirName
	rm_rf "build"
	makedirs "build"
end

desc "Build"
task :build => :clean do |task|
	Dir.chdir("build") do
		system %(CFLAGS="-m32" cmake .. && make)
	end
end

desc "Copy build results to redist dir."
output :make_redist_dir => [:build] do |output|
	configure_redist_dir(output, ProductName)
end

desc "Make zip"
zip :make_zip => :make_redist_dir do |zip|
	configure_redist_zip(zip, ProductName)
end

desc "Upload redistributable zip package to a SFTP host."
task :upload, [:dest_dir_uri] => :make_zip do |task, args|
	dest_dir_uri = args.dest_dir_uri # => "sftp://usr:pwd@127.0.0.1/dependencies/lib"
	raise "Must supply dest_dir_uri parameter" if dest_dir_uri.nil?
	uri = URI.parse dest_dir_uri

	Net::SFTP.start(uri.host, uri.user, :password => uri.password) do |sftp|
		sftp.upload!("#{RedistDirName}/#{ProductName}.zip", "#{uri.path}/#{ProductName}.zip")
	end
end

desc "Copy redistributable zip package."
task :copy, [:dest_dir] => :make_zip do |task, args|
	dest_dir = args.dest_dir # => "\\server\"
	raise "Must supply dest_dir parameter" if dest_dir.nil?
	cp "#{RedistDirName}/#{ProductName}.zip", dest_dir
end