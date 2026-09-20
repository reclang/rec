// Mach-O 64-bit executable file format
// see <mach-o/loader.h> in the macOS SDK
// ($(xcrun --show-sdk-path)/usr/include/mach-o/loader.h) for reference

module macho;

import std.bitmanip : nativeToLittleEndian;
import std.digest.sha : sha256Of;
import std.traits : isStaticArray;

// mach_header_64.magic
enum MH_MAGIC_64 = 0xfeedfacf;

// cputype and cpusubtype, see <mach/machine.h>
enum CPU_ARCH_ABI64        = 0x01000000;                    // 64-bit ABI
enum CPU_TYPE_ARM          = 12;
enum CPU_TYPE_ARM64        = CPU_TYPE_ARM | CPU_ARCH_ABI64;
enum CPU_SUBTYPE_ARM64_ALL = 0;                             // arm64, not arm64e

// filetype
enum MH_EXECUTE = 0x2;          // demand paged executable file

// flags
enum MH_NOUNDEFS = 0x1;         // no undefined references
enum MH_DYLDLINK = 0x4;         // input for the dynamic linker
enum MH_TWOLEVEL = 0x80;        // two-level namespace bindings
enum MH_PIE      = 0x200000;    // loaded at a random address

// load command types
enum LC_REQ_DYLD       = 0x80000000;            // dyld must understand the command
enum LC_SYMTAB         = 0x2;                   // symbol table
enum LC_DYSYMTAB       = 0xb;                   // dynamic symbol table
enum LC_LOAD_DYLIB     = 0xc;                   // load a dynamic library
enum LC_LOAD_DYLINKER  = 0xe;                   // load the dynamic linker
enum LC_SEGMENT_64     = 0x19;                  // 64-bit segment
enum LC_UUID           = 0x1b;                  // image UUID
enum LC_CODE_SIGNATURE = 0x1d;                  // code signature
enum LC_MAIN           = 0x28 | LC_REQ_DYLD;    // entry point
enum LC_BUILD_VERSION  = 0x32;                  // platform and OS versions

// vm_prot_t
enum VM_PROT_READ    = 0x1;
enum VM_PROT_WRITE   = 0x2;
enum VM_PROT_EXECUTE = 0x4;

// section_64.flags attributes
enum S_ATTR_PURE_INSTRUCTIONS = 0x80000000;     // only machine instructions
enum S_ATTR_SOME_INSTRUCTIONS = 0x00000400;     // some machine instructions

// build_version_command.platform
enum PLATFORM_MACOS = 1;

// Mach-O header, always at file offset 0
struct mach_header_64 {
    uint magic;         // MH_MAGIC_64
    int  cputype;       // CPU_TYPE_*
    int  cpusubtype;    // CPU_SUBTYPE_*
    uint filetype;      // MH_EXECUTE
    uint ncmds;         // number of load commands
    uint sizeofcmds;    // size of all load commands
    uint flags;         // MH_*
    uint reserved;
}
static assert(mach_header_64.sizeof == 32);

// Segment load command, followed by nsects section_64 headers
struct segment_command_64 {
    uint      cmd;          // LC_SEGMENT_64
    uint      cmdsize;      // includes the section headers
    ubyte[16] segname;      // NUL-padded
    ulong     vmaddr;       // memory address
    ulong     vmsize;       // memory size
    ulong     fileoff;      // file offset
    ulong     filesize;     // size in file
    int       maxprot;      // VM_PROT_*
    int       initprot;     // VM_PROT_*
    uint      nsects;       // number of sections
    uint      flags;
}
static assert(segment_command_64.sizeof == 72);

// Section header
struct section_64 {
    ubyte[16] sectname;     // NUL-padded
    ubyte[16] segname;      // segment the section belongs to
    ulong     addr;         // memory address
    ulong     size;         // size in bytes
    uint      offset;       // file offset
    uint      align_;       // alignment as a power of 2
    uint      reloff;       // relocation entries' file offset
    uint      nreloc;       // number of relocation entries
    uint      flags;        // type and S_ATTR_*
    uint      reserved1;
    uint      reserved2;
    uint      reserved3;
}
static assert(section_64.sizeof == 80);

// Symbol table
struct symtab_command {
    uint cmd;           // LC_SYMTAB
    uint cmdsize;
    uint symoff;        // symbol table file offset
    uint nsyms;         // number of symbols
    uint stroff;        // string table file offset
    uint strsize;       // string table size
}
static assert(symtab_command.sizeof == 24);

// Dynamic symbol table
struct dysymtab_command {
    uint cmd;           // LC_DYSYMTAB
    uint cmdsize;
    uint ilocalsym;     // local symbols
    uint nlocalsym;
    uint iextdefsym;    // externally defined symbols
    uint nextdefsym;
    uint iundefsym;     // undefined symbols
    uint nundefsym;
    uint tocoff;        // table of contents
    uint ntoc;
    uint modtaboff;     // module table
    uint nmodtab;
    uint extrefsymoff;  // referenced symbol table
    uint nextrefsyms;
    uint indirectsymoff; // indirect symbol table
    uint nindirectsyms;
    uint extreloff;     // external relocation entries
    uint nextrel;
    uint locreloff;     // local relocation entries
    uint nlocrel;
}
static assert(dysymtab_command.sizeof == 80);

// Dynamic linker path, followed by the path string
struct dylinker_command {
    uint cmd;           // LC_LOAD_DYLINKER
    uint cmdsize;       // includes the padded path
    uint name;          // path offset from the command start
}
static assert(dylinker_command.sizeof == 12);

// Image UUID
struct uuid_command {
    uint      cmd;      // LC_UUID
    uint      cmdsize;
    ubyte[16] uuid;
}
static assert(uuid_command.sizeof == 24);

// Platform and OS versions, nibbles xxxx.yy.zz
struct build_version_command {
    uint cmd;           // LC_BUILD_VERSION
    uint cmdsize;
    uint platform;      // PLATFORM_*
    uint minos;         // minimum OS version
    uint sdk;           // SDK version
    uint ntools;        // number of build_tool_version entries
}
static assert(build_version_command.sizeof == 24);

// Entry point
struct entry_point_command {
    uint  cmd;          // LC_MAIN
    uint  cmdsize;
    ulong entryoff;     // file offset of the entry point
    ulong stacksize;    // 0 for the default
}
static assert(entry_point_command.sizeof == 24);

// Dynamic library, followed by the path string
struct dylib_command {
    uint cmd;                   // LC_LOAD_DYLIB
    uint cmdsize;               // includes the padded path
    uint name;                  // path offset from the command start
    uint timestamp;
    uint current_version;       // nibbles xxxx.yy.zz
    uint compatibility_version;
}
static assert(dylib_command.sizeof == 24);

// Offset and size of a blob in __LINKEDIT
struct linkedit_data_command {
    uint cmd;           // LC_CODE_SIGNATURE, ...
    uint cmdsize;
    uint dataoff;       // file offset
    uint datasize;      // size in bytes
}
static assert(linkedit_data_command.sizeof == 16);

ulong roundUp(ulong n, ulong alignment) {
    return (n + alignment - 1) / alignment * alignment;
}

// command size with a NUL-terminated string, padded to 8 bytes
uint stringCommandSize(size_t commandSize, string s) {
    return cast(uint) roundUp(commandSize + s.length + 1, 8);
}

// Image layout:
//   __TEXT     [mach_header_64][load commands][room for LC_CODE_SIGNATURE][code]
//   __LINKEDIT empty until reclang signs its output
// __PAGEZERO maps the low 4 GiB with no access; arm64 requires it.
enum ulong  pageZeroSize  = 0x100000000;
enum ulong  textAddress   = pageZeroSize;
enum ulong  segmentAlign  = 0x4000;     // 16 KiB pages
enum string dyldPath      = "/usr/lib/dyld";
enum string libSystemPath = "/usr/lib/libSystem.B.dylib";
enum uint   macos11       = 0x000b0000; // 11.0.0, the first macOS on arm64
enum uint   version1      = 0x00010000; // 1.0.0

enum uint dylinkerCommandSize = stringCommandSize(dylinker_command.sizeof, dyldPath);
enum uint dylibCommandSize    = stringCommandSize(dylib_command.sizeof, libSystemPath);
enum uint loadCommandsSize    = 3 * segment_command_64.sizeof + section_64.sizeof
    + symtab_command.sizeof + dysymtab_command.sizeof + dylinkerCommandSize
    + uuid_command.sizeof + build_version_command.sizeof + entry_point_command.sizeof
    + dylibCommandSize;
enum ulong codeOffset = mach_header_64.sizeof + loadCommandsSize + linkedit_data_command.sizeof;
static assert(codeOffset == 0x260 && codeOffset % 4 == 0);

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

// segment and section names are NUL-padded 16-byte fields
ubyte[16] name16(string name) {
    ubyte[16] field;
    field[0 .. name.length] = cast(const(ubyte)[]) name;
    return field;
}

// a serialized command followed by its string, zero-padded to cmdsize
ubyte[] withString(ubyte[] command, string s, uint cmdsize) {
    command ~= cast(const(ubyte)[]) s;
    command.length = cmdsize;
    return command;
}

// Builds an arm64 macOS executable image from machine code.
// entryOffset is the offset of the entry point within code.
ubyte[] executableImage(const(ubyte)[] code, ulong entryOffset) {
    ulong textSize = roundUp(codeOffset + code.length, segmentAlign);
    ulong linkeditSize = 0;
    segment_command_64 pageZero = {
        cmd:      LC_SEGMENT_64,
        cmdsize:  segment_command_64.sizeof,
        segname:  name16("__PAGEZERO"),
        vmaddr:   0,
        vmsize:   pageZeroSize,
        fileoff:  0,
        filesize: 0,
        maxprot:  0,
        initprot: 0,
        nsects:   0,
        flags:    0,
    };
    segment_command_64 textSegment = {
        cmd:      LC_SEGMENT_64,
        cmdsize:  segment_command_64.sizeof + section_64.sizeof,
        segname:  name16("__TEXT"),
        vmaddr:   textAddress,
        vmsize:   textSize,
        fileoff:  0,
        filesize: textSize,
        maxprot:  VM_PROT_READ | VM_PROT_EXECUTE,
        initprot: VM_PROT_READ | VM_PROT_EXECUTE,
        nsects:   1,
        flags:    0,
    };
    section_64 textSection = {
        sectname: name16("__text"),
        segname:  name16("__TEXT"),
        addr:     textAddress + codeOffset,
        size:     code.length,
        offset:   codeOffset,
        align_:   2,
        flags:    S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS,
    };
    segment_command_64 linkedit = {
        cmd:      LC_SEGMENT_64,
        cmdsize:  segment_command_64.sizeof,
        segname:  name16("__LINKEDIT"),
        vmaddr:   textAddress + textSize,
        vmsize:   roundUp(linkeditSize, segmentAlign),
        fileoff:  textSize,
        filesize: linkeditSize,
        maxprot:  VM_PROT_READ,
        initprot: VM_PROT_READ,
        nsects:   0,
        flags:    0,
    };
    // no symbols: all zeros
    symtab_command symtab = { cmd: LC_SYMTAB, cmdsize: symtab_command.sizeof };
    dysymtab_command dysymtab = { cmd: LC_DYSYMTAB, cmdsize: dysymtab_command.sizeof };
    dylinker_command dylinker = {
        cmd:     LC_LOAD_DYLINKER,
        cmdsize: dylinkerCommandSize,
        name:    dylinker_command.sizeof,
    };
    // filled in with a hash of the image below
    uuid_command uuid = { cmd: LC_UUID, cmdsize: uuid_command.sizeof };
    build_version_command buildVersion = {
        cmd:      LC_BUILD_VERSION,
        cmdsize:  build_version_command.sizeof,
        platform: PLATFORM_MACOS,
        minos:    macos11,
        sdk:      macos11,
        ntools:   0,
    };
    entry_point_command entryPoint = {
        cmd:       LC_MAIN,
        cmdsize:   entry_point_command.sizeof,
        entryoff:  codeOffset + entryOffset,
        stacksize: 0,
    };
    // dyld requires every executable to link libSystem
    dylib_command libSystem = {
        cmd:                   LC_LOAD_DYLIB,
        cmdsize:               dylibCommandSize,
        name:                  dylib_command.sizeof,
        timestamp:             2,
        current_version:       version1,
        compatibility_version: version1,
    };
    ubyte[] commands;
    uint ncmds;
    void add(ubyte[] command) {
        commands ~= command;
        ncmds++;
    }
    add(serialize(pageZero));
    add(serialize(textSegment) ~ serialize(textSection));
    add(serialize(linkedit));
    add(serialize(symtab));
    add(serialize(dysymtab));
    add(withString(serialize(dylinker), dyldPath, dylinkerCommandSize));
    size_t uuidOffset = mach_header_64.sizeof + commands.length + uuid_command.uuid.offsetof;
    add(serialize(uuid));
    add(serialize(buildVersion));
    add(serialize(entryPoint));
    add(withString(serialize(libSystem), libSystemPath, dylibCommandSize));
    assert(commands.length == loadCommandsSize);
    mach_header_64 header = {
        magic:      MH_MAGIC_64,
        cputype:    CPU_TYPE_ARM64,
        cpusubtype: CPU_SUBTYPE_ARM64_ALL,
        filetype:   MH_EXECUTE,
        ncmds:      ncmds,
        sizeofcmds: loadCommandsSize,
        flags:      MH_NOUNDEFS | MH_DYLDLINK | MH_TWOLEVEL | MH_PIE,
        reserved:   0,
    };
    ubyte[] image = serialize(header) ~ commands;
    image.length = codeOffset;
    image ~= code;
    image.length = textSize;
    // reproducible: the same code gives the same UUID
    image[uuidOffset .. uuidOffset + 16] = sha256Of(image)[0 .. 16];
    return image;
}
