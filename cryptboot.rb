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
  
  options[:include_tar] = false
  opts.on( '-i', '--include-tar', 'Include the tarball in the boot script. Note user data size limits.' ) do
    options[:include_tar] = true
    options[:encrypt] = false
  end
  
  options[:encrypt] = true
  opts.on( '-p', '--public', 'Turn off encryption of the tar.' ) do
    options[:encrypt] = false
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

if options[:encrypt]
  key = `openssl rand -hex 20`.chomp
  tar_output = "out/#{boot_id}.tgz.enc"
  system "tar zch #{directory} | openssl enc -aes-256-cbc -pass 'pass:#{key}' -out '#{tar_output}'"
else
  tar_output = "out/#{boot_id}.tgz"
  system "tar zchf '#{tar_output}' #{directory}"
end

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
END

if options[:include_tar]
  bootscript << <<-END
sed -e '1,/^exit$/d' "$0" | tar -zxvf -
  END
else
  if options[:encrypt]
    bootscript << <<-END
wget -O '#{boot_id}.tgz.enc' '#{uri_path}/#{boot_id}.tgz.enc'
openssl enc -aes-256-cbc -d -pass 'pass:#{key}' -in '#{boot_id}.tgz.enc' -out '#{boot_id}.tgz'
tar zxf '#{boot_id}.tgz' && rm '#{boot_id}.tgz'
    END
  else
    bootscript << <<-END
wget -O '#{boot_id}.tgz' '#{uri_path}/#{boot_id}.tgz'
tar zxf '#{boot_id}.tgz' && rm '#{boot_id}.tgz'
    END
  end
end

bootscript << <<-END
cd #{directory}
chmod +x #{command}
cloud-init-per once cryptboot screen -L -d -m #{command}
END

if options[:include_tar]
  bootscript << "exit\n"
  bootscript << File.read(tar_output)
end

bootscript << "\n--#{boundary}--"

IO.popen("gzip -c > out/#{boot_id}.boot.gz", "w") do |bootfile|
  bootfile << bootscript
end

STDERR.puts "---"
if bootscript.length > 16000
  STDERR.puts "Warning: large boot script. Check that it is compatible with the cloud being used."
end
if !options[:include_tar]
  STDERR.puts "Upload #{tar_output} to #{uri_path}/"
end
STDERR.puts "Start Ubuntu EC2 VMs with out/#{boot_id}.boot.gz as boot data"
STDERR.puts "VMs will unpack archive and run #{command}"
STDERR.puts "---"
