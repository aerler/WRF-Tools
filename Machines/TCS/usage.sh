#!/bin/bash
# show TCS usage by certain users

LLQ=/usr/lpp/LoadL/full/bin/llq

#totsum=0
echo ""
$LLQ -f %o %nh| grep aerler| awk '{ SUM += $2} END { print "Me: " SUM }'
#u0=`$LLQ -f %o %nh | grep aerler| awk '{ SUM += $2} END { print SUM }'`
$LLQ -f %o %nh | grep guido| awk '{ SUM += $2} END { print "Guido: " SUM }'
#u1=`$LLQ -f %o %nh | grep guido| awk '{ SUM += $2} END { print SUM }'`
$LLQ -f %o %nh| grep dchandan| awk '{ SUM += $2} END { print "Deepak: " SUM }'
$LLQ -f %o %nh| grep huoyilin| awk '{ SUM += $2} END { print "Yiling: " SUM }'
$LLQ -f %o %nh| grep fengyi| awk '{ SUM += $2} END { print "Fengyi: " SUM }'
$LLQ -f %o %nh| grep marcdo| awk '{ SUM += $2} END { print "Marc: " SUM }'
#u8=`$LLQ -f %o %nh | grep marcdo| awk '{ SUM += $2} END { print SUM }'`
$LLQ -f %o %nh| grep mkamal| awk '{ SUM += $2} END { print "Kamal: " SUM }'
$LLQ -f %o %nh| grep handres| awk '{ SUM += $2} END { print "Heather: " SUM }'
#u3=`$LLQ -f %o %nh | grep handres| awk '{ SUM += $2} END { print SUM }'`
$LLQ -f %o %nh| grep shahnas| awk '{ SUM += $2} END { print "Hosein: " SUM }'
#u2=`$LLQ -f %o %nh | grep shahnas| awk '{ SUM += $2} END { print SUM }'`
$LLQ -f %o %nh| grep amashaye| awk '{ SUM += $2} END { print "Ali: " SUM }'
#u7=`$LLQ -f %o %nh | grep amashaye| awk '{ SUM += $2} END { print SUM }'`
$LLQ -f %o %nh| grep jyang| awk '{ SUM += $2} END { print "Jun: " SUM }'
#u4=`$LLQ -f %o %nh | grep jyang| awk '{ SUM += $2} END { print SUM }'`
$LLQ -f %o %nh| grep gula| awk '{ SUM += $2} END { print "Jonathan: " SUM }'
#u5=`$LLQ -f %o %nh | grep gula| awk '{ SUM += $2} END { print SUM }'`
$LLQ -f %o %nh| grep ygliu| awk '{ SUM += $2} END { print "Yonggang: " SUM }'
#u6=`$LLQ -f %o %nh | grep ygliu| awk '{ SUM += $2} END { print SUM }'`
$LLQ -f %o %nh| grep mudryk| awk '{ SUM += $2} END { print "Lawrence: " SUM }'
#u9=`$LLQ -f %o %nh | grep marcdo| awk '{ SUM += $2} END { print SUM }'`
#$LLQ -f %o %nh| grep cdurbin| awk '{ SUM += $2} END { print "Cai: " SUM }'
#u9=`$LLQ -f %o %nh | grep cdurbin| awk '{ SUM += $2} END { print SUM }'`

#totsum=`expr $u1 + $u2`
#echo $totsum
echo ""

# print number of idle nodes
idle
echo ""

