import SwiftUI

struct ContentView: View {
    @State private var appeared = false
    @State private var pulse    = false
    @EnvironmentObject var flow: AppFlowStore

    var body: some View {
        ZStack {
            Color.vaultBg.ignoresSafeArea()

            // Subtle radial glow centered on title
            RadialGradient(
                colors: [Color.vault.opacity(0.07), Color.clear],
                center: .center,
                startRadius: 10,
                endRadius: 300
            )
            .ignoresSafeArea()

            // Faint scan-line decoration
            VStack(spacing: 18) {
                ForEach(0..<20, id: \.self) { _ in
                    Rectangle()
                        .fill(Color(white: 1).opacity(0.018))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo block
                VStack(spacing: 16) {
                    Text("SENTIENCE")
                        .font(.system(size: 52, weight: .black))
                        .foregroundColor(.vault)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 18)
                        .animation(.easeOut(duration: 0.7), value: appeared)

                    // Accent rule
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(Color.vault.opacity(0.35))
                            .frame(height: 1)
                            .frame(maxWidth: 48)
                        Circle()
                            .fill(Color.vault)
                            .frame(width: 4, height: 4)
                        Rectangle()
                            .fill(Color.vault.opacity(0.35))
                            .frame(height: 1)
                            .frame(maxWidth: 48)
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.7).delay(0.1), value: appeared)

                    Text("by AMPS Financial")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(white: 0.35))
                        .tracking(2.5)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.7).delay(0.2), value: appeared)
                }

                Spacer()

                // Tap to begin
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.vault)
                        .frame(width: 5, height: 5)
                        .scaleEffect(pulse ? 1.5 : 1.0)
                        .opacity(pulse ? 0.3 : 1.0)

                    Text("TAP TO BEGIN")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(white: 0.38))
                        .tracking(3.5)
                }
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.7).delay(0.4), value: appeared)
                .padding(.bottom, 56)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { flow.showMain = true }
        .onAppear {
            appeared = true
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
                .delay(0.6)
            ) {
                pulse = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppFlowStore())
}
