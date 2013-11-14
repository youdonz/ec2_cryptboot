#!/usr/bin/env ruby

require 'optparse'

def config_merge(a, b)
  if a.nil? || b.nil?
    a || b
  elsif a.kind_of?(Array) || b.kind_of?(Array)
    a = [a] unless a.kind_of?(Array)
    b = [b] unless b.kind_of?(Array)
    (a + b).uniq
  elsif a.kind_of?(Hash) && b.kind_of?(Hash)
    a = a.dup
    b.keys.each do |key|
      if a.has_key?(key)
        a[key] = config_merge(a[key], b[key])
      else
        a[key] = b[key]
      end
    end
    a
  else
    b
  end
end

def load_config(directory)
  config = {}
  config_file = "#{directory}/config.yml"
  if File.exists?(config_file)
    config = YAML.load_file(config_file)
  end
  
  if submodules = config.delete('submodules')
    sc = nil
    submodules.each do |submodule|
      sub_config = load_config("#{directory}/#{submodule}")
      if sc.nil?
        sc = sub_config
      else
        sc = config_merge(sc, sub_config)
      end
    end
    
    config = config_merge(sc, config)
  end
  
  config
end

require 'yaml'

options = {}

optparse = OptionParser.new do|opts|
  opts.banner = "Usage: cryptboot.rb [options] directory/install/"

  options[:verbose] = false
  opts.on( '-v', '--verbose', 'Output more information' ) do
    options[:verbose] = true
  end
  
  options[:uri_path] = 'http://localhost/'
  opts.on( '-u', '--uri-base URI', 'URI to directory where encrypted bundle will be available' ) do |uri|
    options[:uri_path] = uri
  end
  
  opts.on( '-p', '--package-prefix PREFIX', 'Prefix to identify the encrypted bundles' ) do |uri|
    options[:prefix] = uri
  end

  opts.on( nil, '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

remaining = optparse.parse(ARGV)
directory = (remaining.shift || "example").gsub(/\/$/, '')
uri_path = options[:uri_path].gsub(/\/$/, '')

system "mkdir out"

prefix = options[:prefix] || (directory.gsub(/.*\//, '') + ".")
boot_id = prefix + `date +"%Y-%m-%d.%H%M"`.chomp
key = `openssl rand -hex 20`.chomp

cmd = "tar zch #{directory} | openssl enc -aes-256-cbc -pass 'pass:#{key}' -out 'out/#{boot_id}.tgz.enc'"
system cmd

config = load_config(directory)
command = "./init.sh"

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
tar zxf '#{boot_id}.tgz' && rm '#{boot_id}.tgz'
cd #{directory}
chmod +x #{command}
cloud-init-per once cryptboot screen -L -d -m #{command}
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
