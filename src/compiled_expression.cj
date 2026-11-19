package cjexpr

import std.collection.ArrayList
import std.collection.HashMap

private func binaryValue(op: BinaryOp, left: Float64, right: Float64, at: Position): Float64 {
    let result = match (op) {
        case Add => left + right
        case Subtract => left - right
        case Multiply => left * right
        case Divide =>
            if (right == 0.0) {
                throw ExprException("DIVISION_BY_ZERO", at, "除数为零")
            }
            left / right
        case Power =>
            if (left == 0.0 && right < 0.0) {
                throw ExprException("DIVISION_BY_ZERO", at, "零的负次幂需要除以零")
            }
            let value = left ** right
            if (value.isNaN()) {
                throw ExprException("POWER_DOMAIN", at, "负底数的指数必须为整数")
            }
            value
    }
    if (result.isInf() || result.isNaN()) {
        throw ExprException("NON_FINITE", at, "运算结果超出 Float64 的有限范围")
    }
    result
}

/** 一次解析得到的公式。可在多个求值器或线程之间共享。 */
public class CompiledExpression {
    private let nodes: ArrayList<AstNode>

    /** 解析完整表达式。词法、语法或字面量错误会在构造时抛出 ExprException。 */
    public init(expr: String) {
        nodes = Parser(Lexer(expr)).parse()
    }

    /** 使用 evaluator 当前的变量快照执行公式。变量和算术错误抛出 ExprException。 */
    public func evaluate(evaluator: Evaluator): Float64 {
        evaluateWith(evaluator.snapshot())
    }

    /** 在提交时取得变量快照。Future.get() 返回数值或抛出本次求值的 ExprException。 */
    public func evaluateAsync(evaluator: Evaluator): Future<Float64> {
        let saved = evaluator.snapshot()
        spawn { evaluateWith(saved) }
    }

    func evaluateWith(bindings: HashMap<String, Float64>): Float64 {
        let values = Array<Float64>(nodes.size, repeat: 0.0)
        for (i in 0..nodes.size) {
            values[i] = match (nodes[i]) {
                case Literal(n) => n
                case Variable(name, at) => match (bindings.get(name)) {
                    case Some(value) => value
                    case None => throw ExprException("UNKNOWN_VARIABLE", at, "变量“${name}”未绑定")
                }
                case Negate(child) => -values[child]
                case Binary(op, left, right, at) => binaryValue(op, values[left], values[right], at)
            }
        }
        values[nodes.size - 1]
    }
}
