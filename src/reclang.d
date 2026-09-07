import std.stdio;
import std.string;

enum VERSION = import("VERSION").strip;

int main(string[] args) {
	if (args.length > 1 && args[1] == "--version") {
		writeln(VERSION);
		return 0;
	}
	writeln("reclang ", VERSION);
	return 0;
}
