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
sudo -u postgres pg_basebackup -h $master -D /var/lib/pgsql/data -U rep -R -v
if [ $? -ne 0 ]; then
    echo "Error detected" 
    exit 1
fi

echo "Creating recovery.signal file"
sudo -u postgres bash -c "touch /var/lib/pgsql/data/recovery.signal"

echo "Starting PostgreSQL"
sudo service postgresql start

popd
