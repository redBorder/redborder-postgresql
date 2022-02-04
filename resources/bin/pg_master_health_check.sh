#!/bin/bash
su - postgres -c "psql -h 127.0.0.1 -c 'SELECT pg_current_xlog_location();'" &>/dev/null
if [ $? -eq 0 ]; then
  exit 0;
else
  exit 1;
fi
