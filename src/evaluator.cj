package cjexpr

import std.collection.HashMap
import std.sync.Mutex

/** 计算不含变量的表达式，返回 Float64。词法、语法或算术错误抛出 ExprException。 */
public func evaluate(expr: String): Float64 {
    CompiledExpression(expr).evaluateWith(HashMap<String, Float64>())
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

    func snapshot(): HashMap<String, Float64> {
        synchronized(mutex) { bindings.clone() }
    }

    /** 使用调用时的变量快照求值。非法表达式、未绑定变量或除零会抛出 ExprException。 */
    public func evaluate(expr: String): Float64 {
        let saved = snapshot()
        CompiledExpression(expr).evaluateWith(saved)
    }

    /** 提交时截取变量快照，在仓颉线程上求值。Future.get() 返回结果或抛出 ExprException。 */
    public func evaluateAsync(expr: String): Future<Float64> {
        let saved = snapshot()
        spawn { CompiledExpression(expr).evaluateWith(saved) }
    }
}
