import std.stdio;
import std.string;

enum VERSION = import("VERSION").strip;

struct Arguments {
	string[] filenames;
	string name;
	string outputFile;
	string arch;
	string include;
	string path;
	string error;
	bool showHelp;
	bool showVersion;
}

Arguments processArguments(string[] args) {
	Arguments arguments;
	for(int i = 1; i < args.length; i++) {
		string a = args[i];
		// anything without the leading dash is a file
		if (a[0] != '-') {
			arguments.filenames ~= a;
			continue;
		}
		// options, expected format "-key value"
		switch (a) {
			case "--version": arguments.showVersion = true; break;
			case "--help": arguments.showHelp = true; break;
			default:
				if (args.length <= i + 1) {
					arguments.error = "Missing value for " ~ a;
					return arguments;
				}
				string k = a[1..$], v = args[i++ + 1];
				switch (k) {
					case "o": arguments.outputFile = v; break;
					case "a": arguments.arch = v; break;
					case "i": arguments.include = v; break;
					default:
						arguments.error = "Unknown parameter: -" ~ k;
						return arguments;
				}
				break;
		}
	}
	return arguments;
}

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
	return 0;
}
