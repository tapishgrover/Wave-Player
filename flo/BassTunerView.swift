import SwiftUI

struct BassTunerView: View {
    let bassTypes = ["Sustain compressor", "Transient enhancer"]
    let cutoffFrequencies = ["60Hz", "80Hz", "100Hz", "120Hz"]
    
    @State private var selectedType = "Sustain compressor"
    @State private var selectedCutoff = "60Hz"
    @State private var postGain: Float = 0.0
    
    var body: some View {
        List {
            Section {
                Picker("Bass type", selection: $selectedType) {
                    ForEach(bassTypes, id: \.self) { type in
                        Text(type)
                    }
                }
                
                Picker("Cutoff frequency", selection: $selectedCutoff) {
                    ForEach(cutoffFrequencies, id: \.self) { freq in
                        Text(freq)
                    }
                }
                
                HStack {
                    Text("Post‑gain")
                    Spacer()
                    Text(String(format: "%.1f dB", postGain))
                }
                Slider(value: $postGain, in: -12...12, step: 0.5)
            }
        }
        .navigationTitle("Bass Tuner")
    }
}
