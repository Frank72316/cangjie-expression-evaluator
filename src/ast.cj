package cjexpr

enum BinaryOp {
    Add | Subtract | Multiply | Divide
}

// 子节点总是先于父节点写入列表。节点编号同时也是求值结果的下标。
enum AstNode {
    Literal(Float64)
    | Variable(String, Position)
    | Negate(Int64)
    | Binary(BinaryOp, Int64, Int64, Position)
}
