#!/bin/bash

pg_dir=/var/lib/postgresql/9.1/main/

/etc/init.d/postgresql stop

cp postgresql.conf pg_hba.conf $pg_dir

install -o postgres -d /etc/wal-e.d/
install -o postgres -m 600 ./wal-e.d/* /etc/wal-e.d/
rm -rf ./wal-e.d

unzip wal-e-0.6.5.zip
pushd wal-e-0.6.5

python2.7 setup.py install

popd

envdir /etc/wal-e.d /usr/local/bin/wal-e backup-fetch $pg_dir `cat CHOSEN_BACKUP`
cp recovery.conf $pg_dir
chown -R postgres $pg_dir

/etc/init.d/postgresql start

/etc/init.d/memcached restart

