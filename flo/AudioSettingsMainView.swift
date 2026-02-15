import SwiftUI

struct AudioSettingsMainView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink("Graphic Equalizer", destination: GraphicEqualizerView())
                NavigationLink("Equal Loudness", destination: EqualLoudnessView())
                NavigationLink("Virtualizer", destination: VirtualizerView())
                NavigationLink("Bass Tuner", destination: BassTunerView())
                NavigationLink("Limiter", destination: LimiterView())
                NavigationLink("Channel Balance", destination: ChannelBalanceView())
                NavigationLink("AutoEq", destination: AutoEqView())
            }
            .navigationTitle("Wave Player")
        }
    }
}
