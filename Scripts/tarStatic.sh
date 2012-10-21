#!/bin/bash
# a short script to archive run folder contents
# Andre R. Erler, 21/10/2012
mkdir -p 'static'
cp -P * 'static/' &> /dev/null
#rm static/tables
cp -rL 'meta/' 'tables/' 'static/'
tar czf static.tgz static/
rm -r 'static/'
mv static.tgz wrfout/
