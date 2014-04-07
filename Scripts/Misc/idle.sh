#!/bin/sh

#tell me the number if idle nodes

ip1=`llstatus | grep -c Idle`
inodes=`expr $ip1 - 1`
if [ "$inodes" -eq 0 ] ; then
  echo "There are no node idle"
elif [ "$inodes" -eq 1 ] ; then
  echo "There is 1 node idle"
else 
  echo "There are "${inodes}" nodes idle"
fi

exit 0
