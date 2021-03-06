" Vim test
nmap <leader>tn :TestNearest<CR>
nmap <leader>tf :TestFile<CR>
nmap <leader>ta :TestSuite<CR>
nmap <leader>tl :TestLast<CR>
nmap <leader>tv :TestVisit<CR>
 
let test#strategy = "neovim"
let g:test#preserve_screen = 1

if has('nvim')
  tmap <C-o> <C-\><C-n>
endif

let g:test#javascript#jest#executable = 'jest --config ./**/jest.conf.js'
