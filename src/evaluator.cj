package cjexpr

import std.collection.HashMap
import std.sync.Mutex

/** 计算不含变量的表达式，返回 Float64。词法、语法或算术错误抛出 ExprException。 */
public func evaluate(expr: String): Float64 {
    CompiledExpression(expr).evaluateWith(HashMap<String, Float64>())
}

/** 可在线程间共享的求值器。每次调用读取一份一致的变量快照。 */
public class Evaluator {
    private var bindings = HashMap<String, Float64>()
    private let mutex = Mutex()

    /** 创建没有预设变量的求值器。 */
    public init() {}

    /** 新建或更新区分大小写的变量。非法标识符或非有限数值会抛出 ExprException。 */
    public func bind(name: String, value: Float64): Unit {
        validateBinding(name, value)
        synchronized(mutex) { bindings[name] = value }
    }

    /** 原子地新建或更新一批变量。重复名称取最后的值，任一项非法时整批不生效。 */
    public func bindAll(entries: Array<(String, Float64)>): Unit {
        if (entries.size == 0) { return }
        synchronized(mutex) {
            let next = bindings.clone()
            for (i in 0..entries.size) {
                let (name, value) = entries[i]
                validateBinding(name, value, entry: Some(i + 1))
                next[name] = value
            }
            bindings = next
        }
    }

    private func validateBinding(name: String, value: Float64, entry!: ?Int64 = None): Unit {
        func invalid(code: String, column: Int64, reason: String): ExprException {
            let detail = match (entry) {
                case Some(i) => "批量绑定第 ${i} 项（“${name}”）：${reason}"
                case None => reason
            }
            ExprException(code, Position(1, column), detail)
        }
        let chars = name.toRuneArray()
        if (chars.size == 0 || !isNameStart(chars[0])) {
            throw invalid("INVALID_NAME", 1, "变量名须以 ASCII 字母或下划线开头")
        }
        for (i in 1..chars.size) {
            if (!isNamePart(chars[i])) {
                throw invalid("INVALID_NAME", i + 1, "变量名中只能使用 ASCII 字母、数字和下划线")
            }
        }
        if (value.isInf() || value.isNaN()) {
            throw invalid("NON_FINITE", 1, "变量值必须为有限数")
        }
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
