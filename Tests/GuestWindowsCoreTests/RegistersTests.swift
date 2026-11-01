import XCTest
@testable import GuestWindowsCore

final class RegistersTests: XCTestCase {

    func testEAXSubRegisterAliasing() {
        var regs = GeneralRegisters()
        regs.EAX = 0x12345678
        XCTAssertEqual(regs.AX, 0x5678)
        XCTAssertEqual(regs.AH, 0x56)
        XCTAssertEqual(regs.AL, 0x78)
    }

    func testWritingALDoesNotDisturbUpperBits() {
        var regs = GeneralRegisters()
        regs.EAX = 0xAABBCCDD
        regs.AL = 0xFF
        XCTAssertEqual(regs.EAX, 0xAABBCCFF)
    }

    func testWritingAXDoesNotDisturbUpper16Bits() {
        var regs = GeneralRegisters()
        regs.EAX = 0xAABBCCDD
        regs.AX = 0x1122
        XCTAssertEqual(regs.EAX, 0xAABB1122)
    }

    func testEFLAGSRawValueHasReservedBitSet() {
        let flags = EFLAGS()
        // Bit 1 of EFLAGS is always 1 on real hardware.
        XCTAssertEqual(flags.rawValue & 0x2, 0x2)
    }

    func testArithmeticFlagsZeroAndCarryOnAdd() {
        var flags = EFLAGS()
        // 0xFF + 0x01 = 0x100 -> truncates to 0x00, sets ZF and CF
        flags.updateArithmeticFlags8(result: 0x100, operandA: 0xFF, operandB: 0x01, isSubtraction: false)
        XCTAssertTrue(flags.zero)
        XCTAssertTrue(flags.carry)
    }
}
