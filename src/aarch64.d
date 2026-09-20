// AArch64 instruction encoding

module aarch64;

import std.algorithm.searching : countUntil;
import std.bitmanip : nativeToLittleEndian;
import assembler;
import tokenizer;

// 64-bit general-purpose registers, in encoding order
int[string] registers = [
    "x0":   0, "x1":   1, "x2":   2, "x3":   3, "x4":   4, "x5":   5, "x6":   6, "x7":   7,
    "x8":   8, "x9":   9, "x10": 10, "x11": 11, "x12": 12, "x13": 13, "x14": 14, "x15": 15,
    "x16": 16, "x17": 17, "x18": 18, "x19": 19, "x20": 20, "x21": 21, "x22": 22, "x23": 23,
    "x24": 24, "x25": 25, "x26": 26, "x27": 27, "x28": 28, "x29": 29, "x30": 30
];

uint imm16(Token operand) {
    long imm = number(operand);
    if (imm < 0 || imm > 0xffff) throw error(operand, "immediate out of range 0..65535: " ~ operand.text);
    return cast(uint) imm;
}

uint size(Instruction instruction) {
    // every instruction must be aligned
    if (instruction.offset % 4 != 0) {
        throw error(instruction.mnemonic, instruction.mnemonic.text ~ " is not 4-byte aligned");
    }
    switch (instruction.mnemonic.text) {
        case "mov", "adr", "svc": return 4;
        default: throw error(instruction.mnemonic, "unknown instruction " ~ instruction.mnemonic.text);
    }
}

ubyte[] encode(Instruction instruction, Label[string] labels) {
    Token[] operands = instruction.operands;
    uint word;
    switch (instruction.mnemonic.text) {
        // MOVZ Xd, #imm16
        case "mov":
            word = 0xd2800000 | (imm16(operands[1]) << 5) | registers[operands[0].text];
            break;
        // ADR Xd, label
        case "adr":
            long imm = long(label(operands[1], labels).offset) - long(instruction.offset);
            word = 0x10000000 | cast(uint)((imm & 3) << 29) | cast(uint)(((imm >> 2) & 0x7ffff) << 5) | registers[operands[0].text];
            break;
        // SVC #imm16
        case "svc":
            word = 0xd4000001 | (imm16(operands[0]) << 5);
            break;
        default: throw error(instruction.mnemonic, "unknown instruction " ~ instruction.mnemonic.text);
    }
    return nativeToLittleEndian(word).dup;
}
