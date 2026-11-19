package cjexpr

import std.collection.HashMap
import std.sync.Mutex

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
    }
    if (result.isInf() || result.isNaN()) {
        throw ExprException("NON_FINITE", at, "运算结果超出 Float64 的有限范围")
    }
    result
}

private func evaluateWith(expr: String, bindings: HashMap<String, Float64>): Float64 {
    let nodes = Parser(Lexer(expr)).parse()
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

/** 计算不含变量的表达式，返回 Float64。词法、语法或算术错误抛出 ExprException。 */
public func evaluate(expr: String): Float64 {
    evaluateWith(expr, HashMap<String, Float64>())
}

/** 可在线程间共享的求值器。每次调用读取一份一致的变量快照。 */
public class Evaluator {
    private let bindings = HashMap<String, Float64>()
    private let mutex = Mutex()

    /** 创建没有预设变量的求值器。 */
    public init() {}

    /** 新建或更新区分大小写的变量。非法标识符或非有限数值会抛出 ExprException。 */
    public func bind(name: String, value: Float64): Unit {
        let chars = name.toRuneArray()
        if (chars.size == 0 || !isNameStart(chars[0])) {
            throw ExprException("INVALID_NAME", Position(1, 1), "变量名须以 ASCII 字母或下划线开头")
        }
        for (i in 1..chars.size) {
            if (!isNamePart(chars[i])) {
                throw ExprException("INVALID_NAME", Position(1, i + 1), "变量名中只能使用 ASCII 字母、数字和下划线")
            }
        }
        if (value.isInf() || value.isNaN()) {
            throw ExprException("NON_FINITE", Position(1, 1), "变量值必须为有限数")
        }
        synchronized(mutex) { bindings[name] = value }
    }

    private func snapshot(): HashMap<String, Float64> {
        synchronized(mutex) { bindings.clone() }
    }

    /** 使用调用时的变量快照求值。非法表达式、未绑定变量或除零会抛出 ExprException。 */
    public func evaluate(expr: String): Float64 {
        evaluateWith(expr, snapshot())
    }

    /** 提交时截取变量快照，在仓颉线程上求值。Future.get() 返回结果或抛出 ExprException。 */
    public func evaluateAsync(expr: String): Future<Float64> {
        let saved = snapshot()
        spawn { evaluateWith(expr, saved) }
    }
}
