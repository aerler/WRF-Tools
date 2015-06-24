#!/bin/bash
# set up a tunnel between the SciNet datamover node and my komputer via feynmann

# local and intermediate ports used by ssh tunnel
LOCALPORT=50801 # port on local machine (set in .ssh/config)
INTERPORT=58257 # random port, just has to match

# servers for tunneling
SCINET="aerler@login.scinet.utoronto.ca" # skip all my default settings
#SERVER="aerler@feynmann.atmosp.physics.utoronto.ca" # man-in-the-middle
#SERVER="aerler@128.100.80.177" # feynmann (man-in-the-middle)
SERVER="aerler@128.100.80.168" # trident (man-in-the-middle)

# ssh into feynmann and put connection in background (standard tunnel)
ssh -NL $LOCALPORT:localhost:$INTERPORT $SERVER &
SERVERPID=$! # save PID to kill later

# now construct the reverse tunnel from feynmann to the datamover
SSHCMD="ssh -NR $INTERPORT:localhost:22 $SERVER"
# ssh into scinet and execute reverse tunnel on datamover
ssh -t $SCINET ssh -t datamover1 "$SSHCMD"
# after the password prompt, the terminal stays open until killed (Ctrl-C)

# N.B.: both tunnels can in principle be pushed in the background, but they don't exit 
# with the script (or the terminal) and are easily forgotten...

# after reverse tunnel was terminated by user, also kill forward tunnel
kill $SERVERPID # clean-up

# create tunnel (-L for forward tunnel, -R for reverse tunnel, -N means no command, 
# -t to allocate pseudo-tty; not used: -C compression and -f for background)
# N.B.: compression should only be end-to-end; hence, because of the intermediate step,  
# it should be applied on the application level, and not for the tunnel 

## useage with scp & ssh
# scp  -P $LOCALPORT source remoteuser@localhost:destination
# ssh remoteuser@localhost -p $LOCALPORT
# N.B.: host should also be defined in .ssh/config
