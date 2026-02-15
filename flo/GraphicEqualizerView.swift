import SwiftUI

struct GraphicEqualizerView: View {
    @ObservedObject var audioProcessor = AudioProcessor.shared
    let frequencies = [54, 148, 403, 1096, 2980, 8103]
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Presets")
                    Spacer()
                    Menu("V‑shaped") {
                        Button("V‑shaped") { setPreset("v") }
                        Button("U‑shaped") { setPreset("u") }
                        Button("M‑shaped") { setPreset("m") }
                    }
                }
            }
            
            Section {
                ForEach(0..<frequencies.count, id: \.self) { index in
                    HStack {
                        Text("\(frequencies[index]) Hz")
                            .frame(width: 70, alignment: .leading)
                            .font(.caption)
                        Slider(value: $audioProcessor.eqBands[index], in: -7.5...7.5, step: 0.5)
                        Text(String(format: "%.1f", audioProcessor.eqBands[index]))
                            .frame(width: 40, alignment: .trailing)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Graphic Equalizer")
        .onDisappear {
            audioProcessor.saveSettings()
        }
    }
    
    func setPreset(_ shape: String) {
        switch shape {
        case "v":
            audioProcessor.eqBands = [3.0, 0.0, -2.0, -2.0, 0.0, 3.0]
        case "u":
            audioProcessor.eqBands = [-3.0, 0.0, 2.0, 2.0, 0.0, -3.0]
        case "m":
            audioProcessor.eqBands = [0.0, 3.0, 0.0, 0.0, 3.0, 0.0]
        default:
            break
        }
    }
}
