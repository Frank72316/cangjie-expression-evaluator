package cjexpr

import std.unittest.*
import std.unittest.testmacro.*

func nestedExpression(depth: Int64): String {
    let text = StringBuilder()
    for (_ in 0..depth) { text.append("(") }
    text.append("1")
    for (_ in 0..depth) { text.append(")") }
    text.toString()
}

@Test
class ArithmeticTests {
    @TestCase
    func integer() {
        @Expect(evaluate("42"), 42.0)
    }

    @TestCase
    func decimal() {
        @Expect(evaluate("12.75"), 12.75)
    }

    @TestCase
    func leadingPoint() {
        @Expect(evaluate(".5 + .25"), 0.75)
    }

    @TestCase
    func trailingPoint() {
        @Expect(evaluate("2. + 1"), 3.0)
    }

    @TestCase
    func scientificNotation() {
        @Expect(evaluate("1.25e2 + 3E+1"), 155.0)
    }

    @TestCase
    func negativeExponent() {
        @Expect(evaluate("25e-2"), 0.25)
    }

    @TestCase
    func multiplicationFirst() {
        @Expect(evaluate("2 + 3 * 4"), 14.0)
    }

    @TestCase
    func divisionFirst() {
        @Expect(evaluate("7 - 12 / 3"), 3.0)
    }

    @TestCase
    func leftAssociativeSubtraction() {
        @Expect(evaluate("20 - 5 - 3"), 12.0)
    }

    @TestCase
    func leftAssociativeDivision() {
        @Expect(evaluate("24 / 4 / 2"), 3.0)
    }

    @TestCase
    func equalPrecedence() {
        @Expect(evaluate("12 / 3 * 2"), 8.0)
    }

    @TestCase
    func parenthesisOverride() {
        @Expect(evaluate("(2 + 3) * 4"), 20.0)
    }

    @TestCase
    func nestedParentheses() {
        @Expect(evaluate("((1 + 2) * (8 - 3)) / 2"), 7.5)
    }

    @TestCase
    func leadingNegative() {
        @Expect(evaluate("-2 * 3"), -6.0)
    }

    @TestCase
    func negativeGroup() {
        @Expect(evaluate("-(2 + 5)"), -7.0)
    }

    @TestCase
    func minusAfterOperator() {
        @Expect(evaluate("3*-2 - -4"), -2.0)
    }

    @TestCase
    func repeatedSigns() {
        @Expect(evaluate("----3 + ---2"), 1.0)
    }

    @TestCase
    func acrossLines() {
        @Expect(evaluate("\t(2\r\n + 3)\n* 4 "), 20.0)
    }

    @TestCase
    func thousandTerms() {
        let text = StringBuilder("1")
        for (_ in 1..1000) { text.append("+1") }
        @Expect(evaluate(text.toString()), 1000.0)
    }

    @TestCase
    func manyUnarySigns() {
        let text = StringBuilder()
        for (_ in 0..4001) { text.append("-") }
        text.append("3")
        @Expect(evaluate(text.toString()), -3.0)
    }

    @TestCase
    func lastAllowedDepth() {
        @Expect(evaluate(nestedExpression(64)), 1.0)
    }

    @TestCase
    func smallFiniteOperand() {
        @Expect(evaluate("1e-200 / 1e-200"), 1.0)
    }
}
