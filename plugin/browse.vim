function! browse#setup()
	let g:browse_page_id = 0
	let g:browse_highlight_max_id = 0
	hi BrowseNvim_Strong ctermfg=NONE ctermbg=NONE cterm=bold guifg=NONE guibg=NONE
	if has('nvim') || has('gui_running')
		hi BrowseNvim_Strong gui=bold
	endif
	hi BrowseNvim_Italic ctermfg=NONE ctermbg=NONE cterm=italic guifg=NONE guibg=NONE
	if has('nvim') || has('gui_running')
		hi BrowseNvim_Italic gui=italic
	endif
endfunction

function! s:return_highlight_term(group, term)
   " Store output of group to variable
   let output = execute('hi ' . a:group)

   " Find the term we're looking for
   return matchstr(output, a:term.'=\zs\S*')
endfunction
function! s:merge_colors(first, second)
	let first = str2nr(a:first[1:], 16)
	let second = str2nr(a:second[1:], 16)
	let first_r = and(first, 0xFF0000) / 65536
	let second_r = and(second, 0xFF0000) / 65536
	let first_g = and(first, 0x00FF00) / 256
	let second_g = and(second, 0x00FF00) / 256
	let first_b = and(first, 0x0000FF)
	let second_b = and(second, 0x0000FF)
	let r = (first_r + second_r) / 2
	let g = (first_g + second_g) / 2
	let b = (first_b + second_b) / 2
	let color = printf("%06x", r * 65536 + g * 256 + b)
	return color
endfunction
function! s:merge_highlight_groups(main, secondary, destination)
	let main_guifg = s:return_highlight_term(a:main, "guifg")
	let secondary_guifg = s:return_highlight_term(a:secondary, "guifg")
	if main_guifg ==# ""
		let guifg = secondary_guifg
	elseif secondary_guifg ==# ""
		let guifg = main_guifg
	else
		let guifg = s:merge_colors(main_guifg, secondary_guifg)
	endif
	let main_guibg = s:return_highlight_term(a:main, "guibg")
	let secondary_guibg = s:return_highlight_term(a:secondary, "guibg")
	if main_guibg ==# ""
		let guibg = secondary_guibg
	elseif secondary_guibg ==# ""
		let guibg = s:merge_colors(main_guibg, secondary_guibg)
	endif
	let main_gui = s:return_highlight_term(a:main, "gui")
	let secondary_gui = s:return_highlight_term(a:secondary, "gui")
	let main_gui = split(main_gui, ",")
	let secondary_gui = split(secondary_gui, ",")
	let gui = main_gui
	let gui += secondary_gui
	call sort(gui)
	call uniq(gui)
	let gui = join(gui, ",")
	if guifg ==# ""
		let guifg = "NONE"
	endif
	if guibg ==# ""
		let guibg = "NONE"
	endif
	if gui ==# ""
		let gui = "NONE"
	endif
	execute "hi" a:destination "guifg=#".guifg "guibg=#".guibg "gui=".gui
endfunction

function! browse#generate_page(document_text)
	let page = []
	let state = 'default'
	let hl_stack = ['Normal']
	for line in a:document_text
		let page_line = []
		let c_idx = 0
		while c_idx < len(line)
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
					call s:merge_highlight_groups(hl, hl_stack[-1], 'BrowseNvim_Color_'.g:browse_highlight_max_id)
					let hl_stack += ['BrowseNvim_Color_'.g:browse_highlight_max_id]
					let g:browse_highlight_max_id += 1
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
			call nvim_buf_set_text(a:bufnr, line_index, hl_start, line_index, hl_start, [item['val']])
			let hl_end = hl_start + len(item['val'])
			if item['hl'] !=# 'Normal'
				call nvim_buf_add_highlight(a:bufnr, a:ns_id, item['hl'], line_index, hl_start, hl_end)
			endif
		endfor
		let line_index += 1
	endwhile
endfunction

function! browse#quit(bufnr, ns_id)
	call nvim_buf_clear_namespace(a:bufnr, a:ns_id, 0, line('$')-1)
	quit
endfunction

function! browse#add_mappings(ns_id)
	execute "noremap <buffer> q <cmd>call browse#quit(bufnr(), ".a:ns_id.")<cr>"
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
	call browse#add_mappings(ns_id)
	setlocal nomodified
	setlocal nomodifiable
	let g:browse_page_id += 1
	return bufnr
endfunction

function! browse#open_file(filename)
	let document_text = readfile(expand(a:filename))
	return browse#open_page(document_text)
endfunction
