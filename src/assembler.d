module assembler;

import std.stdio;
import std.conv : octal, to, ConvException;
import std.file : exists, remove, setAttributes;
import std.format : format;
import std.path : baseName;
import args;
import pp;
import tokenizer;
import elf64;
import macho;
import x86_64;
import aarch64;

struct Label {
	string local;
	string fullName;
	uint offset;

	ulong address() { return elf64.codeAddress + offset; } // Mach-O output is position-independent
}

struct Instruction {
	Token mnemonic;
	Token[] operands;
	uint offset;
	uint size;

	this(Token[] tokens) {
		mnemonic = tokens[0];
		foreach (token; tokens[1..$]) {
			if (token.kind != TokenKind.punctuator || token.text != ",") operands ~= token;
		}
	}
}

Exception error(Token token, string message) {
	return new Exception(format("%s:%d: %s", token.filename, token.line, message));
}

long number(Token operand) {
	try return to!long(operand.text);
	catch (ConvException) throw error(operand, "expected a number, got " ~ operand.text);
}

Label label(Token operand, Label[string] labels) {
	if (Label *found = operand.text in labels) return *found;
	throw error(operand, "undefined label " ~ operand.text);
}

// db: text and byte values, the same on every architecture
ubyte[] data(Instruction instruction) {
	ubyte[] code;
	foreach (operand; instruction.operands) {
		if (operand.kind == TokenKind.text) {
			foreach (c; operand.text) code ~= cast(ubyte) c;
			continue;
		}
		long value = number(operand);
		if (value < 0 || value > 255) throw error(operand, "byte value out of range: " ~ operand.text);
		code ~= cast(ubyte) value;
	}
	return code;
}

uint size(Instruction instruction, Arch arch) {
	if (instruction.mnemonic.text == "db") return cast(uint) data(instruction).length;
	final switch (arch) {
		case Arch.x86_64:  return x86_64.size(instruction);
		case Arch.aarch64: return aarch64.size(instruction);
	}
}

ubyte[] encode(Instruction instruction, Label[string] labels, Arch arch) {
	if (instruction.mnemonic.text == "db") return data(instruction);
	final switch (arch) {
		case Arch.x86_64:  return x86_64.encode(instruction, labels);
		case Arch.aarch64: return aarch64.encode(instruction, labels);
	}
}

ubyte[] assemble(SourceLine[] lines, string filename, Target target) {
	uint offset;
	string entryLabel = "_start";
	Label[string] labels;
	string parentLabel;
	Instruction[] instructions;
	// first pass: collect instructions, their offsets and label offsets
	foreach(line; lines) {
		Token[] tokens = tokenize(line.path, line.filename, line.num, line.text);
		if (tokens.length == 0) continue;
		if (tokens[0].text[$-1] == ':') {
			string name = tokens[0].text[0..$-1];
			string fullName = name;
			if (name[0] == '.') {
				fullName = parentLabel ~ name;
			} else {
				parentLabel = name;
			}
			labels[name] = Label(name, fullName, offset);
			tokens = tokens[1..$];
		}
		if (tokens.length == 0) continue;
		switch (tokens[0].text) {
			// directives
			case "entry": if (tokens.length > 1) entryLabel = tokens[1].text; break;
			case "format", "segment": break;
			default:
				Instruction instruction = Instruction(tokens);
				instruction.offset = offset;
				instruction.size = size(instruction, target.arch);
				offset += instruction.size;
				instructions ~= instruction;
		}
		writeln(tokens);
	}
	// second pass: encode with all labels known
	ubyte[] bytes;
	foreach (instruction; instructions) bytes ~= instruction.encode(labels, target.arch);
	ulong entryOffset;
	if (Label *label = entryLabel in labels) entryOffset = label.offset;
	else stderr.writefln("warning: entry label '%s' not found, using code offset 0", entryLabel);
	ubyte[] image;
	final switch (target.os) {
		case OS.linux: image = elf64.executableImage(bytes, entryOffset); break;
		case OS.macos: image = macho.executableImage(bytes, entryOffset, baseName(filename)); break;
	}
	// macOS caches code-signature state per vnode
	// a signed binary rewritten in place is killed on its next run
	// the file must be replaced instead
	if (exists(filename)) remove(filename);
	File(filename, "wb").rawWrite(image);
	// make out file executable
	version (Posix) setAttributes(filename, octal!755);
	return bytes;
}
