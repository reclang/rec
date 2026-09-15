module tokenizer;

import std.uni;
import pp;

enum CharKind: ubyte { other, digit, white, punct, quote }
CharKind[256] charKind = () {
    CharKind[256] ck; // defaults to other
    foreach(c; "0123456789")  ck[c] = CharKind.digit;
    foreach(c; " \t\n\r\v\f") ck[c] = CharKind.white;
    foreach(c; "{}(),")       ck[c] = CharKind.punct;
    foreach(c; "\"")          ck[c] = CharKind.quote;
    return ck;
}();

enum TokenKind {
    identifier, type, keyword, constant, punctuator, text
}

struct Token {
    string path;
    string filename;
    uint line;
    uint pos;
    string text;
    TokenKind kind;
}

TokenKind tokenKind(string s) {
    switch(s) {
        case "void": return TokenKind.type;
        default: return charKind[s[0]] == CharKind.digit ? TokenKind.constant : TokenKind.identifier;
    }
}

private void tokenizeLine(ref Token[] tokens, string path, string filename, uint line, string s) {
    uint i = 0;
    while(i < s.length) {
        final switch (charKind[s[i]]) {
            case CharKind.white: i++; break;
            case CharKind.punct:
                tokens ~= Token(path, filename, line, i, s[i .. i+1], TokenKind.punctuator);
                i++;
                break;
            case CharKind.quote:
                uint start = i++;
                while (i < s.length && s[i] != '"') i++;
                tokens ~= Token(path, filename, line, start, s[start + 1 .. i], TokenKind.text);
                i++;
                break;
            case CharKind.other, CharKind.digit:
                uint start = i++;
                while (i < s.length && charKind[s[i]] != CharKind.white && charKind[s[i]] != CharKind.punct) i++;
                tokens ~= Token(path, filename, line, start, s[start .. i], tokenKind(s[start .. i]));
                break;
        }
    }
}

Token[] tokenize(string path, string filename, uint line, string s) {
   Token[] tokens;
    tokenizeLine(tokens, path, filename, line, s);
    return tokens;
}

Token[] tokenize(SourceLine[] lines) {
    Token[] tokens;
    foreach(ref line; lines) tokenizeLine(tokens, line.path, line.filename, line.num, line.text);
    return tokens;
}
