import Foundation

/// Fluffy's ginger fur, as 0xRRGGBB. (The berry1…4 names are kept from the original blueberry so the
/// cursor, bubbles and panels pick up the new colors without changes.)
public enum Palette {
    public static let berry1: UInt32 = 0xFFD9A8  // cream apricot
    public static let berry2: UInt32 = 0xF6A04D  // ginger
    public static let berry3: UInt32 = 0xE0782A  // deep ginger
    public static let berry4: UInt32 = 0xA8521C  // burnt orange
    public static let nose: UInt32 = 0x5B2A12    // dark brown for stripes, mouth and lines
    public static let ink: UInt32 = 0x221510
    public static let inkSoft: UInt32 = 0xCDB8A8
    public static let panel: UInt32 = 0x2A1E18

    /// Fluffy-specific touches.
    public static let cream: UInt32 = 0xFFF1DE   // muzzle, chest and inner ears
    public static let pink: UInt32 = 0xF59CA8    // nose, ear insides, tongue
    public static let iris: UInt32 = 0x9BC53D    // green-gold cat eyes
    public static let irisDeep: UInt32 = 0x5E8A1E

    public static let gradient: [UInt32] = [berry1, berry2, berry3, berry4]
    public static let gradientStops: [Double] = [0, 0.34, 0.68, 1]

    public static func rgb(_ hex: UInt32) -> (r: Double, g: Double, b: Double) {
        (Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }
}
