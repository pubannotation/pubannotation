#!/usr/bin/env ruby
#encoding: UTF-8
Encoding.default_external="UTF-8"
Encoding.default_internal="UTF-8"

module Utfrewrite
	@@charmap = {
		0x00E1 => "a",
		0x00C1 => "A",
		0x00E2 => "a",
		0x00C2 => "A",
		0x00E0 => "a",
		0x00C0 => "A",
		0x00E5 => "a",
		0x00C5 => "A",
		0x00E3 => "a",
		0x00C3 => "A",
		0x00E4 => "a",
		0x00C4 => "A",
		0x00E6 => "ae",
		0x00C6 => "AE",
		0x00E7 => "c",
		0x00C7 => "C",
		0x00E9 => "e",
		0x00C9 => "E",
		0x00EA => "e",
		0x00CA => "E",
		0x00E8 => "e",
		0x00C8 => "E",
		0x00EB => "e",
		0x00CB => "E",
		0x00ED => "i",
		0x00CD => "I",
		0x00EE => "i",
		0x00CE => "I",
		0x00EC => "i",
		0x00CC => "I",
		0x00EF => "i",
		0x00CF => "I",
		0x00F1 => "n",
		0x00D1 => "N",
		0x00F3 => "o",
		0x00D3 => "O",
		0x00F4 => "o",
		0x00D4 => "O",
		0x00F2 => "o",
		0x00D2 => "O",
		0x00F8 => "o",
		0x00D8 => "O",
		0x00F5 => "o",
		0x00D5 => "O",
		0x00F6 => "o",
		0x00D6 => "O",
		0x00DF => "ss",
		0x00FA => "u",
		0x00DA => "U",
		0x00FB => "u",
		0x00DB => "U",
		0x00F9 => "u",
		0x00D9 => "U",
		0x00FC => "u",
		0x00DC => "U",
		0x00FD => "y",
		0x00DD => "Y",
		0x00FF => "y",
		0x0103 => "a",
		0x0102 => "A",
		0x0101 => "a",
		0x0100 => "A",
		0x0105 => "a",
		0x0104 => "A",
		0x0107 => "c",
		0x0106 => "C",
		0x010D => "c",
		0x010C => "C",
		0x0109 => "c",
		0x0108 => "C",
		0x010B => "c",
		0x010A => "C",
		0x010F => "d",
		0x010E => "D",
		0x0111 => "d",
		0x0110 => "D",
		0x011B => "e",
		0x011A => "E",
		0x0117 => "e",
		0x0116 => "E",
		0x0113 => "e",
		0x0112 => "E",
		0x0119 => "e",
		0x0118 => "E",
		0x01F5 => "g",
		0x011F => "g",
		0x011E => "G",
		0x0122 => "G",
		0x011D => "g",
		0x011C => "G",
		0x0121 => "g",
		0x0120 => "G",
		0x0125 => "h",
		0x0124 => "H",
		0x0127 => "h",
		0x0126 => "H",
		0x0130 => "I",
		0x012A => "I",
		0x012B => "ij",
		0x0133 => "ij",
		0x0132 => "IJ",
		0x0131 => "i",
		0x012F => "i",
		0x012E => "I",
		0x0129 => "ij",
		0x0128 => "I",
		0x0135 => "j",
		0x0134 => "J",
		0x0137 => "k",
		0x0136 => "K",
		0x0138 => "k",
		0x013A => "l",
		0x0139 => "L",
		0x013E => "l",
		0x013D => "L",
		0x013C => "l",
		0x013B => "L",
		0x0140 => "l",
		0x013F => "L",
		0x0142 => "l",
		0x0141 => "L",
		0x0144 => "n",
		0x0143 => "N",
		0x0149 => "n",
		0x0148 => "n",
		0x0147 => "N",
		0x0146 => "n",
		0x0145 => "N",
		0x0151 => "o",
		0x0150 => "O",
		0x014C => "O",
		0x014D => "o",
		0x0153 => "oe",
		0x0152 => "OE",
		0x0155 => "r",
		0x0154 => "R",
		0x0159 => "r",
		0x0158 => "R",
		0x0157 => "r",
		0x0156 => "R",
		0x015B => "s",
		0x015A => "S",
		0x0161 => "s",
		0x0160 => "S",
		0x015F => "s",
		0x015E => "S",
		0x015D => "s",
		0x015C => "S",
		0x0165 => "t",
		0x0164 => "T",
		0x0163 => "t",
		0x0162 => "T",
		0x0167 => "t",
		0x0166 => "T",
		0x016D => "u",
		0x016C => "U",
		0x0171 => "u",
		0x0170 => "U",
		0x016B => "u",
		0x016A => "U",
		0x0173 => "u",
		0x0172 => "U",
		0x016F => "u",
		0x016E => "U",
		0x0169 => "u",
		0x0168 => "U",
		0x0175 => "w",
		0x0174 => "W",
		0x0177 => "y",
		0x0176 => "Y",
		0x0178 => "Y",
		0x017A => "z",
		0x0179 => "Z",
		0x017E => "z",
		0x017D => "Z",
		0x017C => "z",
		0x017B => "Z",
		0x2003 => " ",
		0x2002 => " ",
		0x2004 => " ",
		0x2005 => " ",
		0x2007 => " ",
		0x2008 => " ",
		0x2009 => " ",
		0x200A => " ",
		0x2014 => "-",
		0x2013 => "-",
		0x2010 => "-",
		0x2423 => " ",
		0x2025 => "..",
		0x25CB => "o",
		0x2022 => "*",
		0x201A => "'",
		0x201E => "\"",
		0x201D => "\"",
		0x2019 => "'",
		0x0192 => "f",
		0x3008 => "<",
		0x2212 => "-",
		0x2213 => "-/+",
		0x2032 => "'",
		0x2033 => "''",
		0x3009 => ">",
		0x212B => "A",
		0x00A8 => " ",
		0x210B => "H",
		0x2217 => "*",
		0x2134 => "o",
		0x2133 => "M",
		0x00B4 => " ",
		0x02D8 => " ",
		0x02C7 => " ",
		0x00B8 => " ",
		0x005E => " ",
		0x02DD => " ",
		0x00A8 => " ",
		0x02D9 => " ",
		0x0060 => " ",
		0x00AF => " ",
		0x02DB => " ",
		0x02DA => " ",
		0x02DC => " ",
		0x00A8 => " ",
		0x00F7 => "/",
		0x00D7 => "x",
		0x005C => "\\",
		0x2015 => "-",
		0x00AE => "(R)",
        0x00B5 => "==micro==",
        0x2126 => "==ohm==",
        0x00B0 => "==degrees==",
        0x00BA => "==masculine==",
        0x00AA => "==feminine==",
		0x00B1 => "+/-",
		0x223C => "==approximately==",
        0x2243 => "==approximately==",
		0x00B7 => ".",
		0x00A6 => "|",
		0x2010 => "-",
		0x2018 => "'",
		0x2019 => "'",
		0x201C => "\"",
		0x201D => "\"",
		0x00A0 => " ",
		0x00AD => "-",
		0x00B7 => ".",
		0x2216 => "\\",
		0x2035 => "'",
		0x2113 => "l",
		0x0131 => "i",
		0x005C => "\\",
		0x2032 => "'",
		0x2329 => "<",
		0x232A => ">",
		0x2236 => ":",
		0x2709 => " ",
		0x20DE => " ",
	}

	def Utfrewrite.utf8_to_ascii(text)
		atext = ''
		text.each_codepoint do |code|
			str = (@@charmap[code])? @@charmap[code] : code.chr
			atext += str
		end
		atext
	end
end

if __FILE__ == $0
	ARGF.each do |line|
		puts Utfrewrite.utf8_to_ascii(line)
	end
end
