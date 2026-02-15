import SwiftUI

struct VirtualizerView: View {
    @State private var strength: Float = 25.0
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Virtualization strength")
                    Spacer()
                    Text(String(format: "%.0f%%", strength))
                }
                Slider(value: $strength, in: 0...100, step: 1)
            }
        }
        .navigationTitle("Virtualizer")
    }
}
