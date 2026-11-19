package cjexpr

import std.convert.*

enum TokenKind {
    Number(Float64) | Name(String) | Infix(BinaryOp) | LeftParen | RightParen | End
}

struct Token {
    let kind: TokenKind
    let at: Position

    init(kind: TokenKind, at: Position) {
        this.kind = kind
        this.at = at
    }
}

interface TokenSource {
    func nextToken(): Token
}

func isDigit(ch: Rune): Bool {
    ch >= r'0' && ch <= r'9'
}

func isNameStart(ch: Rune): Bool {
    (ch >= r'a' && ch <= r'z') || (ch >= r'A' && ch <= r'Z') || ch == r'_'
}

func isNamePart(ch: Rune): Bool {
    isNameStart(ch) || isDigit(ch)
}

class Lexer <: TokenSource {
    private let chars: Array<Rune>
    private var index: Int64 = 0
    private var line: Int64 = 1
    private var column: Int64 = 1

    init(source: String) {
        chars = source.toRuneArray()
    }

    // 哨兵仅用于前瞻。nextToken 通过长度判断文件末尾，输入中的 NUL 仍会报错。
    private func peek(): Rune {
        if (index < chars.size) { chars[index] } else { r'\0' }
    }

    private func step(): Unit {
        index++
        column++
    }

    private func skipWhitespace(): Unit {
        while (index < chars.size) {
            let ch = peek()
            if (ch == r' ' || ch == r'\t') {
                step()
            } else if (ch == r'\r' || ch == r'\n') {
                index++
                if (ch == r'\r' && peek() == r'\n') {
                    index++
                }
                line++
                column = 1
            } else {
                return
            }
        }
    }

    private func readNumber(at: Position): TokenKind {
        let start = index
        while (isDigit(peek())) { step() }
        if (peek() == r'.') {
            step()
            if (index == start + 1 && !isDigit(peek())) {
                throw ExprException("INVALID_NUMBER", at, "小数点前后至少需要一位数字")
            }
            while (isDigit(peek())) { step() }
        }
        if (peek() == r'e' || peek() == r'E') {
            step()
            if (peek() == r'+' || peek() == r'-') { step() }
            if (!isDigit(peek())) {
                throw ExprException("INVALID_NUMBER", Position(line, column), "指数缺少数字")
            }
            while (isDigit(peek())) { step() }
        }
        if (peek() == r'.') {
            throw ExprException("INVALID_NUMBER", Position(line, column), "数字中出现多余的小数点")
        }
        let spelling = String(chars[start..index])
        match (Float64.tryParse(spelling)) {
            case Some(value) =>
                if (value.isInf() || value.isNaN()) {
                    throw ExprException("NON_FINITE", at, "数值超出 Float64 的有限范围")
                }
                return Number(value)
            case None => throw ExprException("INVALID_NUMBER", at, "无法读取数字 ${spelling}")
        }
    }

    public func nextToken(): Token {
        skipWhitespace()
        let at = Position(line, column)
        if (index == chars.size) { return Token(End, at) }
        let ch = peek()
        if (isDigit(ch) || ch == r'.') { return Token(readNumber(at), at) }
        if (isNameStart(ch)) {
            let start = index
            step()
            while (isNamePart(peek())) { step() }
            return Token(Name(String(chars[start..index])), at)
        }
        step()
        let kind = match (ch) {
            case r'+' => Infix(Add)
            case r'-' => Infix(Subtract)
            case r'*' => Infix(Multiply)
            case r'/' => Infix(Divide)
            case r'(' => LeftParen
            case r')' => RightParen
            case _ => throw ExprException("INVALID_CHARACTER", at, "无法识别字符“${ch}”")
        }
        Token(kind, at)
    }
}
