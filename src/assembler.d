module assembler;

import std.stdio;
import std.conv : octal, to;
import std.file : setAttributes;
import elf64;
import pp;
import tokenizer;

struct Label {
	string local;
	string fullName;
	uint offset;

	ulong address() { return codeAddress + offset; }
}

struct Instruction {
	string instruction;
	Token[] operands;

	this(Token[] tokens) {
		for(uint i = 0; i < tokens.length; i++) {
			if (tokens[i].text == ",") continue;
			if (i == 0) {
				this.instruction = tokens[0].text;
			} else {
				this.operands ~= tokens[i];
			}
		}
	}
}

Instruction processInstruction(Token[] tokens) {
	return Instruction(tokens);
}

int[string] registers = [
	"rax":  0, "rcx":  1, "rdx":  2, "rbx":  3,
	"rsp":  4, "rbp":  5, "rsi":  6, "rdi":  7,
	"r8":   8, "r9":   9, "r10": 10, "r11": 11,
	"r12": 12, "r13": 13, "r14": 14, "r15": 15
];

long value(Token operand, Label[string] labels) {
	if (operand.kind == TokenKind.constant) return to!long(operand.text);
	if (auto label = operand.text in labels) return label.address;
	return 0;
}

ubyte[] bytes(Instruction instruction, Label[string] labels) {
	switch (instruction.instruction) {
		case "syscall": return [0x0f, 0x05];
		// REX.W + B8+ rd io
		case "mov":
			int reg = registers[instruction.operands[0].text];
			long imm = value(instruction.operands[1], labels);
			ubyte[] code = [
				cast(ubyte)(0x48 | (reg >= 8 ? 1 : 0)),
				cast(ubyte)(0xb8 + (reg & 7))
			];
			foreach (i; 0..8) code ~= cast(ubyte)(imm >> (i * 8));
			return code;
		case "db":
			ubyte[] code;
			foreach (operand; instruction.operands) {
				if (operand.kind == TokenKind.text) foreach (c; operand.text) code ~= cast(ubyte) c;
				else code ~= cast(ubyte) to!long(operand.text);
			}
			return code;
		default: return [];
	}
}

ubyte[] assemble(SourceLine[] lines, string filename) {
	uint offset;
	string entryLabel = "_start";
	Label[string] labels;
	string parentLabel;
	uint num = 1;
	Instruction[] instructions;
	// first pass: collect instructions and label offsets
	foreach(line; lines) {
		Token[] tokens = tokenize(line.path, line.filename, num++, line.text);
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
				Instruction instruction = processInstruction(tokens);
				offset += instruction.bytes(labels).length;
				instructions ~= instruction;
		}
		writeln(tokens);
	}
	// second pass: encode with all labels known
	ubyte[] bytes;
	foreach (instruction; instructions) bytes ~= instruction.bytes(labels);
	ulong entryOffset;
	if (auto label = entryLabel in labels) entryOffset = label.offset;
	else stderr.writefln("warning: entry label '%s' not found, using code offset 0", entryLabel);
	File(filename, "wb").rawWrite(executableImage(bytes, entryOffset));
	return bytes;
}
