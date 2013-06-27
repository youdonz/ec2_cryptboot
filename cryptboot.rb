#!/usr/bin/env ruby

require 'yaml'

directory = ARGV.shift || "example"
uri_path = ARGV.shift || "http://localhost"
command = ARGV.shift || "#{directory}/init.sh"

system "mkdir out"

boot_id = `openssl rand -hex 4`.chomp
key = `openssl rand -hex 20`.chomp

File.open("#{boot_id}.key", 'w') do |keyfile|
  keyfile << key
end

cmd = "tar zc #{directory} | openssl enc -pass 'file:#{boot_id}.key' -out 'out/#{boot_id}.tgz.enc'"
system cmd

File.unlink("#{boot_id}.key")

config_file = "#{directory}/config.yml"
config = {}
if File.exists?(config_file)
  config = YAML.load_file(config_file)
end

# Ensure that wget and openssl are present
config["packages"] ||= []
config["packages"] += ['wget', 'openssl']

boundary = `openssl rand -hex 20`.chomp
bootscript = <<-END
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary=#{boundary}

--#{boundary}
Content-Type: text/cloud-config

#{YAML.dump(config)}
--#{boundary}
Content-Type: text/x-shellscript

wget -o '#{boot_id}.tgz.enc' '#{uri_path}/#{boot_id}.tgz.enc'
openssl enc -d -pass 'pass:#{key}' -in '#{boot_id}.tgz.enc' -out '#{boot_id}.tgz'
tar zxf '#{boot_id}.tgz'
#{command}
--#{boundary}--
END

IO.popen("gzip -c > out/#{boot_id}.boot.gz", "w") do |bootfile|
  bootfile << bootscript
end

STDERR.puts "---"
STDERR.puts "Upload out/#{boot_id}.tgz.enc to #{uri_path}/#{boot_id}.tgz.enc"
STDERR.puts "Start Ubuntu EC2 VMs with out/#{boot_id}.boot.gz as boot data"
STDERR.puts "VMs will unpack archive and run #{command}"
STDERR.puts "---"