#!/bin/bash
su - postgres -c "psql -h 127.0.0.1 -c 'select 1'" &>/dev/null
if [ $? -eq 0 ]; then
  exit 0;
else
  exit 3;
fi
