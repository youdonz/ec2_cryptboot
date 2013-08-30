#!/bin/sh

sh compile.sh

ruby rainbow_tables.rb `cat HOST`

