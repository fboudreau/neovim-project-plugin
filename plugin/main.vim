



" Global Variables
if !exists('project_file_name')
    let project_file_name = '.vim_project'
endif


" Section: Functions {{{1
" Autosave only when there is something to save. Always saving makes build
" watchers crazy
function! SaveIfUnsaved()
    if &modified
        :silent! w
    endif
endfunction

au FocusLost,BufLeave,InsertLeave * :call SaveIfUnsaved()
" Read the file on focus/buffer enter
au FocusGained,BufEnter * :silent! !

" Section: Maps {{{1
" Allows pressing Esc to exit insert mode when in terminal (:h term)
tnoremap <Esc> <C-\><C-n>

" vim600: set foldmethod=marker foldlevel=0 :
