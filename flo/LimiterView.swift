import SwiftUI

struct LimiterView: View {
    @ObservedObject var audioProcessor = AudioProcessor.shared
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Attack time")
                    Spacer()
                    Text(String(format: "%.0f ms", audioProcessor.limiterAttack))
                }
                Slider(value: $audioProcessor.limiterAttack, in: 0.1...100, step: 0.1)
                
                HStack {
                    Text("Release time")
                    Spacer()
                    Text(String(format: "%.0f ms", audioProcessor.limiterRelease))
                }
                Slider(value: $audioProcessor.limiterRelease, in: 10...1000, step: 1)
                
                HStack {
                    Text("Pre‑gain")
                    Spacer()
                    Text(String(format: "%.1f dB", audioProcessor.limiterPreGain))
                }
                Slider(value: $audioProcessor.limiterPreGain, in: -12...12, step: 0.5)
            }
        }
        .navigationTitle("Limiter")
        .onDisappear {
            audioProcessor.saveSettings()
        }
    }
}
