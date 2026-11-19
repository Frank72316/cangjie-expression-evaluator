package expression_example

import cjexpr.*

main() {
    println("2 + 3 * 4 = ${evaluate("2 + 3 * 4")}")

    let calculator = Evaluator()
    calculator.bind("price", 12.5)
    calculator.bind("count", 4.0)
    let pending = calculator.evaluateAsync("price * count")
    calculator.bind("price", 15.0)
    println("提交任务时的总价 = ${pending.get()}")
    println("调价后的总价 = ${calculator.evaluate("price * count")}")

    try {
        println(calculator.evaluate("price / (count - 4)"))
    } catch (e: ExprException) {
        println("${e.code}  ${e.message}")
    }
}
