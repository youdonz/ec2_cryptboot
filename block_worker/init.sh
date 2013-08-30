#!/bin/sh

sh compile.sh

ruby worker.rb `cat HOST`

