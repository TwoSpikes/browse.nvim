function! browse#setup()
	let g:browse_page_id = 0
	hi BrowseNvim_Strong ctermfg=NONE ctermbg=NONE cterm=bold guifg=NONE guibg=NONE
	if has('nvim') || has('gui_running')
		hi BrowseNvim_Strong gui=bold
	endif
endfunction

function! browse#generate_page(document_text)
	let page = []
	let strong_enabled = v:false
	for line in a:document_text
		let page_line = []
		if line =~# '<strong>'
			if !strong_enabled
				let match = match(line, '<strong>')
				let opts = {}
				let opts['hl'] = 'Normal'
				let opts['val'] = strpart(line, 0, match)
				let page_line += [opts]
				let line = strpart(line, match+8)
				let strong_enabled = v:true
			endif
		endif
		if line =~# '</strong>'
			if strong_enabled
				let opts = {}
				let match = match(line, '</strong>')
				let opts['val'] = strpart(line, 0, match)
				let opts['hl'] = 'BrowseNvim_Strong'
				let page_line += [opts]
				let strong_enabled = v:false
				let line = strpart(line, match+9)
			endif
		endif
		if line !=# ''
			let opts = {}
			let opts['val'] = line
			if strong_enabled
				let strong_enabled = v:false
				let opts['hl'] = 'BrowseNvim_Strong'
			else
				let opts['hl'] = 'Normal'
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
	let line_index = 0
	let line_count = len(page)
	while line_index < line_count
		let line = page[line_index]
		call setline(line_index+1, '')
		for item in line
			let old_line = getline(line_index+1)
			let hl_start = len(old_line)
			call setline(line_index+1, old_line.item['val'])
			let hl_end = len(getline(line_index+1))
			call nvim_buf_add_highlight(a:bufnr, a:ns_id, item['hl'], line_index, hl_start, hl_end)
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
