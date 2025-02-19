function! image#portable_pixmap#setup()
	let g:image_portable_pixmap_id = 0
endfunction

function! s:is_highlight_group_defined(group)
	silent! let output = execute('hi '.a:group)
	return output !~# 'E411:' && output !~# 'cleared'
endfunction

let s:HEX_TABLE=['0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F']
function! s:nr2hex_888(n) abort
	return s:HEX_TABLE[a:n / 16] . s:HEX_TABLE[a:n % 16]
endfunction
function! s:nr2hex_444(n) abort
	return repeat(s:HEX_TABLE[a:n], 2)
endfunction
function! s:rgb_to_hex(max, r, g, b) abort
	if a:max ==# 0xFF
		return '#'.s:nr2hex_888(a:r).s:nr2hex_888(a:g).s:nr2hex_888(a:b)
	endif
	if a:max ==# 0xF
		return '#'.s:nr2hex_444(a:r).s:nr2hex_444(a:g).s:nr2hex_444(a:b)
	endif
	return v:null
endfunction

function! image#portable_pixmap#read(filename, newbuffer=v:true, insert_in_line=0)
	let lines = readfile(expand(a:filename))
	if len(lines) <# 3
		echohl ErrorMsg
		echomsg "Unable to read image"
		echohl Normal
		return
	endif
	let format = lines[0]
	if format !=# 'P3' && format !=# 'P6'
		echohl ErrorMsg
		echomsg "Unknown format: ".format
		echohl Normal
		return
	endif
	let start = 1
	while start < len(lines)
		if len(lines[start]) <# 1
			echohl ErrorMsg
			echomsg "Unable to read image: empty line"
			echohl Normal
			return
		endif
		if lines[start][0] !=# '#'
			break
		endif
		let start += 1
	endwhile
	let size = split(lines[start])
	if len(size) <# 2
		echohl ErrorMsg
		echomsg "Unable to read image size"
		echohl Normal
		return
	endif
	let cols = str2nr(size[0])
	let rows = str2nr(size[1])
	unlet size
	if format ==# "P3"
		if len(lines) <# rows + start + 2
			echohl ErrorMsg
			echomsg "Unable to read image: not enough lines"
			echohl Normal
			return
		endif
	endif
	if cols ==# 0 || rows ==# 0
		return
	endif
	let maxvalue = str2nr(lines[start + 1])
	if a:newbuffer
		new
		setlocal buftype=nofile
		setlocal bufhidden=hide
		setlocal noswapfile
		setlocal undolevels=-1
		setlocal nonumber
		setlocal norelativenumber
		setlocal nowrap
		setlocal nomodeline
		setlocal filetype=
		setlocal nolist
	endif
	call append(a:insert_in_line, repeat([repeat('#', cols)], rows))
	if a:newbuffer
		execute a:insert_in_line + 1 + rows.'delete'
		setlocal nomodifiable
		setlocal nomodified
		execute a:insert_in_line + 1
	endif
	let ns_id = nvim_create_namespace('ppm-image-'.g:image_portable_pixmap_id)
	if a:newbuffer
		call s:add_mappings(ns_id)
	endif
	let bufnr = bufnr()
	if format ==# "P6"
		let colors_line = join(lines[start + 2:], "\n")
	endif
	let line = 0
	let i = 0
	while i < rows
		if v:false
		elseif format ==# "P3"
			let file_line = lines[i + start + 2]
			let colors = split(file_line)
		elseif format ==# "P6"
			let file_line = strpart(colors_line, i*cols*3, cols*3)
			let colors = []
			let j = 0
			while j < len(file_line)
				let colors += [char2nr(file_line[j])]
				let j += 1
			endwhile
			unlet j
		else
			echohl ErrorMsg
			echomsg "Internal error: Unknown format: ".format
			echohl Normal
			return
		endif
		let colors_in_line = len(colors)
		if colors_in_line <# cols
			echohl ErrorMsg
			echomsg "Unable to read image: not enough row data"
			echohl Normal
			return
		endif
		unlet colors_in_line
		let j = 0
		while j < cols * 3
			let col = j / 3 + 1
			let r = colors[j]
			let g = colors[j + 1]
			let b = colors[j + 2]
			let hlgroupname = 'PPM_'.r.'_'.g.'_'.b
			if !s:is_highlight_group_defined(hlgroupname)
				let hex = s:rgb_to_hex(maxvalue, r, g, b)
				if hex ==# v:null
					echohl ErrorMsg
					echomsg "Unable to read image: cannot convert rgb to hex"
					echohl Normal
					return
				endif
				execute 'hi' hlgroupname 'guifg=NONE' 'guibg='.hex 'gui=NONE'
			endif
			call nvim_buf_add_highlight(bufnr, ns_id, hlgroupname, line, col-1, col)
			unlet hlgroupname
			unlet r
			unlet g
			unlet b
			let j += 3
		endwhile
		let i += 1
		let line += 1
	endwhile
	let g:image_portable_pixmap_id += 1
	if a:newbuffer
		return bufnr
	else
		return ns_id
	endif
endfunction

function! s:quit(ns_id)
	call nvim_buf_clear_namespace(bufnr(), a:ns_id, 0, line('$')-1)
endfunction

function! s:add_mappings(ns_id)
	execute "noremap <buffer> q <cmd>call <sid>quit(".a:ns_id.")<cr>"
endfunction
