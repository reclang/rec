module tokenizer;

import std.uni;
import pp;

enum TokenKind {
	identifier, type, text
}

struct Token {
	string path;
	string filename;
	uint line;
	uint pos;
	string text;
	TokenKind kind;
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
				tokens ~= Token(path, filename, line, start, s[start..i], TokenKind.text);
				continue;
			}
			switch (c) {
				case '{', '(', '}', ')':
					tokens ~= Token(path, filename, line, start, s[start..i], TokenKind.text);
					tokens ~= Token(path, filename, line, i, s[i..i+1], TokenKind.text);
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
	if (collecting) tokens ~= Token(path, filename, line, start, s[start..$], TokenKind.text);
	return tokens;
}

Token[] tokenize(SourceLine[] lines) {
	Token[] tokens;
	foreach(line; lines) {
		tokens ~= tokenize(line.path, line.filename, line.num, line.text);
	}
	return tokens;
}