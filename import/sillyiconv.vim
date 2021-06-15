vim9script

scriptencoding utf-8

def s:char2binary(c: string): list<bool>
	# echo s:char2binary('c')
	# [v:false, v:true, v:true, v:false ,v:false, v:false, v:true, v:true]
	var bits: list<bool> = [v:false, v:false, v:false, v:false, v:false, v:false, v:false, v:false]
	if len(c) == 1
		var n: number = 1
		for i in range(7, 0, -1)
			bits[i] = and(char2nr(c), n) != 0
			n *= 2
		endfor
	endif
	return bits
enddef

def s:count_1_prefixed(bits: list<bool>): number
	# echo s:count_1_prefixed([1,1,0,0 ,0,0,1,1])
	# 2
	var c: number = 0
	for b in bits
		if b
			c += 1
		else
			break
		endif
	endfor
	return c
enddef

export def IsUTF8(input: string): bool
	# http://tools.ietf.org/html/rfc3629

	var cs: string = input
	var i: number = 0
	while i < len(cs)
		var bits: list<bool> = s:char2binary(cs[i])
		var c: number = s:count_1_prefixed(bits)

		# 1 byte utf-8 char. this is asci char.
		if c == 0
			i += 1

			# 2~4 byte utf-8 char.
		elseif 2 <= c && c <= 4
			i += 1
			# consume b10...
			for _ in range(1, c - 1)
				bits = s:char2binary(cs[i])
				c = s:count_1_prefixed(bits)
				if c == 1
					# ok
				else
					# not utf-8
					return v:false
				endif
				i += 1
			endfor
		else
			# not utf-8
			return v:false
		endif
	endwhile
	return v:true
enddef

export def IsEUCJP(input: string): bool
	# http://charset.7jp.net/euc.html
	
	var cs: string = input
	var i: number = 0
	while i < len(cs)
		if 0x00 <= char2nr(cs[i]) && char2nr(cs[i]) <= 0x7f
			i += 1
		elseif 0xa1 <= char2nr(cs[i]) && char2nr(cs[i]) <= 0xfe
			i += 1
			if 0xa1 <= char2nr(cs[i]) && char2nr(cs[i]) <= 0xfe
				i += 1
			else
				return v:false
			endif
		elseif 0x8e == char2nr(cs[i])
			i += 1
			if 0xa1 <= char2nr(cs[i]) && char2nr(cs[i]) <= 0xdf
				i += 1
			else
				return v:false
			endif
		else
			return v:false
		endif
	endwhile
	return v:true
enddef

export def IsShiftJis(input: string): bool
	# http://charset.7jp.net/sjis.html
	var cs: string = input
	var i: number = 0
	while i < len(cs)
		if 0x00 <= char2nr(cs[i]) && char2nr(cs[i]) <= 0x7f
			i += 1
		elseif 0xa1 <= char2nr(cs[i]) && char2nr(cs[i]) <= 0xdf
			i += 1
	
		elseif (0x81 <= char2nr(cs[i]) && char2nr(cs[i]) <= 0x9f) ||
		   	(0xe0 <= char2nr(cs[i]) && char2nr(cs[i]) <= 0xef)
			i += 1
			if (0x40 <= char2nr(cs[i]) && char2nr(cs[i]) <= 0x7e) ||
			   	(0x80 <= char2nr(cs[i]) && char2nr(cs[i]) <= 0xfc)
				i += 1
			else
				return v:false
			endif
		elseif 0x8e == char2nr(cs[i])
			i += 1
			if 0xa1 <= char2nr(cs[i]) && char2nr(cs[i]) <= 0xdf
				i += 1
			else
				return v:false
			endif
		else
			return v:false
		endif
	endwhile
	return v:true
enddef

export def IsISO2022JP(input: string): bool
	# http://charset.7jp.net/jis.html
	const MODE_A: number = 0 # ASCIIの開始
	const MODE_B: number = 1 # 漢字の開始（旧JIS漢字 JIS C 6226-1978）
	const MODE_C: number = 2 # 漢字の開始 (新JIS漢字 JIS X 0208-1983）
	const MODE_D: number = 3 # 漢字の開始 (JIS X 0208-1990）
	const MODE_E: number = 4 # JISローマ字の開始
	const MODE_F: number = 5 # 半角カタカナの開始

	var cs: string = input
	var mode: number = MODE_A
	var i: number = 0
	while i < len(cs)
		if 0x1b == char2nr(cs[i]) && 0x24 == char2nr(cs[i + 1])  && 0x40 == char2nr(cs[i + 2])
			i += 3
			mode = MODE_B
		elseif 0x1b == char2nr(cs[i]) && 0x24 == char2nr(cs[i + 1])  && 0x42 == char2nr(cs[i + 2])
			i += 3
			mode = MODE_C
		elseif 0x1b == char2nr(cs[i]) && 0x26 == char2nr(cs[i + 1])  && 0x40 == char2nr(cs[i + 2]) &&
		   	0x1b == char2nr(cs[i + 3]) && 0x24 == char2nr(cs[i + 4]) && 0x42 == char2nr(cs[i + 5])
			i += 6
			mode = MODE_D
		elseif 0x1b == char2nr(cs[i]) && 0x28 == char2nr(cs[i + 1])  && 0x42 == char2nr(cs[i + 2])
			i += 3
			mode = MODE_A
			#elseif 0x1b == char2nr(cs[i]) && 0x28 == char2nr(cs[i + 1])  && 0x4a == char2nr(cs[i + 2])
			#i += 3
			#mode = MODE_E
		elseif 0x1b == char2nr(cs[i]) && 0x28 == char2nr(cs[i + 1])  && 0x49 == char2nr(cs[i + 2])
			i += 3
			mode = MODE_F

		elseif mode == MODE_A
			if 0x00 <= char2nr(cs[i]) && char2nr(cs[i]) <= 0x7f
				i += 1
			else
				return v:false
			endif
		elseif mode == MODE_F
			if   (0x21 <= char2nr(cs[i]) && char2nr(cs[i]) <= 0x5f) || (0xa1 <= char2nr(cs[i]) && char2nr(cs[i]) <= 0xdf)
				i += 1
			else
				return v:false
			endif
		elseif (mode == MODE_B) || (mode == MODE_C) || (mode == MODE_D)
			if (0x21 <= char2nr(cs[i]) && char2nr(cs[i]) <= 0x7e) && (0x21 <= char2nr(cs[i + 1]) && char2nr(cs[i + 1]) <= 0x7e)
				i += 2
			else
				return v:false
			endif
		else
			return v:false
		endif
	endwhile
	return v:true
enddef

