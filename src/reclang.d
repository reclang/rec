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
    -d STAGES       print compiler stages, comma separated:
                    args, pp, tokens, ast, asm, asm-pp, asm-tokens
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
	if (arguments.shouldDump("args")) writeln(arguments);
	Node program = new Node(NodeKind.program, "Program");
	try {
		foreach(filename; arguments.filenames) {
			SourceLine[] lines = preprocess(filename, arguments.include);
			if (arguments.shouldDump("pp")) foreach (l; lines) writefln("%s/%s:%d: %s", l.path, l.filename, l.num, l.text);
			Token[] tokens = tokenize(lines);
			if (arguments.shouldDump("tokens")) foreach(t; tokens) writefln("%s/%s %d:%d: %s", t.path, t.filename, t.line, t.pos + 1, t.text);
			parse(program, tokens);
			if (arguments.shouldDump("ast")) program.printNode;
		}
	} catch (Exception e) {
		stderr.writeln(e.msg);
		return 1;
	}
	string asmcode = genCode(program, arguments.target);
	if (arguments.shouldDump("asm")) writeln(asmcode);

	//string outputPath = arguments.outputFile.length > 0 ? arguments.outputFile : "./out.asm";
	//File outputFile = File(outputPath, "w");
	//outputFile.write(asmcode);

	SourceLine[] fullcode = preprocess(asmcode.splitLines);
	if (arguments.shouldDump("asm-pp")) foreach (l; fullcode) writefln("%s/%s:%d: %s", l.path, l.filename, l.num, l.text);
	try {
		assemble(fullcode, arguments.outputFile, arguments.target, arguments.shouldDump("asm-tokens"));
	} catch (Exception e) {
		stderr.writeln(e.msg);
		return 1;
	}

	return 0;
}
