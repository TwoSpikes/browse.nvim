function! browse#setup()
	let g:browse_page_id = 0
	hi BrowseNvim_Strong ctermfg=NONE ctermbg=NONE cterm=bold guifg=NONE guibg=NONE
	if has('nvim') || has('gui_running')
		hi BrowseNvim_Strong gui=bold
	endif
	hi BrowseNvim_Italic ctermfg=NONE ctermbg=NONE cterm=italic guifg=NONE guibg=NONE
	if has('nvim') || has('gui_running')
		hi BrowseNvim_Italic gui=italic
	endif
endfunction

function! browse#generate_page(document_text)
	let page = []
	let state = 'default'
	let hl_stack = ['Normal']
	for line in a:document_text
		let page_line = []
		let c_idx = 0
		while c_idx < len(line)
			echomsg "hl_stack:".string(hl_stack).";"
			let c = line[c_idx]
			if v:false
			elseif state ==# 'default'
				if c ==# '<'
					let state = 'opening_triangular_bracket'
				endif
			elseif state ==# 'opening_triangular_bracket'
				if c ==# '/'
					let state = 'tag_close_name'
					let opts = {}
					let val = strpart(line, 0, c_idx-1)
					let val = trim(val)
					let opts['val'] = val
					unlet val
					let line = strpart(line, c_idx)
					let c_idx = 0
					let opts['hl'] = hl_stack[-1]
					call remove(hl_stack, -1)
					if len(hl_stack) <# 1
						let hl_stack += ['Normal']
					endif
					let page_line += [opts]
					continue
				elseif charclass(c) !=# 2
					let state = 'default'
				else
					let state = 'tag_open_name'
					let opts = {}
					let val = strpart(line, 0, c_idx-1)
					let val = trim(val)
					let opts['val'] = val
					unlet val
					let line = strpart(line, c_idx)
					let c_idx = 0
					let opts['hl'] = hl_stack[-1]
					let page_line += [opts]
					continue
				endif
			elseif state ==# 'tag_open_name'
				if c ==# '>'
					let state = 'default'
					let tag_name = strpart(line, 0, c_idx)
					let tag_name = trim(tag_name)
					let tag_name = split(tag_name, ' ')[0]
					if v:false
					elseif tag_name ==? 'strong'
						let hl = 'BrowseNvim_Strong'
					elseif tag_name ==? 'i'
						let hl = 'BrowseNvim_Italic'
					else
						let hl = 'Normal'
					endif
					let hl_stack += [hl]
					let line = strpart(line, c_idx+1)
					let c_idx = 0
					continue
				endif
			elseif state ==# 'tag_close_name'
				if c ==# '>'
					let state = 'default'
					let tag_name = strpart(line, 0, c_idx)
					let tag_name = trim(tag_name)
					let tag_name = split(tag_name, ' ')[0]
					let line = strpart(line, c_idx+1)
					let c_idx = 0
					continue
				endif
			endif
			let c_idx += 1
		endwhile
		if line !=# ''
			let opts = {}
			let val = trim(line)
			let opts['val'] = val
			unlet val
			let opts['hl'] = hl_stack[-1]
			call remove(hl_stack, -1)
			if len(hl_stack) <# 1
				let hl_stack += ['Normal']
			endif
			let page_line += [opts]
		endif
		let page += [page_line]
	endfor
	return page
endfunction

function! browse#render_page(document_text, bufnr, ns_id)
	let g:browse_page_id += 1
	let linecount = len(a:document_text)
	let page = browse#generate_page(a:document_text)
	echomsg "page is:".string(page).";"
	let line_index = 0
	let line_count = len(page)
	while line_index < line_count
		let line = page[line_index]
		call setline(line_index+1, '')
		for item in line
			let old_line = getline(line_index+1)
			let hl_start = len(old_line)
			call nvim_buf_set_text(a:bufnr, line_index, hl_start, line_index, hl_start, [item['val']])
			let hl_end = hl_start + len(item['val'])
			if item['hl'] !=# 'Normal'
				call nvim_buf_add_highlight(a:bufnr, a:ns_id, item['hl'], line_index, hl_start, hl_end)
			endif
		endfor
		let line_index += 1
	endwhile
endfunction

function! browse#open_page(document_text)
	new
	setlocal buftype=nofile
	setlocal bufhidden=hide
	setlocal noswapfile
	setlocal undolevels=-1
	setlocal nomodeline
	setlocal filetype=
	let bufnr = bufnr()
	let ns_id = nvim_create_namespace('browse-nvim-'.g:browse_page_id)
	call browse#render_page(a:document_text, bufnr, ns_id)
	setlocal nomodified
	setlocal nomodifiable
	return bufnr
endfunction

function! browse#open_file(filename)
	let document_text = readfile(expand(a:filename))
	return browse#open_page(document_text)
endfunction
