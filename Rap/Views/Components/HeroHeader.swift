import SwiftUI

// MARK: - Track hero (album-art style with gradient)
struct TrackHeroHeader: View {
    let title: String
    let artist: String
    var isLoading: Bool = false
    var artworkUrl: String? = nil
    var hasPreview: Bool = false
    var isPlayingPreview: Bool = false
    var onAnalyze: (() -> Void)? = nil
    var onTogglePreview: (() -> Void)? = nil

    private var initials: String {
        let words = title.components(separatedBy: " ")
        return words.prefix(2).compactMap { $0.first.map(String.init) }.joined()
    }

    private var gradientColors: [Color] {
        let hash = abs(title.hashValue)
        let palettes: [[Color]] = [
            [Color(hex: "#1a0d2e"), Color(hex: "#16213e")],
            [Color(hex: "#0d1b0d"), Color(hex: "#0a2a1a")],
            [Color(hex: "#1a0d0d"), Color(hex: "#2a0a0a")],
            [Color(hex: "#0d0d2a"), Color(hex: "#0a1a3a")],
            [Color(hex: "#1a1200"), Color(hex: "#2a1e00")],
        ]
        return palettes[hash % palettes.count]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors + [Color.appBackground],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer()

                // Album art
                ZStack {
                    if let urlStr = artworkUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 160, height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            default:
                                artPlaceholder
                            }
                        }
                    } else {
                        artPlaceholder
                    }

                    // Preview play overlay
                    if hasPreview {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button {
                                    onTogglePreview?()
                                } label: {
                                    Image(systemName: isPlayingPreview ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.7), radius: 4)
                                        .padding(8)
                                }
                            }
                        }
                        .frame(width: 160, height: 160)
                    }
                }
                .shadow(color: .black.opacity(0.6), radius: 20, y: 8)

                // Preview label
                if hasPreview {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.system(size: 9))
                        Text(isPlayingPreview ? "再生中 (30秒)" : "試聴できます")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundColor(isPlayingPreview ? Color.gold : .gray)
                    .padding(.top, 6)
                }

                Spacer().frame(height: hasPreview ? 12 : 20)

                // Title & artist
                VStack(spacing: 4) {
                    Text(title.isEmpty ? "曲名を入力" : title)
                        .font(.system(.title2, weight: .bold))
                        .foregroundColor(title.isEmpty ? .gray : .white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(artist.isEmpty ? "アーティスト名を入力" : artist)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(artist.isEmpty ? .gray.opacity(0.6) : Color.gold)
                }

                Spacer().frame(height: 24)

                // Analyze button
                if let action = onAnalyze {
                    Button(action: action) {
                        HStack(spacing: 10) {
                            if isLoading {
                                ProgressView().tint(Color(hex: "#0d0d0d"))
                            } else {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 20))
                            }
                            Text(isLoading ? "解析中..." : "解析する")
                                .font(.system(.subheadline, weight: .bold))
                        }
                        .foregroundColor(isLoading ? .gray.opacity(0.6) : Color(hex: "#0d0d0d"))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(isLoading ? Color.gray.opacity(0.3) : Color.gold)
                        .cornerRadius(30)
                    }
                    .disabled(isLoading)
                }

                Spacer().frame(height: 24)
            }
        }
        .frame(height: hasPreview ? 380 : 360)
    }

    private var artPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [Color.gold.opacity(0.25), Color(hex: "#1a1a1a")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gold.opacity(0.15), lineWidth: 1)
            )
            .frame(width: 160, height: 160)
            .overlay(
                Group {
                    if initials.isEmpty {
                        Image(systemName: "music.note")
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundColor(Color.gold.opacity(0.4))
                    } else {
                        Text(initials)
                            .font(.system(size: 52, weight: .black, design: .monospaced))
                            .foregroundColor(Color.gold.opacity(0.5))
                    }
                }
            )
    }
}

// MARK: - Custom segment control
struct SegmentControl: View {
    let tabs: [String]
    @Binding var selected: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selected = i }
                } label: {
                    VStack(spacing: 6) {
                        Text(tabs[i])
                            .font(.system(size: 13, weight: selected == i ? .bold : .regular,
                                         design: .monospaced))
                            .foregroundColor(selected == i ? .white : .gray)
                            .frame(maxWidth: .infinity)
                        Rectangle()
                            .fill(selected == i ? Color.gold : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .background(Color.appBackground)
    }
}
