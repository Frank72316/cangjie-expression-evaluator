package cjexpr

import std.collection.ArrayList

// 递归只发生在括号内，同一优先级的连续运算和一元负号均使用循环。
let maxParenthesisDepth: Int64 = 64

class Parser {
    private let source: TokenSource
    private var token: Token
    private let nodes = ArrayList<AstNode>()

    init(source: TokenSource) {
        this.source = source
        token = source.nextToken()
    }

    func parse(): ArrayList<AstNode> {
        sum(0)
        match (token.kind) {
            case End => return nodes
            case RightParen => throw ExprException("UNEXPECTED_CLOSE", token.at, "右括号没有对应的左括号")
            case _ => throw ExprException("MISSING_OPERATOR", token.at, "两个操作数之间缺少运算符")
        }
    }

    private func addNode(node: AstNode): Int64 {
        let result = nodes.size
        nodes.add(node)
        result
    }

    private func advance(): Unit {
        token = source.nextToken()
    }

    private func sum(depth: Int64): Int64 {
        var left = product(depth)
        while (true) {
            let op = match (token.kind) {
                case Infix(Add) => Add
                case Infix(Subtract) => Subtract
                case _ => return left
            }
            let at = token.at
            advance()
            let right = product(depth)
            left = addNode(Binary(op, left, right, at))
        }
        left
    }

    private func product(depth: Int64): Int64 {
        var left = unary(depth)
        while (true) {
            let op = match (token.kind) {
                case Infix(Multiply) => Multiply
                case Infix(Divide) => Divide
                case _ => return left
            }
            let at = token.at
            advance()
            let right = unary(depth)
            left = addNode(Binary(op, left, right, at))
        }
        left
    }

    private func unary(depth: Int64): Int64 {
        let negative = takeMinusSigns()
        let base = primary(depth)
        let value = match (token.kind) {
            case Infix(Power) => powerChain(base, depth)
            case _ => base
        }
        if (negative) { addNode(Negate(value)) } else { value }
    }

    private func takeMinusSigns(): Bool {
        var negative = false
        while (let Infix(Subtract) <- token.kind) {
            negative = !negative
            advance()
        }
        negative
    }

    private func powerChain(first: Int64, depth: Int64): Int64 {
        let pending = ArrayList<(Int64, Position, Bool)>()
        var operand = first
        while (let Infix(Power) <- token.kind) {
            let at = token.at
            advance()
            let negativeExponent = takeMinusSigns()
            pending.add((operand, at, negativeExponent))
            operand = primary(depth)
        }

        // 右侧的负号修饰整个指数。2^-3^2 按 2^(-(3^2)) 建树。
        var i = pending.size
        while (i > 0) {
            i--
            let (base, at, negativeExponent) = pending[i]
            let exponent = if (negativeExponent) { addNode(Negate(operand)) } else { operand }
            operand = addNode(Binary(Power, base, exponent, at))
        }
        operand
    }

    private func primary(depth: Int64): Int64 {
        let at = token.at
        match (token.kind) {
            case Number(value) =>
                advance()
                return addNode(Literal(value))
            case Name(name) =>
                advance()
                return addNode(Variable(name, at))
            case LeftParen =>
                if (depth == maxParenthesisDepth) {
                    throw ExprException("NESTING_LIMIT", at, "括号嵌套最多为 ${maxParenthesisDepth} 层")
                }
                advance()
                let child = sum(depth + 1)
                match (token.kind) {
                    case RightParen => advance()
                    case End => throw ExprException("MISSING_CLOSE", at, "这个左括号缺少对应的右括号")
                    case _ => throw ExprException("MISSING_OPERATOR", token.at, "括号内的操作数之间缺少运算符")
                }
                return child
            case _ => throw ExprException("EXPECTED_OPERAND", at, "此处需要数字、变量或括号表达式")
        }
    }
}
