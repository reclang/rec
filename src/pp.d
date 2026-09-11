module pp;

import std.file : readText;
import std.path : absolutePath, buildNormalizedPath, baseName, dirName;

struct SourceLine {
	string filename;
	string path;
	uint num;
	string text;
	SourceLine[] references;
}

SourceLine[] preprocess(string filename) {
	SourceLine[] lines;
	string name = baseName(filename);
	string path = dirName(buildNormalizedPath(absolutePath(filename)));
	// every SourceLine.text is a slice into this buffer
	string source = readText(filename);
	uint num = 1;
	for (size_t start = 0; start < source.length; ) {
		size_t end = start;
		while (end < source.length && source[end] != '\n') end++;
		string text = source[start .. end];
		if (text.length && text[$ - 1] == '\r') text = text[0 .. $ - 1];
		lines ~= SourceLine(name, path, num++, text);
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
