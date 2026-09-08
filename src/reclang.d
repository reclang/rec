import std.stdio;
import std.string;
import args;
import pp;

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
    -a ARCH         target architechture
	}.strip;
	writeln(help);
}

int main(string[] args) {
	Arguments arguments = processArguments(args);
	if (arguments.showVersion) {
		showVersion();
		return 0;
	}
	if (arguments.showHelp) {
		showHelp();
		return 0;
	}
	writeln(arguments);
	foreach(filename; arguments.filenames) {
		SourceLine[] lines = preprocess(filename);
		writeln(lines);
	}

	return 0;
}
