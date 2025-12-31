import SwiftUI



struct ContentView: View {
    @State private var blink = false
    @EnvironmentObject var flow: AppFlowStore
    
    
    var body: some View {
        ZStack {
            
            //visual gradient for design
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.0, green: 0.0, blue: 0.2),
                    Color(red: 0.0, green: 0.0, blue: 0.5)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            //company and parent company name
            VStack {
                Spacer()
                Text("Sentience")
                    .foregroundColor(.yellow)
                    .underline(true, color: .yellow)
                    .font(.system(size: 48, weight: .semibold, design: .serif))
                Text("by AMPS Financial")
                    .foregroundColor(.yellow)
                    .font(.system(size: 12, weight: .light, design: .serif))
                Spacer()
                Text("Tap to Begin")
                    .foregroundColor(.white)
                    .opacity(blink ? 0 : 1) //button blinks
                    .padding(.bottom, 40)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    blink.toggle()
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { flow.showMain = true }
        //when screen is tapped, move to next screen
    }
}



#Preview {
    ContentView()
        .environmentObject(PortfolioStore())
        .environmentObject(AppFlowStore())
        .environmentObject(WatchlistStore())
}

