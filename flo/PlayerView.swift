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
  @State private var showingAudioSettings = false
  @GestureState private var queueDragOffset: CGSize = .zero

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        queueView
        mainPlayerView(geometry: geometry)
      }
      .sheet(isPresented: $showingAudioSettings) {
        AudioSettingsMainView()
      }
    }
    .foregroundColor(.white)
  }

  // MARK: - Queue View (extracted)
  @ViewBuilder
  private var queueView: some View {
    Color(.systemBackground)
      .ignoresSafeArea()
      .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
      .overlay(
        VStack(alignment: .leading) {
          dragIndicator
          playingNextHeader
          queueList
        }
      )
      .gesture(
        DragGesture()
          .updating($queueDragOffset) { value, state, _ in
            if value.translation.height > 0 { state = value.translation }
          }
          .onEnded { value in
            if value.translation.height > 100 { showQueue = false }
          }
      )
      .animation(.spring(duration: 0.4), value: queueDragOffset.height)
      .offset(
        y: showQueue
          ? UIScreen.main.bounds.height - 500 + queueDragOffset.height
          : UIScreen.main.bounds.height
      )
      .frame(height: 500)
      .animation(.spring(duration: 0.2), value: showQueue)
  }

  private var dragIndicator: some View {
    HStack {
      Spacer()
      Rectangle()
        .foregroundColor(Color.gray.opacity(0.3))
        .frame(width: 50, height: 5)
        .cornerRadius(30)
        .padding(.top)
      Spacer()
    }
  }

  private var playingNextHeader: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text("Playing Next").customFont(.headline)
      HStack(alignment: .bottom, spacing: 10) {
        if viewModel.queue.isEmpty {
          Text("").customFont(.subheadline)
        } else {
          Text("From \(viewModel.nowPlaying.albumName ?? "")").customFont(.subheadline)
        }
        Spacer()
        shuffleButton
        repeatButton
      }
    }
    .padding(.horizontal)
    .padding(.bottom, 5)
  }

  private var shuffleButton: some View {
    Button {
      viewModel.shuffleCurrentQueue()
    } label: {
      Image(systemName: "shuffle")
        .foregroundColor(Color.accentColor)
        .fontWeight(.bold)
        .padding(5)
        .background(viewModel.isShuffling ? Color.gray.opacity(0.2) : Color(.systemBackground))
        .cornerRadius(5)
    }
  }

  private var repeatButton: some View {
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
          }
          .opacity(viewModel.playbackMode == PlaybackMode.repeatOnce ? 1 : 0)
        )
        .padding(5)
        .background(
          viewModel.playbackMode == PlaybackMode.defaultPlayback
            ? Color(.systemBackground)
            : Color.gray.opacity(0.2)
        )
        .cornerRadius(5)
    }
  }

  private var queueList: some View {
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
            Text(timeString(for: viewModel.queue[idx].duration))
              .customFont(.caption1)
              .padding(.top, 4)
          }
          .padding(.vertical, 5)
          .padding(.horizontal)
          .background(
            viewModel.activeQueueIdx == idx
              ? Color.gray.opacity(0.1)
              : Color(.systemBackground)
          )
          .onTapGesture {
            viewModel.playFromQueue(idx: idx)
          }
        }
      }
      .padding(.bottom, 60)
    }
  }

  // MARK: - Main Player View (extracted)
  @ViewBuilder
  private func mainPlayerView(geometry: GeometryProxy) -> some View {
    let size = geometry.size
    let imageSize: CGFloat = 300

    VStack {
      dragIndicator
      Spacer()
      albumArt(imageSize: imageSize)
      Spacer()
      songInfo
      Spacer()
      playbackControls(size: size)
      Spacer()
      progressSlider
      Spacer()
      bottomControls
    }
    .padding(.horizontal, 30)
    .frame(maxHeight: .infinity)
    .background(playerBackground)
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
  }

  @ViewBuilder
  private func albumArt(imageSize: CGFloat) -> some View {
    if let image = UIImage(contentsOfFile: viewModel.getAlbumCoverArt()) {
      Image(uiImage: image)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: imageSize, height: imageSize)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    } else {
      LazyImage(url: URL(string: viewModel.getAlbumCoverArt())) { state in
        if let image = state.image {
          image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: imageSize, height: imageSize)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        } else {
          Color.gray.opacity(0.3)
            .frame(width: imageSize, height: imageSize)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
      }
    }
  }

  private var songInfo: some View {
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
  }

  private func playbackControls(size: CGSize) -> some View {
    HStack(spacing: size.width * 0.15) {
      Button { viewModel.prevSong() } label: {
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
      Button { viewModel.nextSong() } label: {
        Image(systemName: "forward.fill").font(.title)
      }
    }
  }

  private var progressSlider: some View {
    VStack {
      PlayerCustomSlider(
        isMediaLoading: viewModel.isMediaLoading,
        isSeeking: $viewModel.isSeeking,
        value: $viewModel.progress,
        range: 0...1
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
  }

  private var bottomControls: some View {
    HStack {
      Button {} label: {
        Image(systemName: "quote.bubble")
          .font(.title2)
          .foregroundColor(.gray)
      }.disabled(true)
      Spacer()
      Button { showingAudioSettings = true } label: {
        Image(systemName: "slider.horizontal.3")
          .font(.title2)
          .foregroundColor(.white)
      }
      Spacer()
      if viewModel._playFromLocal {
        HStack(spacing: 4) {
          Text("EQ")
          Text(viewModel._playFromLocal ? "Y" : "N")
            .font(.system(size: 10))
        }
        .font(.caption2)
        .padding(4)
        .background(Color.accentColor)
        .foregroundColor(.white)
        .cornerRadius(4)
      }
      Spacer()
      Button { showQueue.toggle() } label: {
        Image(systemName: "list.bullet")
          .font(.title2)
          .overlay(queueBadgeOverlay)
      }
    }
  }

  private var queueBadgeOverlay: some View {
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
    .background(.black.opacity(viewModel.playbackMode == PlaybackMode.defaultPlayback ? 0 : 0.2))
    .clipShape(Circle())
    .offset(x: 10, y: -10)
  }

  private var playerBackground: some View {
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
    .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
    .edgesIgnoringSafeArea(.all)
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
        // NavigationLink("Limiter", destination: LimiterView()) // Temporarily disabled
        NavigationLink("Channel Balance", destination: ChannelBalanceView())
        NavigationLink("AutoEq", destination: AutoEqView())
      }
      .navigationTitle("Wave Player")
    }
  }
}

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
    .onDisappear { audioProcessor.saveSettings() }
  }

  func setPreset(_ shape: String) {
    switch shape {
    case "v": audioProcessor.eqBands = [3.0, 0.0, -2.0, -2.0, 0.0, 3.0]
    case "u": audioProcessor.eqBands = [-3.0, 0.0, 2.0, 2.0, 0.0, -3.0]
    case "m": audioProcessor.eqBands = [0.0, 3.0, 0.0, 0.0, 3.0, 0.0]
    default: break
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
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.gray.opacity(0.2))
          .frame(height: 150)
          .overlay(
            VStack {
              Text("Equal loudness curve").foregroundColor(.secondary)
              Text("(frequencies: 54 – 8103 Hz)").font(.caption).foregroundColor(.secondary)
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
          ForEach(bassTypes, id: \.self) { type in Text(type) }
        }
        Picker("Cutoff frequency", selection: $selectedCutoff) {
          ForEach(cutoffFrequencies, id: \.self) { freq in Text(freq) }
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

// Placeholder LimiterView – not using AudioProcessor (to avoid build errors)
struct LimiterView: View {
  @State private var attack: Float = 1.0
  @State private var release: Float = 60.0
  @State private var preGain: Float = 0.0

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
          Text("Pre‑gain")
          Spacer()
          Text(String(format: "%.1f dB", preGain))
        }
        Slider(value: $preGain, in: -12...12, step: 0.5)
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
          ForEach(headphones, id: \.self) { model in Text(model) }
        }
      }
      Section {
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.gray.opacity(0.2))
          .frame(height: 150)
          .overlay(
            VStack {
              Text("AutoEq curve").foregroundColor(.secondary)
              Text("(to be implemented)").font(.caption).foregroundColor(.secondary)
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
