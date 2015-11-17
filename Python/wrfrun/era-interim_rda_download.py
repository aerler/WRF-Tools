#! /usr/bin/env python
#
# python script to download selected files from rda.ucar.edu
# after you save the file, don't forget to make it executable
#   i.e. - "chmod 755 <name_of_script>"
#
import sys
import os
import urllib2
import cookielib
import pandas
#
lverbose=True
lnoclobber=False
args = []
for arg in sys.argv[1:]:
  if arg == '-q': lverbose = False
  elif arg == '-n': lnoclobber = True
  elif arg == '-h' or arg == '--help':
    print('''
usage: {:s} [-q] [-n] [-h] password_on_RDA_webserver begin-date end-date\n
       -q   suppresses the progress message for each file that is downloaded
       -n   skips existing files (no-clobber)
       -h   print this message
       '''.format(sys.argv[0]))
    sys.exit(1)    
  else: args.append(arg)
# assign arguments
passwd, begindate, enddate = args # any pandas-compatible date string is probably fine

# check password
if (len(sys.argv) == 3 and sys.argv[1] == "-q"):
  passwd_idx=2
  verbose=False
#
cj = cookielib.MozillaCookieJar()
opener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cj))
#
# check for existing cookies file and authenticate if necessary
do_authentication=False
if (os.path.isfile("auth.rda.ucar.edu")):
  os.remove("auth.rda.ucar.edu") # old cookies cause problems    
#  cj.load("auth.rda.ucar.edu",False,True)
#  for cookie in cj:
#    if (cookie.name == "sess" and cookie.is_expired()):
#      do_authentication=True
do_authentication=True
if (do_authentication):
  login=opener.open("https://rda.ucar.edu/cgi-bin/login","email=aerler@atmosp.physics.utoronto.ca&password="+passwd+"&action=login")
#
# save the authentication cookies for future downloads
# NOTE! - cookies are saved for future sessions because overly-frequent authentication to our server can cause your data access to be blocked
  cj.clear_session_cookies()
  cj.save("auth.rda.ucar.edu",True,True)
#
# download the data file(s)
urltrunk = "http://rda.ucar.edu/data/ds627.0/"
localtrunk = os.getcwd() # current folder
filetypes = ['sc','uv','sfc']
folders = dict()
folders['sc']  = "ei.oper.an.pl/{0:s}/" # YYYYMM
folders['uv']  = "ei.oper.an.pl/{0:s}/" # YYYYMM
folders['sfc'] = "ei.oper.an.sfc/{0:s}/" # YYYYMM
files = dict()
files['sc'] = "ei.oper.an.pl.regn128sc.{0:s}" # YYYYMMDDHH
files['uv'] = "ei.oper.an.pl.regn128uv.{0:s}" # YYYYMMDDHH
files['sfc'] = "ei.oper.an.sfc.regn128sc.{0:s}" # YYYYMMDDHH
# check
for key in folders.keys(): 
  if key not in filetypes: raise ValueError
for key in files.keys(): 
  if key not in filetypes: raise ValueError
# make local folders
localfolders = {filetype:'/{0:s}/{1:s}/'.format(localtrunk,filetype) for filetype in filetypes}
for localfolder in localfolders.itervalues():
  if not os.path.exists(localfolder): os.mkdir(localfolder)

# date settings
begin = pandas.to_datetime(begindate)
end   = pandas.to_datetime(enddate)
freq  = '6H' # every 6 hours
datelist = pandas.date_range(begin, end, freq=freq)
# iterate over dates
for date in datelist:
  yyyymm     = date.strftime('%Y%m')
  yyyymmddhh = date.strftime('%Y%m%d%H')
  # loop over filetypes
  for filetype in filetypes:    
    urlfolder   = urltrunk + folders[filetype].format(yyyymm)
    filename    = files[filetype].format(yyyymmddhh)
    localfile   = localfolders[filetype]+filename
    # start download
    if lnoclobber and os.path.exists(localfile):
      if lverbose:
	sys.stdout.write("skipping "+filename+"\n")
	sys.stdout.flush()
    else:
      if lverbose:
	sys.stdout.write("downloading "+filename+"...\n")
	sys.stdout.flush()
      infile  = opener.open(urlfolder+filename)
      outfile = open(localfile,"wb")
      outfile.write(infile.read())
      outfile.close()
    
if lverbose:
  sys.stdout.write("done.\n")

# clean up old cookies
os.remove("auth.rda.ucar.edu")
