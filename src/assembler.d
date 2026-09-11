module assembler;

import std.stdio;
import std.conv : to;
import pp;
import tokenizer;

struct Label {
	string local;
	string fullName;
	uint offset;
}

struct Instruction {
	string instruction;
	string[] operands;

	this(Token[] tokens) {
		for(uint i = 0; i < tokens.length; i++) {
			if (tokens[i].text == ",") continue;
			if (i == 0) {
				this.instruction = tokens[0].text;
			} else {
				this.operands ~= tokens[i].text;
			}
		}
	}
}

void processKeywords(Token[] tokens) {

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

byte[] elf64 = [
//  -- ELF Header
//  0x00
	0x7f, 0x45, 0x4c, 0x46,     // 7f E L F
	2, 							// 64-bit format
	1,							// little endianness
	1, 							// ELF version
	3, 0,                       // Linux, 0
	0,0,0,0, 0,0,0,             // Reserved
// 0x10
	2, 0, 						// 0x0002 Executable file
	0x3e, 0,                    // 0x003e AMD x86-64
	1,0,0,0,                    // 0x00000001 e_version = 1
	0x78, 0, 0x40, 0, 0,0,0,0,  // 0x0000000000400000 + 0x78 entry offset
// 0x20
    0x40, 0,0,0, 0,0,0,0,       // 0x0000000000000040 program header offset
    0,0,0,0, 0,0,0,0,           // section header table
// 0x30
    0,0,0,0,                    // flags
    0x40, 0,                    // header size (52 for x86 and 64 for x86-64)
    0x38, 0,       				// program header entry size (0x20 or 0x38 for x86-64)
    1, 0,                       // number of entries
    0x40, 0,      				// section header entry size
    0, 0, 						// number of entries
    0, 0,                       // index w section names
// 0x40 -- End of header --
// Program header
	1,0,0,0,					// Segment type - 1 = loadable
	5,0,0,0,                    // Flags ..0RWX - 101 = readable executable
	0,0,0,0, 0,0,0,0,			// Offset of the segment
// 0x50
	0,0,0x40,0, 0,0,0,0,		// virtual address of the segment
	0,0,0,0, 0,0,0,0,           // segment's physical address
// 0x60
	0,0,0,0, 0,0,0,0,			// Size of the segment in file image
	0,0,0,0, 0,0,0,0,			// Size of the segment in memory
// 0x70
	0,0,0,0, 0,0,0,0,           // Alignment
];

byte[] bytes(Instruction instruction) {
	writeln(instruction);
	switch (instruction.instruction) {
		case "syscall": return [0x0f, 0x05];
		// REX.W + B8+ rd io
		case "mov":
			int reg = registers[instruction.operands[0]];
			long imm = to!long(instruction.operands[1]);
			byte[] code = [
				cast(byte)(0x48 | (reg >= 8 ? 1 : 0)),
				cast(byte)(0xb8 + (reg & 7))
			];
			foreach (i; 0..8) code ~= cast(byte)(imm >> (i * 8));
			return code;
		default: return [];
	}
}

byte[] assemble(SourceLine[] lines, string filename) {
	uint offset;
	uint entry;
	Label[string] labels;
	string parentLabel;
	uint num = 1;
	byte[] bytes;
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
		switch (tokens[0].kind) {
			case TokenKind.keyword: processKeywords(tokens); break;
			default: 
				byte[] encoded = processInstruction(tokens).bytes;
				offset += encoded.length;
				bytes ~= encoded;
		}
		writeln(tokens);
	}
	ulong appsize = elf64.length + bytes.length;
	elf64[0x60] = cast(byte)(appsize & 0xff);
	elf64[0x68] = cast(byte)(appsize & 0xff);
	File(filename, "w").rawWrite(elf64 ~ bytes);
	return bytes;
}