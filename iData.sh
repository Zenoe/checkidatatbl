#!/bin/bash
cd /opt/idata/external/install/monitor
./monitor-free-df.pl
./oozie_check.pl -monitor -nodebug
cat telegraf.log
