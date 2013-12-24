#!/bin/bash

/etc/init.d/postgresql stop

cp postgresql.conf pg_hba.conf /etc/postgresql/9.1/main/

install -o postgres -d /etc/wal-e.d/
install -o postgres -m 600 ./wal-e.d/* /etc/wal-e.d/
rm -rf ./wal-e.d

unzip wal-e-0.6.5.zip
pushd wal-e-0.6.5

python2.7 setup.py install

popd

/etc/init.d/postgresql start

for client in `cat ./client_applications` standby
  do
    pw=`pwgen 10`
    sudo -u postgres -i -- psql -d template1 -c "CREATE USER $client PASSWORD '$pw'" && echo $client $pw >> /root/db.passwords
    sudo -u postgres -i -- createdb -O $client -T template0 -E UTF8 $client
done

/etc/init.d/memcached restart

cp pg_backup.cron /etc/cron.d/pg_backup

sudo -u postgres envdir /etc/wal-e.d /usr/local/bin/wal-e backup-push /var/lib/postgresql/9.1/main/
