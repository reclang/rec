module args;

import std.string;
import std.path : absolutePath, buildNormalizedPath, baseName;

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

string normalizePath(string path) {
	return buildNormalizedPath(absolutePath(path));
}

string withoutExtension(string path) {
    string name = baseName(path);
    long dotIndex = name.lastIndexOf('.');
    return dotIndex != -1 ? name[0 .. dotIndex] : name;
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
					case "s": arguments.path = v; break;
					default:
						arguments.error = "Unknown parameter: -" ~ k;
						return arguments;
				}
				break;
		}
	}
	string currentPath = ".".normalizePath;
	arguments.path = arguments.path.length == 0 ? currentPath : arguments.path.normalizePath;
	arguments.include = arguments.include.length == 0 ? currentPath : arguments.include.normalizePath;
	arguments.outputFile = arguments.outputFile.length == 0 ? "./out.o" : arguments.outputFile;
	// filenames are relative to the source path; absolute ones are kept as is
	foreach (ref filename; arguments.filenames) filename = buildNormalizedPath(arguments.path, filename);
	if (arguments.name.length == 0) {
		if (arguments.outputFile.length != 0) {
			arguments.name = arguments.outputFile.withoutExtension;
		} else if (arguments.filenames.length > 0) {
			arguments.name = arguments.filenames[0].withoutExtension;
		} else {
			arguments.name = "app";
		}
	}
	return arguments;
}
