module pp;

import std.file : exists, isFile, readText;
import std.path : absolutePath, buildNormalizedPath, baseName, dirName, isAbsolute;

import std.string;
import std.uni;
import std.stdio;
import std.range;
import std.algorithm;

struct SourceLine {
	string filename;
	string path;
	uint num;
	string text;
	SourceLine[] references;
}

struct Directive {
	string name;
	Param[] params;
}

struct Param {
	string name;
	string[] values;
}

// -- Directive parser --

Directive parseDirective(string text) {
	size_t i = 0;
	while (i < text.length && isWhite(text[i])) i++;
	if (i < text.length && text[i] == '#') i++;
	size_t start = i;
	while (i < text.length && !isWhite(text[i]) && text[i] != '(') i++;
	Directive d;
	d.name = text[start .. i];
	string rest = text[i .. $];
	// count first so params and all values take one allocation each
	size_t np, nv;
	scanParams!false(rest, null, null, np, nv);
	if (np == 0) return d;
	d.params = uninitializedArray!(Param[])(np);
	string[] values = nv ? uninitializedArray!(string[])(nv) : null;
	np = nv = 0;
	scanParams!true(rest, d.params, values, np, nv);
	return d;
}

// scans the params part of the directive string
private void scanParams(bool fill)(string s, Param[] params, string[] values, ref size_t np, ref size_t nv) {
	size_t i = 0;
	while (true) {
		while (i < s.length && (isWhite(s[i]) || s[i] == ',' || s[i] == ')')) i++;
		if (i >= s.length) return;
		string name = scanWord(s, i);
		size_t first = nv;
		while (i < s.length && isWhite(s[i])) i++;
		if (i < s.length && s[i] == '(') {
			i++;
			while (true) {
				while (i < s.length && (isWhite(s[i]) || s[i] == ',' || s[i] == '(')) i++;
				if (i >= s.length) break;
				if (s[i] == ')') { i++; break; }
				string v = scanWord(s, i);
				static if (fill) values[nv] = v;
				nv++;
			}
		}
		static if (fill) params[np] = Param(name, values[first .. nv]);
		np++;
	}
}

// a quoted string (without quotes) or a bare word up to whitespace , ( )
private string scanWord(string s, ref size_t i) {
	if (s[i] == '"') {
		size_t start = ++i;
		while (i < s.length && s[i] != '"') i++;
		string w = s[start .. i];
		if (i < s.length) i++;
		return w;
	}
	size_t start = i;
	while (i < s.length && !isWhite(s[i]) && s[i] != ',' && s[i] != '(' && s[i] != ')') i++;
	return s[start .. i];
}

// Tests for the parser
unittest {
	assert(parseDirective("include foo").name == "include");
	assert(parseDirective("include foo").params[0].name == "foo");
	assert(parseDirective("include \"foo\"").params[0].name == "foo");

	assert(parseDirective("if arch(x86, x86_64), os(linux, macos)").name == "if");
	assert(parseDirective("if arch(x86, x86_64), os(linux, macos)").params[0].name == "arch");
	assert(parseDirective("if arch(x86, x86_64), os(linux, macos)").params[0].values[0] == "x86");
	assert(parseDirective("if arch(x86, x86_64), os(linux, macos)").params[0].values[1] == "x86_64");
	assert(parseDirective("if arch(x86, x86_64), os(linux, macos)").params[1].name == "os");
	assert(parseDirective("if arch(x86, x86_64), os(linux, macos)").params[1].values[0] == "linux");
	assert(parseDirective("if arch(x86, x86_64), os(linux, macos)").params[1].values[1] == "macos");

	assert(parseDirective("#if  arch( x86 )").name == "if");
	assert(parseDirective("#if  arch( x86 )").params.length == 1);
	assert(parseDirective("#if  arch( x86 )").params[0].values == ["x86"]);
	assert(parseDirective("endif").params.length == 0);
	assert(parseDirective("include \"a b\"").params[0].name == "a b");
	assert(parseDirective("if os(linux").params[0].values == ["linux"]);
}

// -- Directives --

// where is "file:line" of the directive, for error messages
void include(ref SourceLine[] lines, Param[] params, string path, string includes, string where) {
	if (params.length == 0) throw new Exception(where ~ ": #include needs a filename");
	foreach (param; params) {
		if (param.name.length == 0) throw new Exception(where ~ ": empty filename in #include");
		string found = findInclude(param.name, path, includes);
		if (found is null) throw new Exception(format("%s: cannot find include file %s", where, param.name));
		lines ~= preprocess(found);
	}
}

// an absolute filename is used as is, a relative one is looked up
// next to the including file first, then in the include path
string findInclude(string filename, string sourcePath, string includePath) {
	if (isAbsolute(filename)) return isExistingFile(filename) ? filename : null;
	foreach (dir; [sourcePath, includePath]) {
		if (dir.length == 0) continue;
		string candidate = buildNormalizedPath(dir, filename);
		if (isExistingFile(candidate)) return candidate;
	}
	return null;
}

// isFile throws on a missing path, so check exists first
bool isExistingFile(string path) {
	return exists(path) && isFile(path);
}

// -- Preprocessor --

SourceLine[] preprocess(string filename) {
	SourceLine[] lines;
	string name = baseName(filename);
	string path = dirName(buildNormalizedPath(absolutePath(filename)));
	// every SourceLine.text is a slice into this buffer
	string source = readText(filename);
	uint num = 1;
	bool skip;
	for (size_t start = 0; start < source.length; ) {
		size_t end = start;
		size_t text_start = end;
		bool hasDirective; 
		while (end < source.length && source[end] != '\n') {
			if(text_start == end && isWhite(source[end])) text_start++;
			if(!hasDirective && source[end] == '#' && text_start == end) hasDirective = true;
			end++;
		}
		string text = source[start .. end];
		if (text.length && text[$ - 1] == '\r') text = text[0 .. $ - 1];
		if (hasDirective) {
			Directive directive = parseDirective(source[text_start .. end]);
			switch (directive.name) {
				case "include": include(lines, directive.params, path, path, format("%s:%d", name, num)); break; // should be a -i path if available
				default: 
				if (directive.name.length > 0 && directive.name[0] == '!') {
					// skip
				} else {
					// throw error: unrecognized directive 
					writeln("Preprocessor directive: ", directive);
				}
			}
		} else if (skip) {
			// do nothing
		} else {
			lines ~= SourceLine(name, path, num, text);
		}
		num++;
		start = end + 1;
	}
	return lines;
}

SourceLine[] preprocess(string[] code) {
	SourceLine[] lines;
	uint num = 1;
	foreach (line; code) {
		lines ~= SourceLine("source.asm", "", num++, line);
	}
	return lines;
}
