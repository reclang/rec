// ELF64 object file format
// see elf.h (or https://www.man7.org/linux/man-pages/man5/elf.5.html)
// for reference

module elf64;

import std.bitmanip : nativeToLittleEndian;
import std.traits : isStaticArray;

alias Elf64_Half  = ushort; // 16-bit
alias Elf64_Word  = uint;   // 32-bit
alias Elf64_Xword = ulong;  // 64-bit
alias Elf64_Addr  = ulong;  // program address
alias Elf64_Off   = ulong;  // program offset

// e_ident[] indices
enum EI_NIDENT     = 16;    // e_ident[] size
enum EI_CLASS      = 4;     // file class
enum EI_DATA       = 5;     // data encoding
enum EI_VERSION    = 6;     // file version
enum EI_OSABI      = 7;     // OS/ABI identification
enum EI_ABIVERSION = 8;     // ABI version
enum EI_PAD        = 9;     // start of padding bytes

enum ELFCLASS64    = 2;     // 64-bit objects
enum ELFDATA2LSB   = 1;     // little endian
enum EV_CURRENT    = 1;     // current ELF version
enum ELFOSABI_SYSV = 0;     // System V ABI

// e_type
enum ET_EXEC = 2;           // executable file

// e_machine
enum EM_X86_64 = 62;        // AMD x86-64
enum EM_AARCH64 = 183;      // ARM AArch64

// p_type
enum PT_LOAD = 1;           // loadable segment

// p_flags 0RWX
enum PF_X = 1 << 0;         // execute
enum PF_W = 1 << 1;         // write
enum PF_R = 1 << 2;         // read

// ELF header, always at file offset 0
struct Elf64_Ehdr {
    ubyte[EI_NIDENT] e_ident;   // magic, class, data encoding, version, OS/ABI
    Elf64_Half e_type;          // object file type, ET_*
    Elf64_Half e_machine;       // target architecture, EM_*
    Elf64_Word e_version;       // object file version, EV_CURRENT
    Elf64_Addr e_entry;         // entry point virtual address
    Elf64_Off  e_phoff;         // program header table file offset
    Elf64_Off  e_shoff;         // section header table file offset
    Elf64_Word e_flags;         // processor-specific flags
    Elf64_Half e_ehsize;        // ELF header size
    Elf64_Half e_phentsize;     // program header table entry size
    Elf64_Half e_phnum;         // program header table entry count
    Elf64_Half e_shentsize;     // section header table entry size
    Elf64_Half e_shnum;         // section header table entry count
    Elf64_Half e_shstrndx;      // section name string table index
}
static assert(Elf64_Ehdr.sizeof == 64);

// Program header
struct Elf64_Phdr {
    Elf64_Word  p_type;     // segment type, PT_*
    Elf64_Word  p_flags;    // segment flags, PF_*
    Elf64_Off   p_offset;   // segment file offset
    Elf64_Addr  p_vaddr;    // segment virtual address
    Elf64_Addr  p_paddr;    // segment physical address
    Elf64_Xword p_filesz;   // segment size in file
    Elf64_Xword p_memsz;    // segment size in memory
    Elf64_Xword p_align;    // segment alignment
}
static assert(Elf64_Phdr.sizeof == 56);

// Image layout: [Elf64_Ehdr][Elf64_Phdr][code], one readable executable
// PT_LOAD segment mapping the whole file at loadAddress.
enum Elf64_Addr  loadAddress = 0x400000;
enum Elf64_Off   codeOffset  = Elf64_Ehdr.sizeof + Elf64_Phdr.sizeof;
enum Elf64_Addr  codeAddress = loadAddress + codeOffset;
// PT_LOAD alignment: 4 KiB pages on x86-64, 64 KiB on aarch64
enum Elf64_Xword segmentAlignX86_64  = 0x1000;
enum Elf64_Xword segmentAlignAArch64 = 0x10000;
static assert(codeOffset == 0x78);

// Field-wise little-endian serialization, independent of host endianness
ubyte[] serialize(T)(auto ref const T header) if (is(T == struct)) {
    ubyte[] bytes;
    foreach (field; header.tupleof) {
        static if (isStaticArray!(typeof(field))) bytes ~= field[];
        else bytes ~= nativeToLittleEndian(field)[];
    }
    assert(bytes.length == T.sizeof);
    return bytes;
}

// Builds a static executable image from machine code.
// entryOffset is the offset of the entry point within code.
ubyte[] executableImage(const(ubyte)[] code, ulong entryOffset, Elf64_Half machine, Elf64_Xword segmentAlign) {
    Elf64_Ehdr ehdr = {
        e_ident: [0x7f, 'E', 'L', 'F',
                  ELFCLASS64, ELFDATA2LSB, EV_CURRENT, ELFOSABI_SYSV,
                  0, 0, 0, 0, 0, 0, 0, 0],
        e_type:      ET_EXEC,
        e_machine:   machine,
        e_version:   EV_CURRENT,
        e_entry:     codeAddress + entryOffset,
        e_phoff:     Elf64_Ehdr.sizeof,
        e_shoff:     0,
        e_flags:     0,
        e_ehsize:    Elf64_Ehdr.sizeof,
        e_phentsize: Elf64_Phdr.sizeof,
        e_phnum:     1,
        e_shentsize: 0,
        e_shnum:     0,
        e_shstrndx:  0,
    };
    Elf64_Phdr phdr = {
        p_type:   PT_LOAD,
        p_flags:  PF_R | PF_X,
        p_offset: 0,
        p_vaddr:  loadAddress,
        p_paddr:  loadAddress,
        p_filesz: codeOffset + code.length,
        p_memsz:  codeOffset + code.length,
        p_align:  segmentAlign,
    };
    ubyte[] image = serialize(ehdr);
    image ~= serialize(phdr);
    image ~= code;
    return image;
}
