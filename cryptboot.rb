#!/usr/bin/env ruby

require 'yaml'

directory = ARGV.shift || "example"
uri_path = ARGV.shift || "http://localhost"

uri_path = uri_path.gsub(/\/$/, '')

system "mkdir out"

boot_id = `openssl rand -hex 4`.chomp
key = `openssl rand -hex 20`.chomp

cmd = "tar zch #{directory} | openssl enc -aes-256-cbc -pass 'pass:#{key}' -out 'out/#{boot_id}.tgz.enc'"
system cmd

config_file = "#{directory}/config.yml"
command = "./init.sh"

config = {}
if File.exists?(config_file)
  config = YAML.load_file(config_file)
end

# Ensure that wget and openssl are present
config["packages"] ||= []
config["packages"] += ['wget', 'openssl', 'screen', 'bash']

boundary = `openssl rand -hex 20`.chomp
bootscript = <<-END
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary=#{boundary}

--#{boundary}
Content-Type: text/cloud-config

#{YAML.dump(config)}
--#{boundary}
Content-Type: text/x-shellscript

#!/bin/bash -ex

cd /root
wget -O '#{boot_id}.tgz.enc' '#{uri_path}/#{boot_id}.tgz.enc'
openssl enc -aes-256-cbc -d -pass 'pass:#{key}' -in '#{boot_id}.tgz.enc' -out '#{boot_id}.tgz'
tar zxf '#{boot_id}.tgz'
cd #{directory}
chmod +x #{command}
screen -d -m #{command}
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
