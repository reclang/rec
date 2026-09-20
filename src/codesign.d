// Ad-hoc code signature
// macOS refuses to run an unsigned arm64 executable, so every image reclang
// writes carries one. See cs_blobs.h in XNU (osfmk/kern/cs_blobs.h) for the
// structures and Go's cmd/internal/codesign for the layout a linker writes.
// Unlike the rest of Mach-O, signature blobs are big-endian.

module codesign;

import std.algorithm.comparison : min;
import std.bitmanip : nativeToBigEndian;
import std.digest.sha : sha256Of;
import std.traits : isStaticArray;

// blob magic numbers
enum CSMAGIC_EMBEDDED_SIGNATURE = 0xfade0cc0;   // SuperBlob of an embedded signature
enum CSMAGIC_CODEDIRECTORY      = 0xfade0c02;   // CodeDirectory

// SuperBlob slot types
enum CSSLOT_CODEDIRECTORY = 0;

// CodeDirectory.version_
enum CS_SUPPORTSEXECSEG = 0x20400;              // has the execSeg fields

// CodeDirectory.flags
enum CS_ADHOC         = 0x0000002;              // signed with no identity
enum CS_LINKER_SIGNED = 0x0020000;              // signed by a linker, not by codesign(1)

// CodeDirectory.hashType
enum CS_HASHTYPE_SHA256 = 2;

// CodeDirectory.execSegFlags
enum CS_EXECSEG_MAIN_BINARY = 0x1;              // the process's main executable

// Hashed pages are 4 KiB whatever the architecture's page size is,
// as in ld64, lld and the Go linker.
enum uint pageSizeBits = 12;
enum uint pageSize     = 1 << pageSizeBits;
enum uint hashSize     = 32;                    // SHA-256
enum uint blobAlign    = 16;                    // the signature is padded to this

// The signature is a SuperBlob holding one blob, the CodeDirectory
struct SuperBlob {
    uint magic;         // CSMAGIC_EMBEDDED_SIGNATURE
    uint length;        // size of the whole signature
    uint count;         // number of BlobIndex entries, which follow
}
static assert(SuperBlob.sizeof == 12);

struct BlobIndex {
    uint type;          // CSSLOT_*
    uint offset;        // from the start of the SuperBlob
}
static assert(BlobIndex.sizeof == 8);

// Followed by the identifier string and one hash per page
struct CodeDirectory {
    uint  magic;            // CSMAGIC_CODEDIRECTORY
    uint  length;           // size of this blob
    uint  version_;         // CS_SUPPORTS*
    uint  flags;            // CS_ADHOC, ...
    uint  hashOffset;       // first page hash, from the blob start
    uint  identOffset;      // identifier string, from the blob start
    uint  nSpecialSlots;    // hashes stored before hashOffset
    uint  nCodeSlots;       // page hashes
    uint  codeLimit;        // how much of the file is hashed
    ubyte hashSize;         // bytes per hash
    ubyte hashType;         // CS_HASHTYPE_*
    ubyte platform;         // 0 unless this is an Apple platform binary
    ubyte pageSizeBits;     // log2 of the hashed page size
    uint  spare2;
    uint  scatterOffset;    // version 0x20100
    uint  teamOffset;       // version 0x20200
    uint  spare3;           // version 0x20300
    ulong codeLimit64;      // for files above 4 GiB
    ulong execSegBase;      // version 0x20400, __TEXT file offset
    ulong execSegLimit;     // __TEXT file size
    ulong execSegFlags;     // CS_EXECSEG_*
}
static assert(CodeDirectory.sizeof == 88);

// the CodeDirectory follows the SuperBlob header and its one index entry
enum uint directoryOffset = SuperBlob.sizeof + BlobIndex.sizeof;
// the identifier follows the CodeDirectory header
enum uint identifierOffset = CodeDirectory.sizeof;

// Field-wise big-endian serialization, independent of host endianness
ubyte[] serialize(T)(auto ref const T blob) if (is(T == struct)) {
    ubyte[] bytes;
    foreach (field; blob.tupleof) {
        static if (isStaticArray!(typeof(field))) bytes ~= field[];
        else bytes ~= nativeToBigEndian(field)[];
    }
    assert(bytes.length == T.sizeof);
    return bytes;
}

// hashes needed for codeLimit bytes; the last page may be short
uint codeSlots(uint codeLimit) {
    return (codeLimit + pageSize - 1) / pageSize;
}

// the page hashes follow the identifier, which follows the header
uint hashesOffset(string identifier) {
    return identifierOffset + cast(uint)(identifier.length + 1);
}

uint directorySize(string identifier, uint codeLimit) {
    return hashesOffset(identifier) + codeSlots(codeLimit) * hashSize;
}

// Size of the signature, which depends only on the identifier and the page
// count. The image must reserve exactly this much: the sizes recorded in the
// header are hashed along with everything else.
uint signatureSize(string identifier, uint codeLimit) {
    uint total = directoryOffset + directorySize(identifier, codeLimit);
    return (total + blobAlign - 1) / blobAlign * blobAlign;
}

// Signs a finished image: every byte of it is hashed, and the blob returned
// completes the file. identifier names the image, ld64 uses the output file's
// basename. execSegLimit is the __TEXT segment's file size.
ubyte[] sign(const(ubyte)[] image, string identifier, ulong execSegLimit) {
    uint codeLimit = cast(uint) image.length;
    uint slots = codeSlots(codeLimit);
    uint blobSize = directorySize(identifier, codeLimit);
    CodeDirectory directory = {
        magic:        CSMAGIC_CODEDIRECTORY,
        length:       blobSize,
        version_:     CS_SUPPORTSEXECSEG,
        flags:        CS_ADHOC | CS_LINKER_SIGNED,
        hashOffset:   hashesOffset(identifier),
        identOffset:  identifierOffset,
        nSpecialSlots: 0,
        nCodeSlots:   slots,
        codeLimit:    codeLimit,
        hashSize:     hashSize,
        hashType:     CS_HASHTYPE_SHA256,
        platform:     0,
        pageSizeBits: pageSizeBits,
        codeLimit64:  0,
        execSegBase:  0,            // __TEXT starts at file offset 0
        execSegLimit: execSegLimit,
        execSegFlags: CS_EXECSEG_MAIN_BINARY,
    };
    SuperBlob superBlob = {
        magic:  CSMAGIC_EMBEDDED_SIGNATURE,
        length: directoryOffset + blobSize,
        count:  1,
    };
    BlobIndex index = {
        type:   CSSLOT_CODEDIRECTORY,
        offset: directoryOffset,
    };
    ubyte[] blob = serialize(superBlob) ~ serialize(index) ~ serialize(directory);
    blob ~= cast(const(ubyte)[]) identifier;
    blob ~= 0;
    foreach (slot; 0 .. slots) {
        size_t start = slot * pageSize;
        blob ~= sha256Of(image[start .. min(start + pageSize, codeLimit)]);
    }
    assert(blob.length == superBlob.length);
    blob.length = signatureSize(identifier, codeLimit);
    return blob;
}
