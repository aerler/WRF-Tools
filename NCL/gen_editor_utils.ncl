;----------------------------------------------------------------------
; The functions in this script are for listing every single NCL
; function, procedure, resource, and operator. These lists can
; be used to generate editor enhancements for emacs, vi, nedit,
; etc.
;
; Usage:
;
;  load "gen_editor_utils.ncl"
;
;  begin
;    fp_names  = get_ncl_procs_and_funcs()          ; Use this or
;    fp_names  = get_ncl_procs_and_funcs_by_cat()   ; this---not both!
;    res_names = get_ncl_resources()
;    key_names = get_ncl_keywords()
;    op_names  = get_ncl_operators()
;  end
;
; The "gen_emacs_file.ncl" script uses this script to create an emacs
; editor enhancement file called "ncl.el".
; 
; With the NCL functions and procedures, you can list them all
; as one big giant list of functions ("get_ncl_procs_and_funcs")
; or by category  ("get_ncl_procs_and_funcs_by_cat").
;
;----------------------------------------------------------------------
; This variable determines whether to use "wget" to retrieve HTML 
; pages from web. This should be set to True at least the first
; time you run this script. After that, if the *.shtml files don't
; change on the web, then you can set this to False.
;----------------------------------------------------------------------
GET_FROM_WEB = True

;----------------------------------------------------------------------
; This function returns a list of valid category names we can
; use for NCL functions and procedures.
;----------------------------------------------------------------------
undef("get_valid_cat_names")
function get_valid_cat_names()
begin
;
; Each "names" triplet contains an abbreviated category name, 
; the descriptive name that will end up in the emacs file,
; and the shtml filename that is linked to from the 
; "list_alpha_browse.shtml" file.
; 
  return((/ \
            (/"builtin", \
              "ncl built-in functions", \
              "/Document/Functions/Built-in/"/), \
            (/"contrib", \
              "contributed functions", \
              "/Document/Functions/Contributed/"/), \
            (/"diag", \
              "diagnostics functions", \
              "/Document/Functions/Diagnostics/"/), \
            (/"pop", \
              "pop_remap functions", \
              "/Document/Functions/Pop_remap/"/), \
            (/"shea", \
              "shea_util functions", \
              "/Document/Functions/Shea_util/"/), \
            (/"skewt", \
              "skewt functions", \
              "/Document/Functions/Skewt_func/"/), \
            (/"user", \
              "user_contributed functions", \
              "/Document/Functions/User_contributed/"/), \
            (/"wrfarw", \
              "wrf_arw functions", \
              "/Document/Functions/WRF_arw/"/), \
            (/"wrfcontrib", \
              "wrf_contributed functions", \
              "/Document/Functions/WRF_contributed/"/), \
            (/"windrose", \
              "wind_rose functions", \
              "/Document/Functions/Wind_rose/"/), \
            (/"gsn", \
              "gsn csm plot templates and special gsn functions", \ 
              "/Document/Graphics/Interfaces/"/) \
            /))
end

;----------------------------------------------------------------------
; This function reads the alphabetical web page for *all* NCL
; functions and procedures and produces a list of the names.
;
; Use "get_ncl_procs_and_funcs_by_cat" if you want to retrieve
; function/procedure names by catetory (gsn, built-in, contrib, etc).
;----------------------------------------------------------------------
undef("get_ncl_procs_and_funcs")
function get_ncl_procs_and_funcs()
local url, fname, lines, dq, line_search, new_lines, delim, ii 
begin
  fname = "list_alpha_browse.shtml"
  if(GET_FROM_WEB) then
;---Remove local file first.
    system("/bin/rm " + fname)
    url = "http://www.ncl.ucar.edu/Document/Functions/"
    system("wget " + (url+fname))
  end if
  lines = asciiread(fname,-1,"string")
;
; Get just the strings that contain the func/proc names
;
;   The line we want contains:
;
;      <a href="/Document/XXXXX/YYYY/funcproc_name.shtml"...
;
  dq          = str_get_dq()
  line_search = "^<a href=" + dq + "/Document/"
  ii          = str_match_ind(lines,line_search)
  new_lines   = lines(ii)

;---Split out the function/procedure names
  delim = "/."
  names = str_get_field(new_lines,5,delim)
  return(names)
end

;----------------------------------------------------------------------
; This function reads the alphabetical web page for the given category
; type of NCL functions and procedures and produces a list of the 
; names. Use "get_ncl_procs_and_funcs" if you just want one giant
; list of function/procedure names, regardless of category.
;----------------------------------------------------------------------
undef("get_ncl_procs_and_funcs_by_cat")
function get_ncl_procs_and_funcs_by_cat(cat_name)
local url, fname, lines, dq, line_search, new_lines, delim, ii 
begin
  fname = "list_alpha_browse.shtml"
  if(GET_FROM_WEB)  then
;---Remove local file first.
    system("/bin/rm " + fname)
    url = "http://www.ncl.ucar.edu/Document/Functions/"
    system("wget " + (url+fname))
  end if
  names = get_valid_cat_names()
  lines = asciiread(fname,-1,"string")
;
; Get just the strings that contain the func/proc names for
; the given category.
;
;   The line we want contains:
;
;      <a href="/Document/XXXXX/YYYY/funcproc_name.shtml"...
;
  icat = ind(cat_name.eq.names(:,0))
  if(ismissing(icat)) then
    print("get_ncl_procs_and_funcs_by_cat: invalid category")
    return(new(1,string))
  end if

;;;;This part still needs work!!
  dq          = str_get_dq()
  line_search = "^<a href=" + dq + names(icat,2)
  ii          = str_match_ind(lines,line_search)
  new_lines   = lines(ii)

;---Split out the function/procedure names
  delim = "/."
  fnames = str_get_field(new_lines,5,delim)
  return(fnames)
end

;----------------------------------------------------------------------
; This function reads the alphabetical web page for NCL resources
; and produces a list of just the resource names.
;----------------------------------------------------------------------
undef("get_ncl_resources")
function get_ncl_resources()
local url, fname, lines, dq, tab, line_search, new_lines, delim, names
begin
  fname = "list_alpha_res.shtml"
  if(GET_FROM_WEB)  then
;---Remove local file first.
    system("/bin/rm " + fname)
    url = "http://www.ncl.ucar.edu/Document/Graphics/Resources/"
    system("wget " + (url+fname))
  end if
  lines = asciiread(fname,-1,"string")
;
; Get just the strings that contain the resource names
;
;   The line we want contains:
;
;      <a name="resource_name"></a><strong>resource_name</strong>
;
  dq          = str_get_dq()
  tab         = str_get_tab()
  line_search = dq + "></a><strong>"
  ii          = str_match_ind(lines,line_search)
  new_lines   = lines(ii)
;
; We want the part between <strong> and </strong>, but we can't
; use str_get_field for this, because you can only use a single
; character as a delimiter. So, convert these to single tabs,
; and use tab as a delimiter.
;
  new_lines = str_sub_str(new_lines,"<strong>",tab)
  new_lines = str_sub_str(new_lines,"</strong>",tab)

;---Split out the resource names
  delim = tab
  names = str_get_field(new_lines,2,delim)
  return(names)
end

;----------------------------------------------------------------------
; This function reads the reference page for NCL keywords
; produces a list of them.
;----------------------------------------------------------------------
undef("get_ncl_keywords")
function get_ncl_keywords()
local url, fname, lines, dq, line_search, new_lines, delim, names
begin
  fname = "NclKeywords.shtml"
  if(GET_FROM_WEB)  then
;---Remove local file first.
    system("/bin/rm " + fname)
    url   = "http://www.ncl.ucar.edu/Document/Manuals/Ref_Manual/"
    system("wget " + (url+fname))
  end if
  lines = asciiread(fname,-1,"string")
 
;
; Get just the strings that contain the keyword names
;
;   The line we want contains:
;
;   "        <a href="....">keyword_name</a>"
;
  dq          = str_get_dq()
  line_search = "        <a href=" + dq
  ii          = str_match_ind(lines,line_search)
  new_lines   = lines(ii)

;---Split out the keyword names
  delim = "<>"
  names = str_get_field(new_lines,3,delim)
  return(names)
end

;----------------------------------------------------------------------
; This function returns the list NCL operators.
;----------------------------------------------------------------------
undef("get_ncl_operators")
function get_ncl_operators()
begin
;
; We don't have an official page of operators, so just list them here.
;
; I'm not sure what to call an "operator". Is '{' an operator?
; Note I didn't include characters like '(' and '['.
;
;  operators = (/"!","|","$","&","@","-","^","*","/","%","#","+","-","<",">",\
;                "{","}","(/","/)","[\","/]","\",\
;                ".eq.",".ne.",".lt.",".le.",".gt.",".ge.",".and.", \
;                ".or.",".not.",".xor."/)

  operators = (/"(/","/)","\",".eq.",".ne.",".lt.",".le.",".gt.",\
                ".ge.",".and.",".or.",".not.",".xor."/)
  return(operators)
end
