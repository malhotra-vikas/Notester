import SwiftUI

struct VeraView: View {
    let url: String
    let emailLoggedIn: String
    @State private var isLoading: Bool = true
    @State private var accuracyScore: Int = 0
    @State private var quote: String = ""
    @State private var summary: String = ""
    @State private var sources: [String] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Image("verav2white") // Make sure you have this image in your asset catalog
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                    Spacer()
                }
                .padding()
                .background(Color.blue)
                
                // URL and Login
                Text(url)
                    .font(.headline)
                
                //Text("Logged in as: \(emailLoggedIn)")
                
                // Loading Screen
                if isLoading {
                    ProgressView("Verifying content...")
                } else {
                    // Accuracy Score
                    VStack {
                        Text("Accuracy Score")
                            .font(.headline)
                        ZStack {
                            Circle()
                                .stroke(lineWidth: 20)
                                .opacity(0.3)
                                .foregroundColor(.blue)
                            
                            Circle()
                                .trim(from: 0.0, to: CGFloat(accuracyScore) / 100)
                                .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                                .foregroundColor(.blue)
                                .rotationEffect(Angle(degrees: 270.0))
                            
                            Text("\(accuracyScore)%")
                                .font(.title)
                                .bold()
                        }
                        .frame(width: 150, height: 150)
                    }
                    
                    // Quote
                    Text(quote)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    
                    // Sources
                    VStack(alignment: .leading) {
                        Text("Top verified sources:")
                            .font(.headline)
                        ForEach(sources, id: \.self) { source in
                            Text("• \(source)")
                        }
                    }
                    .padding()
                    
                    // Summary
                    Text("According to")
                        .font(.headline)
                    Text(summary)
                        .padding()
                }
            }
            .padding()
        }
        .onAppear(perform: loadData)
    }
    
    private func loadData() {
        // Simulate API call or data loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.accuracyScore = Int.random(in: 70...95)
            self.quote = "This is a sample quote from the verified content."
            self.summary = "This is a summary of the verified content."
            self.sources = ["Source 1", "Source 2", "Source 3"]
            self.isLoading = false
        }
    }
}

struct VeraView_Previews: PreviewProvider {
    static var previews: some View {
        VeraView(url: "https://example.com", emailLoggedIn: "user@example.com")
    }
}
