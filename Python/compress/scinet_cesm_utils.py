
"""
NOTE: Mar 28, 2016: Modified to ensure compatibility with pyhton 3
"""

import os
from functools import reduce
from paramiko import SSHClient

def secondsToStr(t):
    return "%d:%02d:%02d.%03d" % \
        reduce(lambda ll,b : divmod(ll[0],b) + ll[1:],
            [(t*1000,),1000,60,60])

def which(program):
    """ Checks if an executable is available in the system path. 
        Code from stackoverflow. 
    RETURNS:
        full path to the executable if exists, else None.
    """
    def is_exe(fpath):
        return os.path.isfile(fpath) and os.access(fpath, os.X_OK)

    fpath, fname = os.path.split(program)
    if fpath:
        if is_exe(program):
            return program
    else:
        for path in os.environ["PATH"].split(os.pathsep):
            path = path.strip('"')
            exe_file = os.path.join(path, program)
            if is_exe(exe_file):
                return exe_file
    return None

def push_notification_to_user(msg):
    """
    Pushes a notification to me through the Pushover API. 
    Args:
        msg: the message to push
    Returns:
        True, when pushing successful
    """

    scl = SSHClient()
    scl.load_system_host_keys()
    scl.connect('scinet03-ib0')
    token = "akgAGDCC5mJjsUQSP3VXUUgHwQqJms" # pushover API token
    user  = "uxEnjV6Uz6DHB1B5j5bKy72agTaups" # pushover user ID
    url   = "https://api.pushover.net/1/messages.json"
    cmd   = "curl -s --form-string 'token={0}' --form-string 'user={1}' --form-string 'message={2}' {3}".format(token, user, msg, url)
    stdin, stdout, stderr = scl.exec_command(cmd)
    return True
