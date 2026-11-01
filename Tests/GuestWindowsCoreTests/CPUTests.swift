import XCTest
@testable import GuestWindowsCore

final class CPUTests: XCTestCase {

    private func makeCPU(program: [UInt8], loadAt: UInt16 = 0x0000, cs: UInt16 = 0x1000) -> CPU {
        let memory = MemoryBus(sizeInBytes: 1 << 20) // 1 MB, like an 8086 address space
        let cpu = CPU(memory: memory)
        cpu.reset(csResetVector: cs, ipResetVector: loadAt)
        let linear = MemoryBus.linearAddress(segment: cs, offset: loadAt)
        memory.load(program, at: linear)
        return cpu
    }

    func testMovALImmediate() throws {
        // B0 2A -> MOV AL, 0x2A
        let cpu = makeCPU(program: [0xB0, 0x2A])
        try cpu.step()
        XCTAssertEqual(cpu.registers.AL, 0x2A)
    }

    func testMovAXImmediate() throws {
        // B8 3412 -> MOV AX, 0x1234
        let cpu = makeCPU(program: [0xB8, 0x34, 0x12])
        try cpu.step()
        XCTAssertEqual(cpu.registers.AX, 0x1234)
    }

    func testAddALImmediateSetsZeroFlagOnWrap() throws {
        // B0 FF       -> MOV AL, 0xFF
        // 04 01       -> ADD AL, 0x01   => AL=0x00, ZF=1, CF=1
        let cpu = makeCPU(program: [0xB0, 0xFF, 0x04, 0x01])
        try cpu.step()
        try cpu.step()
        XCTAssertEqual(cpu.registers.AL, 0x00)
        XCTAssertTrue(cpu.flags.zero)
        XCTAssertTrue(cpu.flags.carry)
    }

    func testIncDecWordRegister() throws {
        // B8 0000     -> MOV AX, 0
        // 40          -> INC AX
        // 40          -> INC AX
        // 48          -> DEC AX
        let cpu = makeCPU(program: [0xB8, 0x00, 0x00, 0x40, 0x40, 0x48])
        try cpu.run(maxSteps: 4)
        XCTAssertEqual(cpu.registers.AX, 1)
    }

    func testHaltStopsExecution() throws {
        let cpu = makeCPU(program: [0x90, 0xF4, 0xB0, 0xFF]) // NOP, HLT, (never reached)
        XCTAssertThrowsError(try cpu.run(maxSteps: 10)) { error in
            guard case CPUError.halted = error else {
                return XCTFail("Expected .halted, got \(error)")
            }
        }
        XCTAssertEqual(cpu.registers.AL, 0, "Instruction after HLT must not execute")
    }

    func testUnimplementedOpcodeThrowsWithLocation() throws {
        let cpu = makeCPU(program: [0x0F]) // not implemented yet
        XCTAssertThrowsError(try cpu.step()) { error in
            guard case CPUError.unimplementedOpcode(let op, _, let ip) = error else {
                return XCTFail("Expected .unimplementedOpcode, got \(error)")
            }
            XCTAssertEqual(op, 0x0F)
            XCTAssertEqual(ip, 0x0000, "IP should roll back to point at the offending opcode")
        }
    }

    func testShortJumpForward() throws {
        // EB 01       -> JMP +1  (skip the next byte)
        // B0 FF       -> (skipped) MOV AL, 0xFF
        // B0 2A       -> MOV AL, 0x2A  <- landed here
        let cpu = makeCPU(program: [0xEB, 0x01, 0xB0, 0xFF, 0xB0, 0x2A])
        try cpu.step() // JMP
        try cpu.step() // MOV AL, 0x2A
        XCTAssertEqual(cpu.registers.AL, 0x2A)
    }

    func testRealModeSegmentWraparound() {
        // Classic 8086 address wraparound behavior used throughout real-mode code.
        let addr = MemoryBus.linearAddress(segment: 0xFFFF, offset: 0x0010)
        XCTAssertEqual(addr, 0x100000) // past 1MB, the famous A20 edge case
    }
}
