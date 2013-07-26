'''
Created on 2012-11-10

Some simple functions built on top of the netCDF4-python module. 

@author: Andre R. Erler
'''

## netCDF4-python module: Dataset is probably all we need
from netCDF4 import Dataset

## definitions
# NC4 compression options
zlib_default = dict(zlib=True, complevel=1, shuffle=True) # my own default compression settings

## functions

# copy attributes from a variable or dataset to another
def copy_ncatts(dst, src, prefix = '', incl_=True):
  for att in src.ncattrs(): 
    if att[0] != '_' or incl_: # these seem to cause problems
      dst.setncattr(prefix+att,src.getncattr(att))
      
# copy variables from one dataset to another
def copy_vars(dst, src, varlist=None, namemap=None, dimmap=None, remove_dims=None, copy_data=True, zlib=True, copy_atts=True, prefix='', incl_=True, **kwargs):
  # prefix is passed to copy_ncatts, the remaining kwargs are passed to dst.createVariable()
  if not varlist: varlist = src.variables.keys() # just copy all
  if dimmap: midmap = dict(zip(dimmap.values(),dimmap.keys())) # reverse mapping
  varargs = dict() # arguments to be passed to createVariable
  if zlib: varargs.update(zlib_default)
  varargs.update(kwargs)
  dtype = varargs.pop('dtype', None) 
  # loop over variable list
  for name in varlist:
    if namemap and (name in namemap.keys()): rav = src.variables[namemap[name]] # apply name mapping 
    else: rav = src.variables[name]
    dims = [] # figure out dimension list
    for dim in rav.dimensions:
      if dimmap and midmap.has_key(dim): dim = midmap[dim] # apply name mapping (in reverse)
      if not (remove_dims and dim in remove_dims): dims.append(dim)
    # create new variable
    dtype = dtype or rav.dtype
    var = dst.createVariable(name, dtype, dims, **varargs)
    if copy_data: var[:] = rav[:] # copy actual data, if desired (default)
    if copy_atts: copy_ncatts(var, rav, prefix=prefix, incl_=incl_) # copy attributes, if desired (default) 

# copy dimensions and coordinate variables from one dataset to another
def copy_dims(dst, src, dimlist=None, namemap=None, copy_coords=True, **kwargs):
  # all remaining kwargs are passed on to dst.createVariable()
  if not dimlist: dimlist = src.dimensions.keys() # just copy all
  if not namemap: namemap = dict() # a dummy - assigning pointers in argument list is dangerous! 
  # loop over dimensions
  for name in dimlist:
    mid = src.dimensions[namemap.get(name,name)]
    # create actual dimensions
    dst.createDimension(name, size=len(mid))
  # create coordinate variable
  if copy_coords:
#    if kwargs.has_key('dtype'): kwargs['datatype'] = kwargs.pop('dtype') # different convention... 
    remove_dims = [dim for dim in src.dimensions.keys() if dim not in dimlist] # remove_dims=remove_dims
    copy_vars(dst, src, varlist=dimlist, namemap=namemap, dimmap=namemap, remove_dims=remove_dims, **kwargs)
    
# add a new dimension with coordinate variable
def add_coord(dst, name, values=None, atts=None, dtype=None, zlib=True, **kwargs):
  # all remaining kwargs are passed on to dst.createVariable()
  # create dimension
  if dst.dimensions.has_key(name):
    assert len(values) == len(dst.dimensions[name]), '\nWARNING: Dimensions %s already present and size does not match!\n'%(name,) 
  else:
    if values is not None:
      if not dtype: dtype = values.dtype # should be standard... 
      dst.createDimension(name, size=len(values))
    else:
      dst.createDimension(name, size=None) # unlimited dimension
  # create coordinate variable
  varargs = dict() # arguments to be passed to createVariable
  if zlib: varargs.update(zlib_default)
  varargs.update(kwargs)
  coord = dst.createVariable(name, dtype, (name,), **varargs)
  if values is not None: coord[:] = values # assign coordinate values if given  
  if atts: # add attributes
    for key,value in atts.iteritems():
      coord.setncattr(key,value) 
      
def add_var(dst, name, dims, values=None, atts=None, dtype=None, zlib=True, **kwargs):
  # all remaining kwargs are passed on to dst.createVariable()
  # use values array to infer dimensions and data type
  if not values is None: 
    # check/create dimension
    assert len(dims) == values.ndim, '\nWARNING: Number of dimensions does not match (%s)!\n'%(name,)    
    for i in xrange(len(dims)):
      if dst.dimensions.has_key(dims[i]):
        assert values.shape[i] == len(dst.dimensions[dims[i]]), \
              '\nWARNING: Size of dimension %s does not match!\n'%(dims[i],)
      else: dst.createDimension(dims[i], size=values.shape[i])
    if not dtype: dtype = values.dtype # infer data type, if not specified 
  # create coordinate variable
  varargs = dict() # arguments to be passed to createVariable
  if zlib: varargs.update(zlib_default)
  varargs.update(kwargs)
  var = dst.createVariable(name, dtype, dims, **varargs)
  if values is not None: var[:] = values # assign coordinate values if given  
  if atts: # add attributes
    for key,value in atts.iteritems():
#       print key, value
      var.setncattr(key,value) 
  

