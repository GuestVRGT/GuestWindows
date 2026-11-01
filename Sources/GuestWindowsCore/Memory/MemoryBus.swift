import Foundation

/// A flat byte-addressable memory space. Real hardware segmentation
/// (segment:offset -> linear address) is resolved by the CPU before
/// calling into this bus; paging will sit in front of this in a later
/// milestone once protected mode exists.
public final class MemoryBus {
    public private(set) var bytes: [UInt8]
    public let sizeInBytes: Int

    public init(sizeInBytes: Int) {
        precondition(sizeInBytes > 0, "Memory size must be positive")
        self.sizeInBytes = sizeInBytes
        self.bytes = [UInt8](repeating: 0, count: sizeInBytes)
    }

    public func readByte(_ address: UInt32) -> UInt8 {
        guard Int(address) < sizeInBytes else { return 0xFF }
        return bytes[Int(address)]
    }

    public func writeByte(_ address: UInt32, _ value: UInt8) {
        guard Int(address) < sizeInBytes else { return }
        bytes[Int(address)] = value
    }

    public func readWord(_ address: UInt32) -> UInt16 {
        let lo = UInt16(readByte(address))
        let hi = UInt16(readByte(address &+ 1))
        return lo | (hi << 8)
    }

    public func writeWord(_ address: UInt32, _ value: UInt16) {
        writeByte(address, UInt8(truncatingIfNeeded: value))
        writeByte(address &+ 1, UInt8(truncatingIfNeeded: value >> 8))
    }

    /// Loads raw bytes (e.g. a test program or future BIOS image) at a
    /// given linear address.
    public func load(_ data: [UInt8], at address: UInt32) {
        for (i, byte) in data.enumerated() {
            writeByte(address &+ UInt32(i), byte)
        }
    }

    /// Real-mode segment:offset -> 20-bit linear address, matching the
    /// 8086-style wraparound address computation.
    public static func linearAddress(segment: UInt16, offset: UInt16) -> UInt32 {
        return (UInt32(segment) << 4) &+ UInt32(offset)
    }
}
