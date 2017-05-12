#!/bin/bash
cd /tooty
ln -sf /dev/stdout /var/log/nginx/access.log
ln -sf /dev/stderr /var/log/nginx/error.log
nginx -c /etc/nginx/nginx.conf &
/usr/local/bin/npm start
