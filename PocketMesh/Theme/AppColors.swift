import SwiftUI

/// Centralized color definitions for the app.
///
/// Colors are organized by purpose:
/// - Identity palettes: Colors for identifying senders, contacts, and nodes
/// - UI elements: Colors for interface components like message bubbles
enum AppColors {

    // MARK: - Identity Palettes

    /// Colors for sender names in channel messages.
    ///
    /// The standard palette uses muted earth tones designed for visual harmony.
    /// For users with increased contrast enabled, use `paletteHighContrast` which
    /// meets WCAG AA 4.5:1 contrast ratio against white backgrounds.
    enum SenderName {
        /// Standard muted earth tone palette.
        static let palette: [Color] = [
            Color(hex: 0xcc7a5c), // coral
            Color(hex: 0x5c8a99), // slate teal
            Color(hex: 0x8c7a99), // dusty violet
            Color(hex: 0x7a9988), // sage
            Color(hex: 0x997a8c), // dusty rose
            Color(hex: 0x99885c), // ochre
            Color(hex: 0x5c7a99), // slate blue
            Color(hex: 0xb5856b), // terracotta
            Color(hex: 0x8a9966), // olive
            Color(hex: 0x8c5c7a), // dusty plum
        ]

        /// High-contrast palette meeting WCAG AA 4.5:1 contrast ratio.
        /// Used when `ColorSchemeContrast.increased` is enabled.
        static let paletteHighContrast: [Color] = [
            Color(hex: 0x9e5a3c), // coral (darkened)
            Color(hex: 0x3d6a79), // slate teal (darkened)
            Color(hex: 0x6a5a79), // dusty violet (darkened)
            Color(hex: 0x5a7968), // sage (darkened)
            Color(hex: 0x795a6c), // dusty rose (darkened)
            Color(hex: 0x79683c), // ochre (darkened)
            Color(hex: 0x3c5a79), // slate blue (darkened)
            Color(hex: 0x8a654b), // terracotta (darkened)
            Color(hex: 0x6a7946), // olive (darkened)
            Color(hex: 0x6c3c5a), // dusty plum (darkened)
        ]

        /// Returns a color for the given sender name.
        ///
        /// Uses XOR hashing to deterministically map names to colors.
        /// The same name always returns the same color.
        ///
        /// - Parameters:
        ///   - name: The sender's display name.
        ///   - highContrast: When true, uses high-contrast palette for accessibility.
        /// - Returns: A color from the appropriate palette.
        static func color(for name: String, highContrast: Bool = false) -> Color {
            let colors = highContrast ? paletteHighContrast : palette
            let hash = name.utf8.reduce(0) { $0 ^ Int($1) }
            return colors[abs(hash) % colors.count]
        }
    }

    /// Colors for contact avatars in direct message lists.
    enum ContactAvatar {
        /// Uses a subset of SenderName palette for visual consistency.
        static let palette: [Color] = [
            SenderName.palette[0], // coral
            SenderName.palette[1], // slate teal
            SenderName.palette[2], // dusty violet
            SenderName.palette[3], // sage
        ]

        /// Returns a color for the given contact.
        ///
        /// Uses XOR hashing on public key prefix for deterministic coloring.
        /// If publicKey is empty, returns the first palette color.
        ///
        /// - Parameter publicKey: The contact's public key.
        /// - Returns: A color from the palette.
        static func color(for publicKey: Data) -> Color {
            let hash = publicKey.prefix(4).reduce(0) { $0 ^ Int($1) }
            return palette[abs(hash) % palette.count]
        }
    }

    /// Colors for remote node avatars.
    enum NodeAvatar {
        /// Orange palette for room server nodes.
        enum RoomServer {
            static let palette: [Color] = [
                Color(hex: 0xff8800), // orange
                Color(hex: 0xff6600), // orange (darker)
                Color(hex: 0xffaa00), // orange (lighter)
                Color(hex: 0xcc5500), // orange (dark)
            ]

            /// Returns a color for the given room server.
            ///
            /// If publicKey is empty, returns the first palette color.
            static func color(for publicKey: Data) -> Color {
                let hash = publicKey.prefix(4).reduce(0) { $0 ^ Int($1) }
                return palette[abs(hash) % palette.count]
            }
        }

        /// Blue palette for repeater nodes.
        enum Repeater {
            static let palette: [Color] = [
                Color(hex: 0x00aaff), // cyan
                Color(hex: 0x0088cc), // medium blue
            ]

            /// Returns a color for the repeater at the given index.
            static func color(at index: Int) -> Color {
                palette[index % palette.count]
            }
        }
    }

    /// Color for channel avatars.
    enum ChannelAvatar {
        static let color = Color(hex: 0x336688) // slate blue
    }

    // MARK: - UI Elements

    /// Colors for message bubbles and related UI.
    enum Message {
        static let outgoingBubble = Color(hex: 0x2463EB)
        static let outgoingBubbleFailed = Color.red.opacity(0.8)
        static let incomingBubble = Color(.systemGray5)
    }
}
