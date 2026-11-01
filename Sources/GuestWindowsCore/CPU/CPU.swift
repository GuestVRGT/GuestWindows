import Foundation

/// Errors surfaced by the interpreter when it hits something it does not
/// yet implement. The CPU must fail loudly here rather than silently
/// skip bytes — a wrong decode compounds instantly.
public enum CPUError: Error, CustomStringConvertible {
    case unimplementedOpcode(UInt8, atCS: UInt16, atIP: UInt16)
    case halted

    public var description: String {
        switch self {
        case .unimplementedOpcode(let op, let cs, let ip):
            let opHex = String(format: "0x%02X", op)
            let csHex = String(format: "0x%04X", cs)
            let ipHex = String(format: "0x%04X", ip)
            return "Unimplemented opcode \(opHex) at CS:IP \(csHex):\(ipHex)"
        case .halted:
            return "CPU halted (HLT executed)"
        }
    }
}

/// A 16-bit real-mode x86 interpreter covering a first, deliberately
/// small subset of the instruction set. This is Milestone 2/5 work:
/// the goal right now is correctness and testability on simple
/// programs, not coverage. Every opcode here has a matching unit test.
///
/// Explicitly NOT yet implemented (tracked for later milestones):
/// ModRM-addressed instructions, string instructions, protected mode,
/// paging, interrupts/exceptions, segment overrides, the 0x66/0x67
/// operand/address size prefixes, and everything past this tiny subset.
public final class CPU {
    public var registers = GeneralRegisters()
    public var segments = SegmentRegisters()
    public var flags = EFLAGS()
    public var ip: UInt16 = 0
    public var halted = false

    public let memory: MemoryBus

    public init(memory: MemoryBus) {
        self.memory = memory
    }

    /// Resets to the real power-on CPU state (CS=F000, IP=FFF0 on real
    /// hardware; test programs typically override this before running).
    public func reset(csResetVector: UInt16 = 0xF000, ipResetVector: UInt16 = 0xFFF0) {
        registers = GeneralRegisters()
        segments = SegmentRegisters()
        segments.cs = csResetVector
        flags = EFLAGS()
        ip = ipResetVector
        halted = false
    }

    /// Executes a single instruction. Returns the opcode byte executed,
    /// primarily so tests can assert on what actually ran.
    @discardableResult
    public func step() throws -> UInt8 {
        if halted { throw CPUError.halted }

        let opcode = fetchByte()

        switch opcode {
        case 0x90: // NOP
            break

        case 0xF4: // HLT
            halted = true

        // MOV r8, imm8  (0xB0 + reg)
        case 0xB0...0xB7:
            let value = fetchByte()
            setByteRegister(index: Int(opcode - 0xB0), value: value)

        // MOV r16, imm16  (0xB8 + reg)
        case 0xB8...0xBF:
            let value = fetchWord()
            setWordRegister(index: Int(opcode - 0xB8), value: value)

        // ADD AL, imm8
        case 0x04:
            let operand = fetchByte()
            let a = registers.AL
            let result = Int(a) + Int(operand)
            flags.updateArithmeticFlags8(result: result, operandA: a, operandB: operand, isSubtraction: false)
            registers.AL = UInt8(truncatingIfNeeded: result)

        // ADD AX, imm16
        case 0x05:
            let operand = fetchWord()
            let a = registers.AX
            let result = UInt32(a) &+ UInt32(operand)
            registers.AX = UInt16(truncatingIfNeeded: result)
            flags.zero = registers.AX == 0
            flags.carry = result > 0xFFFF
            flags.sign = (registers.AX & 0x8000) != 0

        // INC r16  (0x40 + reg)
        case 0x40...0x47:
            let idx = Int(opcode - 0x40)
            let v = wordRegister(index: idx)
            setWordRegister(index: idx, value: v &+ 1)

        // DEC r16  (0x48 + reg)
        case 0x48...0x4F:
            let idx = Int(opcode - 0x48)
            let v = wordRegister(index: idx)
            setWordRegister(index: idx, value: v &- 1)

        // JMP rel8 (short jump)
        case 0xEB:
            let rel = Int8(bitPattern: fetchByte())
            ip = UInt16(truncatingIfNeeded: Int(ip) + Int(rel))

        default:
            // Roll IP back to the opcode byte so the error is precisely
            // located, and so a caller could in principle resume after
            // patching in support for this opcode.
            ip = ip &- 1
            throw CPUError.unimplementedOpcode(opcode, atCS: segments.cs, atIP: ip)
        }

        return opcode
    }

    /// Runs until HLT or an error, with a hard step ceiling so a bad
    /// decode (e.g. an infinite jump loop) can't hang the caller.
    public func run(maxSteps: Int = 1_000_000) throws {
        for _ in 0..<maxSteps {
            try step()
        }
    }

    // MARK: - Fetch helpers (CS:IP addressed)

    private func fetchByte() -> UInt8 {
        let addr = MemoryBus.linearAddress(segment: segments.cs, offset: ip)
        let b = memory.readByte(addr)
        ip = ip &+ 1
        return b
    }

    private func fetchWord() -> UInt16 {
        let lo = fetchByte()
        let hi = fetchByte()
        return UInt16(lo) | (UInt16(hi) << 8)
    }

    // MARK: - Register index mapping (Intel encoding order: AX,CX,DX,BX,SP,BP,SI,DI)

    private func wordRegister(index: Int) -> UInt16 {
        switch index {
        case 0: return registers.AX
        case 1: return registers.CX
        case 2: return registers.DX
        case 3: return registers.BX
        case 4: return registers.esp.loWord
        case 5: return registers.ebp.loWord
        case 6: return registers.esi.loWord
        case 7: return registers.edi.loWord
        default: fatalError("Invalid register index \(index)")
        }
    }

    private func setWordRegister(index: Int, value: UInt16) {
        switch index {
        case 0: registers.AX = value
        case 1: registers.CX = value
        case 2: registers.DX = value
        case 3: registers.BX = value
        case 4: registers.esp = value32(low: value, high: registers.esp.hiWord)
        case 5: registers.ebp = value32(low: value, high: registers.ebp.hiWord)
        case 6: registers.esi = value32(low: value, high: registers.esi.hiWord)
        case 7: registers.edi = value32(low: value, high: registers.edi.hiWord)
        default: fatalError("Invalid register index \(index)")
        }
    }

    private func setByteRegister(index: Int, value: UInt8) {
        switch index {
        case 0: registers.AL = value
        case 1: registers.CL = value
        case 2: registers.DL = value
        case 3: registers.BL = value
        case 4: registers.AH = value
        case 5: registers.CH = value
        case 6: registers.DH = value
        case 7: registers.BH = value
        default: fatalError("Invalid register index \(index)")
        }
    }

    private func value32(low: UInt16, high: UInt16) -> UInt32 {
        (UInt32(high) << 16) | UInt32(low)
    }
}

private extension UInt32 {
    var loWord: UInt16 { UInt16(truncatingIfNeeded: self) }
    var hiWord: UInt16 { UInt16(truncatingIfNeeded: self >> 16) }
}
