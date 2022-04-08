#!/bin/bash
su - postgres -s /bin/bash -c "psql -h 127.0.0.1 -c 'SELECT pg_current_xlog_location();'" &>/dev/null
if [ $? -eq 0 ]; then
  exit 0;
else
  exit 1;
fi
