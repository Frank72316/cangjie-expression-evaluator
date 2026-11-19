package cjexpr

struct Position {
    let line: Int64
    let column: Int64

    init(line: Int64, column: Int64) {
        this.line = line
        this.column = column
    }
}

/** 表达式或变量绑定有误。message 含中文说明与从 1 起算的行列号。 */
public class ExprException <: Exception {
    /** 稳定的错误代码，取值见 doc/api.md 的错误表。 */
    public let code: String
    /** 表达式中的行号。绑定错误定位到传入的变量名。 */
    public let line: Int64
    /** 从 1 起算的 Unicode 码点列号。 */
    public let column: Int64

    init(code: String, at: Position, detail: String) {
        super("第 ${at.line} 行，第 ${at.column} 列：${detail}")
        this.code = code
        this.line = at.line
        this.column = at.column
    }
}
