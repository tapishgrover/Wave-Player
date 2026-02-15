import SwiftUI

struct AutoEqView: View {
    let headphones = ["Skullcandy Crusher Wireless", "Sony WH-1000XM4", "Apple AirPods Max"]
    @State private var selectedHeadphone = "Skullcandy Crusher Wireless"
    
    var body: some View {
        List {
            Section {
                Picker("Headphone model", selection: $selectedHeadphone) {
                    ForEach(headphones, id: \.self) { model in
                        Text(model)
                    }
                }
            }
            
            Section {
                // Placeholder for the EQ curve graph
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 150)
                    .overlay(
                        VStack {
                            Text("AutoEq curve")
                                .foregroundColor(.secondary)
                            Text("(to be implemented)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
        .navigationTitle("AutoEq")
    }
}
