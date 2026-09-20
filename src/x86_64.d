// x86-64 instruction encoding

module x86_64;

import std.algorithm.searching : countUntil;
import assembler;
import tokenizer;

// 64-bit general-purpose registers, in encoding order
int[string] registers = [
    "rax": 0, "rcx": 1, "rdx":  2, "rbx":  3, "rsp":  4, "rbp":  5, "rsi":  6, "rdi":  7,
    "r8":  8, "r9":  9, "r10": 10, "r11": 11, "r12": 13, "r13": 13, "r14": 14, "r15": 15
];

long value(Token operand, Label[string] labels) {
    if (operand.kind == TokenKind.constant) return number(operand);
    return label(operand, labels).address;
}

uint size(Instruction instruction) {
    switch (instruction.mnemonic.text) {
        case "syscall": return 2;
        case "mov": return 10;
        default: throw error(instruction.mnemonic, "unknown instruction " ~ instruction.mnemonic.text);
    }
}

ubyte[] encode(Instruction instruction, Label[string] labels) {
    switch (instruction.mnemonic.text) {
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
        default: throw error(instruction.mnemonic, "unknown instruction " ~ instruction.mnemonic.text);
    }
}
