;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; gen_vim_syntax.ncl
;; Carl Schreck (carl@cicsnc.org)
;; ftp://filsrv.cicsnc.org/carl/ncl-vim/
;; August 2012
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Description: Create a vim syntax file for ncl
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "gen_editor_utils.ncl"

begin

  ;; These are some parameters that could be useful to have up top
  headerFile = "ncl_header.vim"
  footerFile = "ncl_footer.vim"
  outFile    = "ncl3.vim"

  boilerPlate = \
      (/ str_get_dq() + " Vim syntax File", \
         str_get_dq() + " Language: NCL",   \
         str_get_dq() + " Author:   Carl Schreck (carl@cicsnc.org)",   \
         str_get_dq() + " Based on previous versions by Kevin Mueller and Arindam Chakraborty",  \
         str_get_dq() + " Updated " + systemfunc("date"), \
         "" \
      /)

  header = asciiread( headerFile, -1, "string" )
  footer = asciiread( footerFile, -1, "string" )

  cat_names = get_valid_cat_names()
  procs_and_funcs = new( dimsizes( cat_names(:,0) ) , string )
  do i = 0, dimsizes(procs_and_funcs)-1
    currFuncList = get_ncl_procs_and_funcs_by_cat( cat_names(i,0) )
    procs_and_funcs(i) = "syn keyword ncl" + str_upper( cat_names(i,0) ) + " " \
      + str_join( currFuncList, " " )
    delete(currFuncList)
  end do
  
  resList   = get_ncl_resources()
  resources = "syn keyword nclResource " + str_join( resList, " " )
  keyList   = get_ncl_keywords()
  keywords  = "syn keyword nclKeyword " + str_join( keyList, " " )

  ;; put it all together
  out0 = array_append_record( boilerPlate, header, 0 ) 
  out1 = array_append_record( out0, procs_and_funcs, 0 ) 
  out2 = array_append_record( out1, resources, 0 ) 
  out3 = array_append_record( out2, keywords, 0 ) 
  out4 = array_append_record( out3, footer, 0 ) 

  output = out4
  asciiwrite( outFile, output )

end
