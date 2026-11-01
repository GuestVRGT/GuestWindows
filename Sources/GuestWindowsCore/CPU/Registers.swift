import Foundation

/// 32-bit general purpose registers, addressable as 32/16/8-bit views,
/// matching real x86 register aliasing (EAX/AX/AH/AL etc).
public struct GeneralRegisters {
    private var eax: UInt32 = 0
    private var ebx: UInt32 = 0
    private var ecx: UInt32 = 0
    private var edx: UInt32 = 0
    public var esi: UInt32 = 0
    public var edi: UInt32 = 0
    public var ebp: UInt32 = 0
    public var esp: UInt32 = 0

    public init() {}

    // MARK: 32-bit views
    public var EAX: UInt32 { get { eax } set { eax = newValue } }
    public var EBX: UInt32 { get { ebx } set { ebx = newValue } }
    public var ECX: UInt32 { get { ecx } set { ecx = newValue } }
    public var EDX: UInt32 { get { edx } set { edx = newValue } }

    // MARK: 16-bit views (low 16 bits of the 32-bit register)
    public var AX: UInt16 {
        get { UInt16(truncatingIfNeeded: eax) }
        set { eax = (eax & 0xFFFF_0000) | UInt32(newValue) }
    }
    public var BX: UInt16 {
        get { UInt16(truncatingIfNeeded: ebx) }
        set { ebx = (ebx & 0xFFFF_0000) | UInt32(newValue) }
    }
    public var CX: UInt16 {
        get { UInt16(truncatingIfNeeded: ecx) }
        set { ecx = (ecx & 0xFFFF_0000) | UInt32(newValue) }
    }
    public var DX: UInt16 {
        get { UInt16(truncatingIfNeeded: edx) }
        set { edx = (edx & 0xFFFF_0000) | UInt32(newValue) }
    }

    // MARK: 8-bit views (AL/AH etc.)
    public var AL: UInt8 {
        get { UInt8(truncatingIfNeeded: eax) }
        set { eax = (eax & 0xFFFF_FF00) | UInt32(newValue) }
    }
    public var AH: UInt8 {
        get { UInt8(truncatingIfNeeded: eax >> 8) }
        set { eax = (eax & 0xFFFF_00FF) | (UInt32(newValue) << 8) }
    }
    public var BL: UInt8 {
        get { UInt8(truncatingIfNeeded: ebx) }
        set { ebx = (ebx & 0xFFFF_FF00) | UInt32(newValue) }
    }
    public var BH: UInt8 {
        get { UInt8(truncatingIfNeeded: ebx >> 8) }
        set { ebx = (ebx & 0xFFFF_00FF) | (UInt32(newValue) << 8) }
    }
    public var CL: UInt8 {
        get { UInt8(truncatingIfNeeded: ecx) }
        set { ecx = (ecx & 0xFFFF_FF00) | UInt32(newValue) }
    }
    public var CH: UInt8 {
        get { UInt8(truncatingIfNeeded: ecx >> 8) }
        set { ecx = (ecx & 0xFFFF_00FF) | (UInt32(newValue) << 8) }
    }
    public var DL: UInt8 {
        get { UInt8(truncatingIfNeeded: edx) }
        set { edx = (edx & 0xFFFF_FF00) | UInt32(newValue) }
    }
    public var DH: UInt8 {
        get { UInt8(truncatingIfNeeded: edx >> 8) }
        set { edx = (edx & 0xFFFF_00FF) | (UInt32(newValue) << 8) }
    }
}

/// Real-mode style segment registers. Protected mode will layer
/// descriptor-cache interpretation on top of these in a later milestone.
public struct SegmentRegisters {
    public var cs: UInt16 = 0xF000 // BIOS reset vector segment, matches real hardware power-on state
    public var ds: UInt16 = 0
    public var es: UInt16 = 0
    public var fs: UInt16 = 0
    public var gs: UInt16 = 0
    public var ss: UInt16 = 0

    public init() {}
}

/// EFLAGS register, bit-accurate to the real x86 layout where it matters
/// for the instructions currently implemented.
public struct EFLAGS {
    public var carry = false        // bit 0  (CF)
    public var reserved1 = true     // bit 1  (always 1)
    public var parity = false       // bit 2  (PF)
    public var auxCarry = false     // bit 4  (AF)
    public var zero = false         // bit 6  (ZF)
    public var sign = false         // bit 7  (SF)
    public var trap = false         // bit 8  (TF)
    public var interruptEnable = false // bit 9 (IF)
    public var direction = false    // bit 10 (DF)
    public var overflow = false     // bit 11 (OF)

    public init() {}

    public var rawValue: UInt32 {
        var v: UInt32 = 0
        if carry { v |= 1 << 0 }
        v |= 1 << 1
        if parity { v |= 1 << 2 }
        if auxCarry { v |= 1 << 4 }
        if zero { v |= 1 << 6 }
        if sign { v |= 1 << 7 }
        if trap { v |= 1 << 8 }
        if interruptEnable { v |= 1 << 9 }
        if direction { v |= 1 << 10 }
        if overflow { v |= 1 << 11 }
        return v
    }

    /// Updates SF/ZF/PF/CF/OF after an 8-bit arithmetic result, matching
    /// real x86 flag semantics for ADD-style operations.
    mutating func updateArithmeticFlags8(result: Int, operandA: UInt8, operandB: UInt8, isSubtraction: Bool) {
        let truncated = UInt8(truncatingIfNeeded: result)
        zero = truncated == 0
        sign = (truncated & 0x80) != 0
        parity = EFLAGS.evenParity(truncated)
        carry = isSubtraction ? (Int(operandA) < Int(operandB)) : (result > 0xFF)

        let signA = (operandA & 0x80) != 0
        let signB = (operandB & 0x80) != 0
        let signR = (truncated & 0x80) != 0
        if isSubtraction {
            overflow = (signA != signB) && (signR != signA)
        } else {
            overflow = (signA == signB) && (signR != signA)
        }
    }

    private static func evenParity(_ byte: UInt8) -> Bool {
        byte.nonzeroBitCount % 2 == 0
    }
}
