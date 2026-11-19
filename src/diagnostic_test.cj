package cjexpr

import std.unittest.*
import std.unittest.testmacro.*

func captureError<T>(operation: () -> T): ExprException {
    try {
        operation()
    } catch (e: ExprException) {
        return e
    }
    throw Exception("预期抛出 ExprException，实际求值成功")
}

private func checkError(expr: String, code: String, line: Int64, column: Int64): Unit {
    let e = captureError({ => evaluate(expr) })
    @Expect(e.code, code)
    @Expect(e.line, line)
    @Expect(e.column, column)
    @Expect(e.message.contains("第 ${line} 行，第 ${column} 列"))
}

@Test
class DiagnosticTests {
    @TestCase
    func emptyInput() {
        checkError("", "EXPECTED_OPERAND", 1, 1)
    }

    @TestCase
    func onlyWhitespace() {
        checkError(" \t\r\n ", "EXPECTED_OPERAND", 2, 2)
    }

    @TestCase
    func illegalSymbol() {
        checkError("2 @ 3", "INVALID_CHARACTER", 1, 3)
    }

    @TestCase
    func unicodeOperator() {
        checkError("3 × 5", "INVALID_CHARACTER", 1, 3)
    }

    @TestCase
    func illegalRune() {
        checkError("\u{1F642} + 2", "INVALID_CHARACTER", 1, 1)
    }

    @TestCase
    func embeddedNul() {
        checkError("1\0+2", "INVALID_CHARACTER", 1, 2)
    }

    @TestCase
    func isolatedPoint() {
        checkError(".", "INVALID_NUMBER", 1, 1)
    }

    @TestCase
    func repeatedPoint() {
        checkError("12.3.4", "INVALID_NUMBER", 1, 5)
    }

    @TestCase
    func missingExponent() {
        checkError("1e", "INVALID_NUMBER", 1, 3)
    }

    @TestCase
    func signedEmptyExponent() {
        checkError("1E-", "INVALID_NUMBER", 1, 4)
    }

    @TestCase
    func letterInExponent() {
        checkError("2eX", "INVALID_NUMBER", 1, 3)
    }

    @TestCase
    func decimalExponent() {
        checkError("2e2.1", "INVALID_NUMBER", 1, 4)
    }

    @TestCase
    func emptyGroup() {
        checkError("()", "EXPECTED_OPERAND", 1, 2)
    }

    @TestCase
    func missingRightOperand() {
        checkError("1+", "EXPECTED_OPERAND", 1, 3)
    }

    @TestCase
    func missingLeftOperand() {
        checkError("*2", "EXPECTED_OPERAND", 1, 1)
    }

    @TestCase
    func unaryPlus() {
        checkError("+2", "EXPECTED_OPERAND", 1, 1)
    }

    @TestCase
    func twoOperators() {
        checkError("2*/3", "EXPECTED_OPERAND", 1, 3)
    }

    @TestCase
    func bareUnary() {
        checkError("--", "EXPECTED_OPERAND", 1, 3)
    }

    @TestCase
    func adjacentNumbers() {
        checkError("2 3", "MISSING_OPERATOR", 1, 3)
    }

    @TestCase
    func implicitMultiplication() {
        checkError("2(3)", "MISSING_OPERATOR", 1, 2)
    }

    @TestCase
    func adjacentGroups() {
        checkError("(2)(3)", "MISSING_OPERATOR", 1, 4)
    }

    @TestCase
    func nameAfterNumber() {
        checkError("2cost", "MISSING_OPERATOR", 1, 2)
    }

    @TestCase
    func adjacentInGroup() {
        checkError("(1 2)", "MISSING_OPERATOR", 1, 4)
    }

    @TestCase
    func functionCall() {
        checkError("sin(1)", "MISSING_OPERATOR", 1, 4)
    }

    @TestCase
    func unmatchedOpen() {
        checkError("3*(1+2", "MISSING_CLOSE", 1, 3)
    }

    @TestCase
    func unmatchedClose() {
        checkError("(1))", "UNEXPECTED_CLOSE", 1, 4)
    }

    @TestCase
    func operandBeforeClose() {
        checkError("(1+)", "EXPECTED_OPERAND", 1, 4)
    }

    @TestCase
    func unknownName() {
        checkError("2 + missing", "UNKNOWN_VARIABLE", 1, 5)
    }

    @TestCase
    func zeroDivision() {
        checkError("8 / 0", "DIVISION_BY_ZERO", 1, 3)
    }

    @TestCase
    func computedZero() {
        checkError("8/(3-3)", "DIVISION_BY_ZERO", 1, 2)
    }

    @TestCase
    func negativeZero() {
        checkError("1 / -0.0", "DIVISION_BY_ZERO", 1, 3)
    }

    @TestCase
    func runtimeOverflow() {
        checkError("1e308*10", "NON_FINITE", 1, 6)
    }

    @TestCase
    func literalOverflow() {
        checkError("2 + 1e999", "NON_FINITE", 1, 5)
    }

    @TestCase
    func windowsNewline() {
        checkError("3 +\r\n  未", "INVALID_CHARACTER", 2, 3)
    }

    @TestCase
    func classicMacNewline() {
        checkError("1+\r\tmiss", "UNKNOWN_VARIABLE", 2, 2)
    }

    @TestCase
    func firstRuntimeError() {
        checkError("absent + (1/0)", "UNKNOWN_VARIABLE", 1, 1)
    }

    @TestCase
    func syntaxBeforeEvaluation() {
        checkError("1/0 +", "EXPECTED_OPERAND", 1, 6)
    }

    @TestCase
    func excessiveNesting() {
        checkError(nestedExpression(1000), "NESTING_LIMIT", 1, 65)
    }
}
