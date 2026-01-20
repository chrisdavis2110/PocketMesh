import SwiftUI
import PocketMeshServices

struct ChannelAvatar: View {
    let channel: ChannelDTO
    let size: CGFloat

    var body: some View {
        Image(systemName: channel.isPublicChannel ? "globe" : "number")
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(avatarColor, in: .circle)
    }

    private var avatarColor: Color {
        Color(hex: 0x336688)
    }
}
