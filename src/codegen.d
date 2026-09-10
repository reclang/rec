module codegen;

import std.stdio;
import std.format;
import parser;

string genFunction(Node node, string name) {
	string s;
	s ~= format("%s:\n", name);
	foreach(child; node.children) s ~= genNode(child);
	return s;	
}

string genCall(Node node) {
	switch (node.name) {
		case "exit": return format("\tmov\trax, 60\n\tmov\trdi, %s\n\tsyscall\n", node.params[0]);
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

string genCode(Node program) {
	string s;
	s ~= "format ELF64 executable\n";
	s ~= "entry _start\n";
	s ~= "segment readable executable\n";
	foreach(node; program.children) s ~= genNode(node);
	return s;
}
