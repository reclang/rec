module tokenizer;

import std.uni;
import pp;

enum TokenKind {
	identifier, type, keyword, constant, punctuator, text
}

bool[string] types = [ "void": true ];
bool[string] punctuators = [ "{": true, "(": true, "}": true, ")": true,  ",": true  ];

struct Token {
	string path;
	string filename;
	uint line;
	uint pos;
	string text;
	TokenKind kind;
}

TokenKind tokenKind(string s) {
	if (s in types) return TokenKind.type;
	if (isNumber(s[0])) return TokenKind.constant;
	if (s in punctuators) return TokenKind.punctuator;
	return TokenKind.identifier;
}

Token[] tokenize(string path, string filename, uint line, string s) {
	Token[] tokens;
	uint start;
	bool collecting;
	for (uint i = 0; i < s.length; i++) {
		char c = s[i];
		if (collecting) {
			if (isWhite(c)) {
				collecting = false;
				tokens ~= Token(path, filename, line, start, s[start..i], tokenKind(s[start..i]));
				continue;
			}
			switch (c) {
				case '{', '(', '}', ')', ',':
					tokens ~= Token(path, filename, line, start, s[start..i], tokenKind(s[start..i]));
					tokens ~= Token(path, filename, line, i, s[i..i+1], TokenKind.punctuator);
					start = i+1;
					collecting = false;
					break;
				default: continue;
			}
		} else {
			if (isWhite(c)) continue;
			collecting = true;
			start = i;
		}
	}
	if (collecting) tokens ~= Token(path, filename, line, start, s[start..$], tokenKind(s[start..$]));
	return tokens;
}

Token[] tokenize(SourceLine[] lines) {
	Token[] tokens;
	foreach(line; lines) {
		tokens ~= tokenize(line.path, line.filename, line.num, line.text);
	}
	return tokens;
}