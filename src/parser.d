module parser;

import std.stdio;
import tokenizer;

enum NodeKind {
	program, entry, fdecl, call, text
}

class Node {
	NodeKind kind;
	string name;
	string[] params;
	Node[] children;
	Token[] tokens;

	this(NodeKind kind, string name) {
		this.kind = kind;
		this.name = name;
	}
}

void printNode(Node node, uint depth = 0) {
	foreach (_; 0 .. depth) write("  ");
	write(node.kind, " ", node.name);
	if (node.params.length > 0) writef(" (%-(%s, %))", node.params);
	writeln();
	foreach (child; node.children) child.printNode(depth + 1);
}

uint parseParams(Node node, in Token[] tokens, uint pos) {
	while (tokens[pos].text != ")") {
		if (tokens[pos].text != ",") {
			node.params ~= tokens[pos].text;
		}
		pos++;
	}
	return pos + 1;
}

uint parseDeclaration(Node parent, in Token[] tokens, uint pos) {
	while (tokens[pos].text != "(") pos++;
	Node declNode = new Node(tokens[pos - 1].text == "main" ? NodeKind.entry : NodeKind.fdecl, tokens[pos - 1].text);
	pos = parseParams(declNode, tokens, pos + 1);
	pos = parseStatements(declNode, tokens, pos + 1);
	parent.children ~= declNode;
	return pos;
}

uint parseInvocation(Node parent, in Token[] tokens, uint pos) {
	while (tokens[pos].text != "(") pos++;
	Node callNode = new Node(NodeKind.call, tokens[pos - 1].text);
	pos = parseParams(callNode, tokens, pos + 1);
	parent.children ~= callNode;
	return pos;
}

uint parseStatement(Node parent, in Token[] tokens, uint pos) {
	if (tokens[pos].kind == TokenKind.type) return parseDeclaration(parent, tokens, pos);
	else if (tokens[pos].kind == TokenKind.identifier) return parseInvocation(parent, tokens, pos);
	return pos + 1;
}

uint parseStatements(Node parent, in Token[] tokens, uint pos) {
	while (pos < tokens.length) {
		if (tokens[pos].text == "}") break;
		pos = parseStatement(parent, tokens, pos);
	}
	return pos + 1;
}

void parse(Node program, in Token[] tokens) {
	uint pos = parseStatements(program, tokens, 0);
}
