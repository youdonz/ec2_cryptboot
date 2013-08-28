#!/bin/sh

gem install -q bundler

# Remove any default nginx configuration
rm /etc/nginx/sites-enabled/*
rm /etc/nginx/sites-available/*

# Add our root and site
install -d /var/www
mv public /var/www/rack_site
chmod -R +r /var/www/rack_site
find /var/www/rack_site -type d -exec 'chmod +x'
cp nginx/site.conf /etc/nginx/sites-available/
ln -s /etc/nginx/sites-available/site.conf /etc/nginx/sites-enabled/site.conf
service nginx restart

bundle install --deployment

bundle exec rackup -s thin -E production -p 3000 config.ru

