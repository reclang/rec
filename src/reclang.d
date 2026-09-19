import std.stdio;
import std.string;
import args;
import pp;
import tokenizer;
import parser;
import codegen;
import assembler;

enum VERSION = import("VERSION").strip;

void showVersion(bool full = false) {
	full ? writeln("reclang ", VERSION) : writeln(VERSION);
}

void showHelp() {
	showVersion(true);
	enum help = q{
    reclang [OPTIONS] files...
    --version       reclang version
    --help          this help
    -o FILENAME     output file name
    -s PATH         path for source files
    -i PATH         path for include files
    -t ARCH-OS      target, defaults to the host
	}.strip;
	writeln(help);
}

int main(string[] args) {
	Arguments arguments = processArguments(args);
	if (arguments.error.length != 0) {
		stderr.writeln(arguments.error);
		return 1;
	}
	if (arguments.showVersion) {
		showVersion();
		return 0;
	}
	if (arguments.showHelp) {
		showHelp();
		return 0;
	}
	writeln(arguments);
	Node program = new Node(NodeKind.program, "Program");
	foreach(filename; arguments.filenames) {
		SourceLine[] lines = preprocess(filename);
		foreach (l; lines) writefln("%s/%s:%d: %s", l.path, l.filename, l.num, l.text);
		Token[] tokens = tokenize(lines);
		foreach(t; tokens) writefln("%s/%s %d:%d: %s", t.path, t.filename, t.line, t.pos + 1, t.text);
		parse(program, tokens);
		program.printNode;
	}
	string asmcode = genCode(program);
	writeln(asmcode);

	//string outputPath = arguments.outputFile.length > 0 ? arguments.outputFile : "./out.asm";
	//File outputFile = File(outputPath, "w");
	//outputFile.write(asmcode);

	SourceLine[] fullcode = preprocess(asmcode.splitLines);
	foreach (l; fullcode) writefln("%s/%s:%d: %s", l.path, l.filename, l.num, l.text);
	ubyte[] bytes = assemble(fullcode, arguments.outputFile);

	return 0;
}
