import SwiftUI

struct ChannelBalanceView: View {
    @State private var leftGain: Float = -0.1
    @State private var rightGain: Float = -0.1
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Left")
                    Spacer()
                    Text(String(format: "%.1f dB", leftGain))
                }
                Slider(value: $leftGain, in: -12...12, step: 0.1)
                
                HStack {
                    Text("Right")
                    Spacer()
                    Text(String(format: "%.1f dB", rightGain))
                }
                Slider(value: $rightGain, in: -12...12, step: 0.1)
            }
        }
        .navigationTitle("Channel Balance")
    }
}
