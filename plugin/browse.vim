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
	if len(main_guifg) ># 0
		let guifg = main_guifg
	elseif secondary_guifg !=# ""
		let guifg = secondary_guifg
	else
		let guifg = ""
	endif
	if guifg ==# ""
		let guifg = "NONE"
	endif
	let main_guibg = s:return_highlight_term(a:main, "guibg")
	let secondary_guibg = s:return_highlight_term(a:secondary, "guibg")
	if main_guibg !=# ""
		let guibg = main_guibg
	elseif secondary_guibg !=# ""
		let guibg = secondary_guibg
	else
		let guibg = ""
	endif
	if guibg ==# ""
		let guibg = "NONE"
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
	execute "hi" a:destination "guifg=".guifg "guibg=".guibg "gui=".gui
endfunction

function! s:escape(str)
	if a:str ==# 'lt' || a:str ==# 'LT'
		return '<'
	endif
	if a:str ==# 'gt' || a:str ==# 'GT'
		return '>'
	endif
	if a:str ==# 'amp' || a:str ==# 'AMP'
		return '&'
	endif
	if a:str ==# 'quot' || a:str ==# 'QUOT'
		return '"'
	endif
	if a:str =~# '#[0-9]\+'
		return nr2char(strpart(a:str, 1))
	endif
	return v:null
endfunction

function! s:parse_args(args)
	let result = {}
	let state = 'default'
	let key = ''
	let value = v:null
	let i = 0
	let len = len(a:args)
	while i < len
		let c = a:args[i]
		if state ==# 'default'
			if c ==# '='
				let state = 'value'
				let value = ''
			elseif charclass(c) ==# 2
				let key .= c
			elseif charclass(c) ==# 0
			else
				let state = 'error'
			endif
		elseif state ==# 'value'
			if c ==# '"'
				let state = 'string'
			elseif charclass(c) !=# 0
				let value .= c
			else
				let state = 'default'
				let result[key] = value
				let value = v:null
				let key = ''
			endif
		elseif state ==# 'string'
			if c ==# '"'
				let state = 'default'
				let result[key] = value
				let value = v:null
				let key = ''
			else
				let value .= c
			endif
		endif
		let i += 1
	endwhile
	return result
endfunction

function! browse#generate_page(document_text)
	let page = []
	let page_line = []
	let state = 'default'
	let escaping = v:null
	let escaped = v:false
	let hl_stack = ['Normal']
	let type_stack = ['default']
	let add_space = v:null
	let add_newline = v:null
	let args = {}
	let document_text_len = len(a:document_text)
	let page_line_len = 0
	let l_idx = 0
	while l_idx < document_text_len
		let line = a:document_text[l_idx]
		let c_idx = 0
		while c_idx < len(line)
			let c = line[c_idx]
			if escaping !=# v:null
				let e = s:escape(escaping)
				if c ==# ';'
					let escaping = v:null
					if e ==# v:null
						let line = strpart(line, 0, c_idx).'&'.escaping.strpart(line, c_idx+1, len(line)-c_idx-1)
					else
						let line = strpart(line, 0, c_idx).e.strpart(line, c_idx+1, len(line)-c_idx-1)
					endif
					let escaped = v:true
				elseif charclass(c) !=# 2
					let line .= '&'.escaping.c
					let escaping = v:null
					if e ==# v:null
						let line = strpart(line, 0, c_idx).'&'.escaping.c.strpart(line, c_idx+1, len(line)-c_idx-1)
					else
						let line = strpart(line, 0, c_idx).e.strpart(line, c_idx+1, len(line)-c_idx-1)
					endif
				else
					if e ==# v:null
						let escaping .= c
						let line = strpart(line, 0, c_idx).strpart(line, c_idx+1, len(line)-c_idx-1)
					else
						let escaping = v:null
						let line = strpart(line, 0, c_idx).e.strpart(line, c_idx+1, len(line)-c_idx-1)
					endif
				endif
				unlet e
				continue
			endif
			if c ==# '&' && !escaped
				let line = strpart(line, 0, c_idx).strpart(line, c_idx+1, len(line)-c_idx-1)
				let escaping = ''
				continue
			endif
			let local_escaped = escaped
			let escaped = v:false
			if v:false
			elseif state ==# 'comment'
				if c ==# '>' && !local_escaped
					let state = 'default'
					let line = strpart(line, c_idx + 1)
					let c_idx = 0
					continue
				endif
			elseif state ==# 'default'
				if c ==# '<' && !local_escaped
					let state = 'opening_triangular_bracket'
				endif
			elseif state ==# 'opening_triangular_bracket'
				if c ==# '!'
					let state = 'comment'
					let opts = {}
					let val = strpart(line, 0, c_idx-1)
					if len(val) <# 1
						let add_space_before = v:false
						let add_space_after = v:false
					else
						let add_space_before = charclass(val[0]) ==# 0
						let add_space_after = charclass(val[len(val)-1]) ==# 0
						let add_space_after += l_idx <# document_text_len + 1
					endif
					if add_newline !=# v:null
						let page_line_len = 0
						let page += [page_line]
						let page_line = []
						let add_newline = v:null
					elseif add_space !=# v:null && !add_space_before
						let opts2 = {}
						let opts2['val'] = ' '
						let page_line_len += 1
						let opts2['hl'] = add_space
						let opts2['args'] = {}
						let opts2['type'] = 'default'
						let page_line += [opts2]
						unlet opts2
						let add_space = v:null
					endif
					let val = split(val)
					let val = join(val, ' ')
					let opts['val'] = val
					unlet val
					if add_space_before && page_line_len ># 0
						let opts['val'] = ' '.opts['val']
					endif
					let page_line_len += len(opts['val'])
					let line = strpart(line, c_idx)
					let c_idx = 0
					let opts['hl'] = hl_stack[-1]
					if add_space_after
						let add_space = opts['hl']
					endif
					call remove(hl_stack, -1)
					if len(hl_stack) <# 1
						let hl_stack += ['Normal']
					endif
					let opts['args'] = args
					let opts['type'] = type_stack[-1]
					let args = {}
					let page_line += [opts]
					continue
				elseif c ==# '/'
					let state = 'tag_close_name'
					let opts = {}
					let val = strpart(line, 0, c_idx-1)
					if len(val) <# 1
						let add_space_before = v:false
						let add_space_after = v:false
					else
						let add_space_before = charclass(val[0]) ==# 0
						let add_space_before *= page_line_len ># 0
						let add_space_after = charclass(val[len(val)-1]) ==# 0
						let add_space_after *= l_idx <# document_text_len + 1
					endif
					if add_newline !=# v:null
						let page_line_len = 0
						let page += [page_line]
						let page_line = []
						let add_newline = v:null
					elseif add_space !=# v:null && !add_space_before
						let opts2 = {}
						let opts2['val'] = ' '
						let page_line_len += 1
						let opts2['hl'] = add_space
						let opts2['args'] = args
						let opts2['type'] = 'default'
						let page_line += [opts2]
						unlet opts2
						let add_space = v:null
					endif
					let val = split(val)
					let val = join(val, ' ')
					let opts['val'] = val
					unlet val
					if add_space_before && page_line_len ># 0
						let opts['val'] = ' '.opts['val']
					endif
					let page_line_len += len(opts['val'])
					let line = strpart(line, c_idx)
					let c_idx = 0
					let opts['hl'] = hl_stack[-1]
					if add_space_after
						let add_space = opts['hl']
					endif
					call remove(hl_stack, -1)
					if len(hl_stack) <# 1
						let hl_stack += ['Normal']
					endif
					let opts['args'] = args
					let opts['type'] = type_stack[-1]
					let args = {}
					let page_line += [opts]
					continue
				elseif charclass(c) !=# 2
					let state = 'default'
				else
					let state = 'tag_open_name'
					let opts = {}
					let val = strpart(line, 0, c_idx-1)
					if len(val) <# 1
						let add_space_before = v:false
						let add_space_after = v:false
					else
						let add_space_before = charclass(val[0]) ==# 0
						let add_space_after = charclass(val[len(val)-1]) ==# 0
						let add_space_after *= l_idx < document_text_len + 1
					endif
					if add_newline !=# v:null
						let page_line_len = 0
						let page += [page_line]
						let page_line = []
						let add_newline = v:null
					elseif add_space !=# v:null && !add_space_before
						let opts2 = {}
						let opts2['val'] = ' '
						let page_line_len += 1
						let opts2['hl'] = add_space
						let opts2['args'] = {}
						let opts2['type'] = 'default'
						let page_line += [opts2]
						unlet opts2
						let add_space = v:null
					endif
					let val = split(val)
					let val = join(val, ' ')
					let opts['val'] = val
					if add_space_before && page_line_len ># 0
						let opts['val'] = ' '.opts['val']
					endif
					unlet val
					let page_line_len += len(opts['val'])
					let line = strpart(line, c_idx)
					let c_idx = 0
					let opts['hl'] = hl_stack[-1]
					if add_space_after
						let add_space = opts['hl']
					endif
					let opts['args'] = args
					let opts['type'] = type_stack[-1]
					let args = {}
					let page_line += [opts]
					continue
				endif
			elseif state ==# 'tag_open_name'
				if c ==# '>'
					let state = 'default'
					let before_bracket = strpart(line, 0, c_idx)
					let before_bracket = trim(before_bracket)
					let tag_name = split(before_bracket, ' ')[0]
					let args = join(split(before_bracket)[1:], " ")
					let args = s:parse_args(args)
					if v:false
					elseif tag_name ==? 'strong'
						let hl = 'BrowseNvim_Strong'
						let type_stack += ['default']
						let add_newline = v:null
					elseif tag_name ==? 'i'
						let hl = 'BrowseNvim_Italic'
						let type_stack += ['default']
						let add_newline = v:null
					elseif tag_name ==? 'em'
						let hl = 'BrowseNvim_Italic'
						let type_stack += ['default']
						let add_newline = v:null
					elseif tag_name ==? 'img'
						let hl = 'Normal'
						let type_stack += ['image']
						let add_newline = hl
					elseif v:false
					\|| tag_name ==? 'h1'
					\|| tag_name ==? 'h2'
					\|| tag_name ==? 'h3'
					\|| tag_name ==? 'h4'
					\|| tag_name ==? 'h5'
					\|| tag_name ==? 'h6'
						let hl = 'Title'
						let type_stack += ['default']
						let add_newline = hl
					elseif v:false
					\|| tag_name ==? 'div'
					\|| tag_name ==? 'p'
						let hl = 'Normal'
						let type_stack += ['default']
						let add_newline = hl
					elseif tag_name ==? 'br'
						let hl = 'Normal'
						let type_stack += ['default']
						let add_newline = hl
					else
						let hl = 'Normal'
						let type_stack += ['default']
						let add_newline = v:null
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
		if line !=# '' && state !=# 'comment'
			let opts = {}
			if len(line) <# 1
				let add_space_before = v:false
				let add_space_after = v:false
			else
				let add_space_before = charclass(line[0]) ==# 0
				let add_space_after = charclass(line[len(line)-1]) ==# 0
				let add_space_after *= l_idx <# document_text_len + 1
			endif
			if add_newline !=# v:null
				let page_line_len = 0
				let page += [page_line]
				let page_line = []
				let add_newline = v:null
			elseif add_space !=# v:null && !add_space_before
				let opts2 = {}
				let opts2['val'] = ' '
				let page_line_len += 1
				let opts2['hl'] = add_space
				let opts2['args'] = {}
				let opts2['type'] = 'default'
				let page_line += [opts2]
				unlet opts2
				let add_space = v:null
			endif
			let val = split(line)
			let val = join(val, ' ')
			let opts['val'] = val
			if add_space_before && page_line_len ># 0
				let opts['val'] = ' '.opts['val']
			endif
			unlet val
			let page_line_len += len(opts['val'])
			let opts['hl'] = hl_stack[-1]
			if add_space_after
				let add_space = opts['hl']
			endif
			call remove(hl_stack, -1)
			if len(hl_stack) <# 1
				let hl_stack += ['Normal']
			endif
			let opts['args'] = args
			let opts['type'] = type_stack[-1]
			let args = {}
			let page_line += [opts]
		endif
		let l_idx += 1
	endwhile
	if page_line !=# []
		let page += [page_line]
	endif
	return page
endfunction

function! browse#render_page(document_text, bufnr, ns_id)
	let linecount = len(a:document_text)
	let page = browse#generate_page(a:document_text)
	let line_index = 0
	let line_count = len(page)
	while line_index < line_count
		mode
		let line = page[line_index]
		call setline(line_index+1, '')
		for item in line
			let old_line = getline(line_index+1)
			let hl_start = len(old_line)
			let type = item['type']
			if v:false
			elseif type ==# 'default'
				let text = item['val']
				let hl = item['hl']
			elseif type ==# 'image'
				let text = 'Image loading...'
				let hl = 'BrowseNvim_Italic'
			endif
			call nvim_buf_set_text(a:bufnr, line_index, hl_start, line_index, hl_start, [text])
			let hl_end = hl_start + len(text)
			if hl !=# 'Normal'
				call nvim_buf_add_highlight(a:bufnr, a:ns_id, hl, line_index, hl_start, hl_end)
			endif
		endfor
		let line_index += 1
	endwhile
	return page
endfunction

function! browse#render_other_elements(filename, bufnr, page)
	let i = 0
	let pagelen = len(a:page)
	while i < pagelen
		let page_line = a:page[i]
		for item in page_line
			let val = item['val']
			let args = item['args']
			let hl = item['hl']
			let type = item['type']
			if v:false
			elseif type ==# 'default'
			elseif type ==# 'image'
				let alt = get(args, 'alt', v:null)
				let src = get(args, 'src', v:null)
				let error = v:false

				if src ==# v:null
					let error = v:true
				else
					let src = fnamemodify(a:filename, ':h').'/'.src
					if !filereadable(src)
						let error = v:true
					endif
				endif

				setlocal modifiable

				execute i + 1.'delete'
				if error
					if alt ==# v:null
						let text = 'Unable to load image'
					else
						let text = 'Unable to load image: '.alt
					endif
					call append(i, [text])
					unlet text
				else
					call image#portable_pixmap#read(src, v:false, i)
				endif

				setlocal nomodifiable
				setlocal nomodified
				unlet error
				unlet alt
			endif
		endfor
		let i += 1
	endwhile
endfunction

function! browse#quit(bufnr, ns_id)
	call nvim_buf_clear_namespace(a:bufnr, a:ns_id, 0, line('$')-1)
	quit
endfunction

function! browse#add_mappings(ns_id)
	execute "noremap <buffer> q <cmd>call browse#quit(bufnr(), ".a:ns_id.")<cr>"
endfunction

function! browse#open_page(filename, document_text)
	new
	setlocal buftype=nofile
	setlocal bufhidden=hide
	setlocal noswapfile
	setlocal undolevels=-1
	setlocal nomodeline
	setlocal filetype=
	setlocal wrap
	setlocal linebreak
	setlocal nolist
	setlocal nonumber
	setlocal norelativenumber
	let bufnr = bufnr()
	let ns_id = nvim_create_namespace('browse-nvim-'.g:browse_page_id)
	let page = browse#render_page(a:document_text, bufnr, ns_id)
	call timer_start(0, {->browse#render_other_elements(a:filename, bufnr, page)})
	call browse#add_mappings(ns_id)
	setlocal nomodified
	setlocal nomodifiable
	let g:browse_page_id += 1
	return bufnr
endfunction

function! browse#open_file(filename)
	let document_text = readfile(expand(a:filename))
	return browse#open_page(a:filename, document_text)
endfunction
