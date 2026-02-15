//
//  PlayerView.swift
//  flo
//
//  Created by rizaldy on 01/06/24.
//

import NukeUI
import SwiftUI

struct PlayerView: View {
  @Binding var isExpanded: Bool

  @ObservedObject var viewModel: PlayerViewModel

  @State private var offset = CGSize.zero
  @State private var isDragging = false

  @State private var showQueue = false
  @State private var showingAudioSettings = false      // <-- new state for settings

  @GestureState private var queueDragOffset: CGSize = .zero

  var body: some View {
    GeometryReader {
      let size = $0.size
      let imageSize: CGFloat = 300

      // FIXME: Refactor this?
      ZStack(alignment: .topLeading) {
        Color(.systemBackground)
          .ignoresSafeArea()
          .clipShape(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
          )
        VStack(alignment: .leading) {
          HStack {
            Spacer()

            Rectangle()
              .foregroundColor(Color.gray.opacity(0.3))
              .frame(width: 50, height: 5)
              .cornerRadius(30)
              .padding(.top)

            Spacer()
          }
          VStack(alignment: .leading, spacing: 3) {
            Text("Playing Next").customFont(.headline)

            HStack(alignment: .bottom, spacing: 10) {
              if viewModel.queue.isEmpty {
                Text("").customFont(.subheadline)
              } else {
                Text("From \(viewModel.nowPlaying.albumName ?? "")").customFont(.subheadline)
              }

              Spacer()

              Button {
                viewModel.shuffleCurrentQueue()
              } label: {
                Image(systemName: "shuffle")
                  .foregroundColor(Color.accentColor)
                  .fontWeight(.bold)
                  .padding(5)
                  .background(
                    viewModel.isShuffling ? Color.gray.opacity(0.2) : Color(.systemBackground)
                  )
                  .cornerRadius(5)
              }

              Button {
                viewModel.setPlaybackMode()
              } label: {
                Image(systemName: "repeat")
                  .foregroundColor(Color.accentColor)
                  .fontWeight(.bold)
                  .overlay(
                    Group {
                      Text("1")
                        .font(.caption)
                        .clipShape(Circle())
                        .offset(x: 10, y: -5)
                        .fontWeight(.bold)
                    }.opacity(viewModel.playbackMode == PlaybackMode.repeatOnce ? 1 : 0)
                  )
                  .padding(5)
                  .background(
                    viewModel.playbackMode == PlaybackMode.defaultPlayback
                      ? Color(.systemBackground) : Color.gray.opacity(0.2)
                  )
                  .cornerRadius(5)
              }
            }
          }
          .padding(.horizontal)
          .padding(.bottom, 5)

          ScrollView {
            VStack(alignment: .leading) {
              ForEach(viewModel.queue.indices, id: \.self) { idx in
                HStack(alignment: .top) {
                  VStack(alignment: .leading) {
                    Text(viewModel.queue[idx].songName ?? "")
                      .customFont(.callout)
                      .fontWeight(.medium)
                      .padding(.bottom, 3)

                    Text(viewModel.queue[idx].artistName ?? "")
                      .customFont(.caption1)
                  }
                  .frame(maxWidth: .infinity, alignment: .leading)

                  Spacer()

                  Text(timeString(for: viewModel.queue[idx].duration)).customFont(.caption1)
                    .padding(.top, 4)
                }
                .padding(.vertical, 5)
                .padding(.horizontal)
                .background(
                  viewModel.activeQueueIdx == idx
                    ? Color.gray.opacity(0.1) : Color(.systemBackground)
                )
                .onTapGesture {
                  viewModel.playFromQueue(idx: idx)
                }
              }
            }
          }.padding(.bottom, 60)
        }
      }
      .gesture(
        DragGesture()
          .updating($queueDragOffset) { value, state, _ in
            if value.translation.height > 0 {
              state = value.translation
            }
          }
          .onEnded { value in
            if value.translation.height > 100 {
              self.showQueue = false
            }
          }
      )
      .animation(.spring(duration: 0.4), value: queueDragOffset.height)
      .foregroundColor(.primary)
      .zIndex(1)
      .offset(
        y: showQueue
          ? UIScreen.main.bounds.height - 500 + queueDragOffset.height : UIScreen.main.bounds.height
      )
      .frame(height: 500)
      .animation(.spring(duration: 0.2), value: showQueue)

      ZStack {
        VStack {

          Rectangle()
            .foregroundColor(Color.gray.opacity(0.8))
            .frame(width: 50, height: 5)
            .cornerRadius(30)
            .padding(.top, 20)

          Spacer()

          if let image = UIImage(contentsOfFile: viewModel.getAlbumCoverArt()) {
            Image(uiImage: image)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: imageSize, height: imageSize)
              .clipShape(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
              )
          } else {
            LazyImage(url: URL(string: viewModel.getAlbumCoverArt())) { state in
              if let image = state.image {
                image
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: imageSize, height: imageSize)
                  .clipShape(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                  )
              } else {
                Color.gray.opacity(0.3)
                  .frame(width: imageSize, height: imageSize)
                  .clipShape(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                  )
              }
            }
          }

          Spacer()

          VStack(alignment: .center, spacing: 10) {
            Text(viewModel.nowPlaying.songName ?? "")
              .foregroundColor(.white)
              .customFont(.title2)
              .fontWeight(.bold)
              .multilineTextAlignment(.center)
              .lineLimit(3)

            Text(viewModel.nowPlaying.artistName ?? "")
              .foregroundColor(.white.opacity(0.8))
              .customFont(.title3)
              .multilineTextAlignment(.center)
              .lineLimit(2)
          }

          Spacer()

          HStack(spacing: size.width * 0.15) {
            Button {
              viewModel.prevSong()
            } label: {
              Image(systemName: "backward.fill").font(.title)
            }

            Button {
              viewModel.isPlaying ? viewModel.pause() : viewModel.play()
            } label: {
              Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 50))
            }
            .foregroundColor(viewModel.isMediaLoading ? .gray : .white)
            .disabled(viewModel.isMediaLoading)

            Button {
              viewModel.nextSong()
            } label: {
              Image(systemName: "forward.fill").font(.title)
            }
          }

          Spacer()

          VStack {

            PlayerCustomSlider(
              isMediaLoading: viewModel.isMediaLoading,
              isSeeking: $viewModel.isSeeking, value: $viewModel.progress, range: 0...1
            ) { newValue in
              viewModel.seek(to: newValue)
            }

            HStack {
              Text(viewModel.currentTimeString)
                .foregroundColor(.white)
                .customFont(.caption2)
                .frame(width: 60, alignment: .leading)

              Spacer()

              Text(
                viewModel.isPlayFromSource
                  ? "\(viewModel.nowPlaying.suffix ?? "")   \(viewModel.nowPlaying.bitRate.description)"
                  : "\(TranscodingSettings.targetFormat)   \(UserDefaultsManager.maxBitRate)"
              )
              .foregroundColor(.white)
              .customFont(.caption2)
              .fontWeight(.bold)
              .textCase(.uppercase)
              .frame(maxWidth: .infinity, alignment: .center)

              Spacer()

              Text(viewModel.totalTimeString)
                .foregroundColor(.white)
                .customFont(.caption2)
                .frame(width: 60, alignment: .trailing)
            }
          }

          Spacer()

          HStack {
            Button {
              // placeholder
            } label: {
              Image(systemName: "quote.bubble")
                .font(.title2)
                .foregroundColor(.gray)
            }.disabled(true)

            Spacer()

            // New settings button (replaced the disabled airplayaudio)
            Button {
              showingAudioSettings = true
            } label: {
              Image(systemName: "slider.horizontal.3")
                .font(.title2)
                .foregroundColor(.white)
            }

            Spacer()

            Button {
              self.showQueue.toggle()
            } label: {
              Image(systemName: "list.bullet")
                .font(.title2)
                .overlay(
                  Group {
                    Image(systemName: "repeat")
                      .font(.caption)
                      .overlay(
                        Group {
                          Text("1")
                            .font(.system(size: 8))
                        }
                        .offset(x: 7, y: -4)
                        .opacity(viewModel.playbackMode == PlaybackMode.repeatOnce ? 1 : 0)
                      )
                      .opacity(viewModel.playbackMode == PlaybackMode.defaultPlayback ? 0 : 1)
                  }
                  .padding(5)
                  .background(
                    .black.opacity(viewModel.playbackMode == PlaybackMode.defaultPlayback ? 0 : 0.2)
                  )
                  .clipShape(Circle())
                  .offset(x: 10, y: -10)
                )
            }
          }
        }
        .padding(.horizontal, 30)
      }
      .frame(maxHeight: .infinity)
      .background {
        ZStack {
          if UserDefaultsManager.playerBackground == PlayerBackground.translucent {
            if let image = UIImage(contentsOfFile: viewModel.getAlbumCoverArt()) {
              Image(uiImage: image)
                .resizable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: 50, opaque: true)
                .edgesIgnoringSafeArea(.all)
            } else {
              LazyImage(url: URL(string: viewModel.getAlbumCoverArt())) { state in
                if let image = state.image {
                  image
                    .resizable()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: 50, opaque: true)
                    .edgesIgnoringSafeArea(.all)
                }
              }
            }

            Rectangle().fill(.thinMaterial).edgesIgnoringSafeArea(.all)
          } else {
            Rectangle().fill(Color("PlayerColor")).edgesIgnoringSafeArea(.all)
          }
        }
        .environment(\.colorScheme, .dark)
        .clipShape(
          RoundedRectangle(cornerRadius: 25, style: .continuous)
        ).edgesIgnoringSafeArea(.all)
      }
      .offset(y: offset.height)
      .gesture(
        DragGesture()
          .onChanged { gesture in
            if gesture.translation.height > 0 {
              offset = gesture.translation
              isDragging = true
            }
          }
          .onEnded { _ in
            if offset.height > size.height / 3 {
              isExpanded = false
            }
            offset = .zero
            isDragging = false
          }
      )
      // Sheet for audio settings
      .sheet(isPresented: $showingAudioSettings) {
        AudioSettingsMainView()
      }
    }
    .foregroundColor(.white)
  }
}

// MARK: - Audio Settings Views

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

struct GraphicEqualizerView: View {
    @State private var bands: [Float] = [0, 0, 0, 0, 0, 0]
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
                        Slider(value: $bands[index], in: -7.5...7.5, step: 0.5)
                        Text(String(format: "%.1f", bands[index]))
                            .frame(width: 40, alignment: .trailing)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Graphic Equalizer")
    }
    
    func setPreset(_ shape: String) {
        switch shape {
        case "v":
            bands = [3.0, 0.0, -2.0, -2.0, 0.0, 3.0]
        case "u":
            bands = [-3.0, 0.0, 2.0, 2.0, 0.0, -3.0]
        case "m":
            bands = [0.0, 3.0, 0.0, 0.0, 3.0, 0.0]
        default:
            break
        }
    }
}

struct EqualLoudnessView: View {
    @State private var threshold: Float = -20.0
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Volume threshold")
                    Spacer()
                    Text(String(format: "%.0f dB", threshold))
                }
                Slider(value: $threshold, in: -30...0, step: 1)
            }
            
            Section {
                // Placeholder for the equal loudness graph
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 150)
                    .overlay(
                        VStack {
                            Text("Equal loudness curve")
                                .foregroundColor(.secondary)
                            Text("(frequencies: 54 – 8103 Hz)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
        .navigationTitle("Equal Loudness")
    }
}

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

struct LimiterView: View {
    @State private var attack: Float = 1.0        // ms
    @State private var release: Float = 60.0      // ms
    @State private var ratio: Float = 10.0        // :1
    @State private var threshold: Float = -2.0    // dB
    @State private var autoPostGain = true
    @State private var postGain: Float = 0.0      // dB
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Attack time")
                    Spacer()
                    Text(String(format: "%.0f ms", attack))
                }
                Slider(value: $attack, in: 0.1...100, step: 0.1)
                
                HStack {
                    Text("Release time")
                    Spacer()
                    Text(String(format: "%.0f ms", release))
                }
                Slider(value: $release, in: 10...1000, step: 1)
                
                HStack {
                    Text("Ratio")
                    Spacer()
                    Text(String(format: "%.1f:1", ratio))
                }
                Slider(value: $ratio, in: 1...20, step: 0.5)
                
                HStack {
                    Text("Threshold")
                    Spacer()
                    Text(String(format: "%.0f dB", threshold))
                }
                Slider(value: $threshold, in: -30...0, step: 1)
                
                Toggle("Automatic post‑gain", isOn: $autoPostGain)
                
                HStack {
                    Text("Post‑gain")
                    Spacer()
                    Text(String(format: "%.1f dB", postGain))
                }
                Slider(value: $postGain, in: -12...12, step: 0.5)
                    .disabled(autoPostGain)
            }
        }
        .navigationTitle("Limiter")
    }
}

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

struct PlayerView_previews: PreviewProvider {
  @StateObject static var viewModel = PlayerViewModel()
  @State static var isExpanded: Bool = true

  static var previews: some View {
    PlayerView(isExpanded: $isExpanded, viewModel: viewModel)
  }
}
