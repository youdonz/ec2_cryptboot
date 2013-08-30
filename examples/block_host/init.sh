#!/bin/sh

gem install -q bundler

bundle install --deployment

bundle exec ruby server.rb `cat OPTIONS`

