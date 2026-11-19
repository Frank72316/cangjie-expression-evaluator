package cjexpr

import std.unittest.*
import std.unittest.testmacro.*

@Test
class PowerTests {
    @TestCase
    func rightAssociative() {
        @Expect(evaluate("2^3^2"), 512.0)
        @Expect(evaluate("(2^3)^2"), 64.0)
    }

    @TestCase
    func unaryMinusOnBase() {
        @Expect(evaluate("-2^2"), -4.0)
        @Expect(evaluate("(-2)^2"), 4.0)
    }

    @TestCase
    func negativeExponent() {
        @Expect(evaluate("2^-3"), 0.125)
        @Expect(evaluate("(-2)^-3"), -0.125)
    }

    @TestCase
    func signedExponentChain() {
        @Expect(evaluate("2^-3^2"), 1.0 / 512.0)
        @Expect(evaluate("-2^--2^3"), -256.0)
    }

    @TestCase
    func mixedPrecedence() {
        @Expect(evaluate("1 + 3 * 2^3 / 4 - 2"), 5.0)
        @Expect(evaluate("2^(1+2)*3"), 24.0)
    }

    @TestCase
    func realFractionalExponent() {
        @Expect(evaluate("9^0.5"), 3.0)
        @Expect(evaluate("16^-.5"), 0.25)
    }

    @TestCase
    func zeroConventions() {
        @Expect(evaluate("0^0"), 1.0)
        @Expect(evaluate("0^3"), 0.0)
        @Expect(evaluate("2^0"), 1.0)
    }

    @TestCase
    func negativeZeroNegativePower() {
        checkError("(-0)^-1", "DIVISION_BY_ZERO", 1, 5)
    }

    @TestCase
    func negativeBaseFraction() {
        checkError("(-4)\r\n  ^.5", "POWER_DOMAIN", 2, 3)
    }

    @TestCase
    func overflowInInnerPower() {
        checkError("2^10^400", "NON_FINITE", 1, 5)
    }

    @TestCase
    func underflow() {
        @Expect(evaluate("2^-2000"), 0.0)
    }

    @TestCase
    func missingExponent() {
        checkError("2^-", "EXPECTED_OPERAND", 1, 4)
        checkError("2^", "EXPECTED_OPERAND", 1, 3)
    }

    @TestCase
    func unexpectedOperator() {
        checkError("2^^3", "EXPECTED_OPERAND", 1, 3)
        checkError("^3", "EXPECTED_OPERAND", 1, 1)
    }

    @TestCase
    func longPowerChain() {
        let text = StringBuilder("2")
        for (_ in 0..10000) { text.append("^1") }
        @Expect(evaluate(text.toString()), 2.0)
    }

    @TestCase
    func compiledVariablesAndSnapshot() {
        let ev = Evaluator()
        let formula = CompiledExpression("base^exponent")
        ev.bind("base", 4.0)
        ev.bind("exponent", 2.0)
        let first = formula.evaluateAsync(ev)
        ev.bind("exponent", 0.5)
        @Expect(first.get(), 16.0)
        @Expect(formula.evaluate(ev), 2.0)
        @Expect(ev.evaluate("base^exponent"), 2.0)
    }

    @TestCase
    func runtimeDomainErrorAndReuse() {
        let formula = CompiledExpression("(-4)^x")
        let ev = Evaluator()
        ev.bind("x", 0.5)
        let error = captureError({ => formula.evaluateAsync(ev).get() })
        @Expect(error.code, "POWER_DOMAIN")
        @Expect(error.column, 5)
        ev.bind("x", 3.0)
        @Expect(formula.evaluate(ev), -64.0)
    }

    @TestCase
    func leftOperandErrorFirst() {
        checkError("unknown ^ ((-4)^.5)", "UNKNOWN_VARIABLE", 1, 1)
    }
}
