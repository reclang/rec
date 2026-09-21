module codegen;

import std.stdio;
import std.format;
import args;
import parser;

// how a target makes a system call
struct SyscallConvention {
	string number;		// register for the syscall number
	string[] args;		// argument registers, in order
	string trap;		// instruction that enters the kernel
	uint write, exit;	// syscall numbers
	string address;		// mnemonic that loads a label's address
}

SyscallConvention syscallConvention(Target target) {
	final switch (target.os) {
		case OS.linux:
			final switch (target.arch) {
				case Arch.x86_64: return SyscallConvention("rax", ["rdi", "rsi", "rdx"], "syscall", 1, 60, "mov");
				case Arch.aarch64: return SyscallConvention("x8", ["x0", "x1", "x2"], "svc\t0", 64, 93, "adr");
			}
			break;
		case OS.macos:
			final switch (target.arch) {
				case Arch.x86_64: break;
				case Arch.aarch64: return SyscallConvention("x16", ["x0", "x1", "x2"], "svc\t128", 4, 1, "adr");
			}
			break;
	}
	throw new Exception("No code generation for target " ~ target.toString);
}

string objectFormat(OS os) {
	final switch (os) {
		case OS.linux: return "ELF64";
		case OS.macos: return "MachO64";
	}
}

string[] strings;
SyscallConvention sys;

string addString(string text) {
	strings ~= text;
	return format("str%d", strings.length - 1);
}

string genFunction(Node node, string name) {
	string s;
	s ~= format("%s:\n", name);
	foreach(child; node.children) s ~= genNode(child);
	return s;
}

string genCall(Node node) {
	switch (node.name) {
		case "exit":
			return format("\tmov\t%s, %d\n\tmov\t%s, %s\n\t%s\n",
				sys.number, sys.exit, sys.args[0], node.params[0].text, sys.trap);
		case "writeln":
			string text = node.params[0].text;
			string label = addString(text);
			return format("\tmov\t%s, %d\n\tmov\t%s, 1\n\t%s\t%s, %s\n\tmov\t%s, %d\n\t%s\n",
				sys.number, sys.write, sys.args[0], sys.address, sys.args[1], label, sys.args[2], text.length + 1, sys.trap);
		default: return format("call %s\n", node.name);
	}
}

string genNode(Node node) {
	switch(node.kind) {
		case NodeKind.entry: return genFunction(node, "_start");
		case NodeKind.fdecl: return genFunction(node, node.name);
		case NodeKind.call: return genCall(node);
		default: return "";
	}
}

string genCode(Node program, Target target) {
	sys = syscallConvention(target);
	string s;
	s ~= format("format %s executable\n", objectFormat(target.os));
	s ~= "entry _start\n";
	s ~= "segment readable executable\n";
	foreach(node; program.children) s ~= genNode(node);
	foreach(i, text; strings) s ~= format("str%d:\n\tdb\t\"%s\", 10\n", i, text);
	return s;
}
