master=$1
hostname=`hostname`

if [ "x$master" == "x" ]; then
    echo "need to provide master IP" 
    exit 1
fi

rm -f /tmp/postgresql.trigger
pushd /var/lib/pgsql

echo Stopping PostgreSQL
sudo service postgresql stop

echo Cleaning up old cluster directory
sudo -u postgres rm -rf /var/lib/pgsql/data

echo Starting base backup as replicator
sudo -u postgres pg_basebackup -h $master -D /var/lib/pgsql/data -U rep -v
if [ $? -ne 0 ]; then
    echo "Error detected" 
    exit 1
fi

echo Writing recovery.conf file
[ -f /var/lib/pgsql/data/recovery.done ] && rm -f /var/lib/pgsql/data/recovery.done
sudo -u postgres bash -c "cat > /var/lib/pgsql/data/recovery.conf <<- _EOF1_
  standby_mode = 'on'
  primary_conninfo = 'host=$master port=5432 user=rep application_name=$hostname'
  trigger_file = '/tmp/postgresql.trigger'
_EOF1_
"

echo Startging PostgreSQL
sudo service postgresql start

popd
