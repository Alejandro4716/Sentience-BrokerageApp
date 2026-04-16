import SwiftUI

struct AddTickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    var onAdd: (String) -> Void

    private var canAdd: Bool { !text.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            Color.vaultBg.ignoresSafeArea()
            VStack(spacing: 0) {

                // Header
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(white: 0.5))
                    Spacer()
                    Text("ADD TICKER")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.vault)
                    Spacer()
                    Text("Cancel").font(.system(size: 14)).foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 24)

                // Input card
                VStack(alignment: .leading, spacing: 8) {
                    Text("SYMBOL")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(white: 0.38))
                        .padding(.horizontal, 4)
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(white: 0.4))
                        TextField("e.g. AAPL", text: $text)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .background(Color.vaultCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 16)

                Spacer()

                // Add button
                Button {
                    onAdd(text.trimmingCharacters(in: .whitespaces).uppercased())
                    dismiss()
                } label: {
                    Text("ADD TO WATCHLIST")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(canAdd ? .black : Color(white: 0.3))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canAdd ? Color.vault : Color(white: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!canAdd)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }
}
