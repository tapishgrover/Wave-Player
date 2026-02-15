//
//  PlayerViewModel.swift
//  flo
//
//  Created by rizaldy on 05/06/24.
//

import AVFoundation
import Combine
import MediaPlayer
import SwiftUI

// MARK: - PlaybackMode Enum
enum PlaybackMode {
    case defaultPlayback
    case repeatAlbum
    case repeatOnce
}

// MARK: - AudioProcessor (improved)
class AudioProcessor: ObservableObject {
    static let shared = AudioProcessor()
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 6)
    private var isEngineRunning = false
    
    @Published var eqBands: [Float] = [0, 0, 0, 0, 0, 0] {
        didSet { applyEQ() }
    }
    
    // Indicates whether the last play attempt failed
    @Published var didFail = false
    
    private init() {
        setupEQ()
        setupAudioSession()
        setupEngine()
        loadSettings()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session: \(error)")
            didFail = true
        }
    }
    
    private func setupEQ() {
        let frequencies: [Float] = [54, 148, 403, 1096, 2980, 8103]
        for (index, freq) in frequencies.enumerated() {
            eq.bands[index].frequency = freq
            eq.bands[index].bandwidth = 0.5
            eq.bands[index].gain = 0.0
            eq.bands[index].bypass = false
        }
    }
    
    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(eq)
        engine.connect(playerNode, to: eq, format: nil)
        engine.connect(eq, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = 1.0
        
        do {
            try engine.start()
            isEngineRunning = true
            didFail = false
        } catch {
            print("Engine failed to start: \(error)")
            isEngineRunning = false
            didFail = true
        }
    }
    
    func play(url: URL) -> Bool {
        guard isEngineRunning else {
            didFail = true
            return false
        }
        
        playerNode.stop()
        
        guard let file = try? AVAudioFile(forReading: url) else {
            print("Cannot open audio file: \(url)")
            didFail = true
            return false
        }
        
        playerNode.scheduleFile(file, at: nil)
        playerNode.volume = 1.0
        // Test boost – can be removed later
        for i in 0..<eq.bands.count {
            eq.bands[i].gain = 3.0
        }
        playerNode.play()
        didFail = false
        return true
    }
    
    func pause() { playerNode.pause() }
    func resume() { playerNode.play() }
    func stop() { playerNode.stop() }
    
    private func applyEQ() {
        for (index, gain) in eqBands.enumerated() {
            eq.bands[index].gain = gain
        }
    }
    
    private func loadSettings() {
        if let saved = UserDefaults.standard.array(forKey: "eqBands") as? [Float] {
            eqBands = saved
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(eqBands, forKey: "eqBands")
    }
}

// MARK: - PlayerViewModel
class PlayerViewModel: ObservableObject {
  private var player: AVPlayer?
  private var playerItem: AVPlayerItem?
  private var timeObserverToken: Any?
  private var progressTimer: Timer?

  @Published var queue: [QueueEntity] = []
  @Published var playbackMode = PlaybackMode.defaultPlayback
  @Published var activeQueueIdx: Int = 0
  @Published var isMediaFailed: Bool = false
  @Published var isMediaLoading: Bool = false
  @Published var isShuffling: Bool = false
  @Published var isPlaying: Bool = false
  @Published var isSeeking: Bool = false
  @Published var isLyricsMode: Bool = false
  @Published var progress: Double = 0.0
  @Published var currentTimeString: String = "00:00"
  @Published var totalTimeString: String = "00:00"
  @Published var shouldHidePlayer: Bool = false
  @Published var _playFromLocal: Bool = false

  private var isLocallySaved: Bool = false
  private var isFinished: Bool = false
  private var totalDuration: Double = 0.0
  private var playerItemObservation: AnyCancellable?
  private var interruptionObservation = Set<AnyCancellable>()
  private var scrobbleThreshold = 0.5
  private var usingLocalProcessor: Bool = false

  var nowPlaying: QueueEntity { queue[activeQueueIdx] }
  var isPlayFromSource: Bool {
    _playFromLocal || UserDefaultsManager.maxBitRate == TranscodingSettings.sourceBitRate
  }

  init() {
    player = AVPlayer()
    observeInterruptionNotifications()

    let lastPlayData = PlaybackService.shared.getQueue()
    let queueActiveIdx = UserDefaultsManager.queueActiveIdx

    if !lastPlayData.isEmpty && queueActiveIdx < lastPlayData.count {
      progress = UserDefaultsManager.nowPlayingProgress
      playbackMode = UserDefaultsManager.playbackMode
      addToQueue(idx: queueActiveIdx, item: lastPlayData, playAudio: false)
      if progress > scrobbleThreshold { isLocallySaved = true }
    } else {
      UserDefaultsManager.removeObject(key: UserDefaultsKeys.queueActiveIdx)
      UserDefaultsManager.removeObject(key: UserDefaultsKeys.nowPlayingProgress)
      PlaybackService.shared.clearQueue()
    }

    setupRemoteCommandCenter()
  }

  func observeInterruptionNotifications() {
    NotificationCenter.default
      .publisher(for: AVAudioSession.interruptionNotification)
      .sink { self.handleInterruptionNotification($0) }
      .store(in: &interruptionObservation)
  }

  func handleInterruptionNotification(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? Int,
          let type = AVAudioSession.InterruptionType(rawValue: UInt(typeValue)) else { return }
    switch type {
    case .began: pause()
    case .ended:
      play()
      if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? Int,
         let options = AVAudioSession.InterruptionOptions(rawValue: UInt(optionsValue)),
         options.contains(.shouldResume) {
        play()
      }
    @unknown default: break
    }
  }

  func addToQueue(idx: Int, item: [QueueEntity], playAudio: Bool = true) {
    activeQueueIdx = idx
    queue = item
    setNowPlaying(playAudio: playAudio)
  }

  func getAlbumCoverArt() -> String {
    AlbumService.shared.getAlbumCover(
      artistName: nowPlaying.artistName ?? "",
      albumName: nowPlaying.albumName ?? "",
      albumId: nowPlaying.albumId ?? "",
      trackId: nowPlaying.id ?? "")
  }

  func hasNowPlaying() -> Bool { !queue.isEmpty }

  func setNowPlaying(playAudio: Bool = true) {
    shouldHidePlayer = false
    isLocallySaved = false

    progressTimer?.invalidate()
    progressTimer = nil
    if let token = timeObserverToken {
      player?.removeTimeObserver(token)
      timeObserverToken = nil
    }

    let audioURL = URL(string: AlbumService.shared.getStreamUrl(id: nowPlaying.id ?? ""))
    _playFromLocal = audioURL?.isFileURL == true
    usingLocalProcessor = _playFromLocal

    if usingLocalProcessor, let localURL = audioURL {
        let success = AudioProcessor.shared.play(url: localURL)
        if success {
            player = nil
            playerItem = nil
            isMediaLoading = false
            isMediaFailed = false
        } else {
            usingLocalProcessor = false
            playerItem = AVPlayerItem(url: localURL)
            player?.replaceCurrentItem(with: playerItem)
        }
    } else {
        playerItem = AVPlayerItem(url: audioURL!)
        player?.replaceCurrentItem(with: playerItem)
    }

    let duration = CMTime(seconds: nowPlaying.duration, preferredTimescale: nowPlaying.sampleRate)
    totalDuration = CMTimeGetSeconds(duration)
    totalTimeString = timeString(for: totalDuration)
    currentTimeString = timeString(for: progress * totalDuration)

    if !usingLocalProcessor {
      playerItemObservation = playerItem?.publisher(for: \.status)
        .sink { [weak self] status in
          guard let self = self else { return }
          switch status {
          case .readyToPlay:
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
              self.isMediaLoading = false
              self.isMediaFailed = false
            }
          case .failed:
            self.isMediaLoading = false
            self.isMediaFailed = true
          case .unknown:
            self.isMediaLoading = false
          @unknown default:
            self.isMediaLoading = true
          }
        }
    } else {
      isMediaLoading = false
    }

    if playAudio {
      if usingLocalProcessor {
        AudioProcessor.shared.resume()
        isPlaying = true
      } else {
        seek(to: 0.0)
        play()
      }
    } else {
      if usingLocalProcessor {
        AudioProcessor.shared.pause()
        isPlaying = false
      } else {
        seek(to: progress)
      }
    }

    if !usingLocalProcessor {
      addPeriodicTimeObserver()
      startProgressTimer()
    }

    initNowPlayingInfo(title: nowPlaying.songName ?? "",
                       artist: nowPlaying.artistName ?? "",
                       playbackDuration: totalDuration)
    FloooViewModel.shared.setNowPlayingToScrobbleServer(nowPlaying: nowPlaying)
  }

  private func addPeriodicTimeObserver() {
    guard let player = player else { return }
    let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
      let currentTime = CMTimeGetSeconds(time)
      let roundedTotalDuration = floor(self.totalDuration)

      self.progress = currentTime / self.totalDuration
      self.currentTimeString = timeString(for: currentTime)
      UserDefaultsManager.nowPlayingProgress = self.progress

      if !self.isLocallySaved && self.progress >= 0.5 {
        Task {
          FloooViewModel.shared.scrobble(submission: true, nowPlaying: self.nowPlaying)
          self.isLocallySaved = true
        }
      }

      if round(currentTime) >= roundedTotalDuration {
        self.nextSong()
        UserDefaultsManager.removeObject(key: UserDefaultsKeys.nowPlayingProgress)
      }
    }
  }

  private func startProgressTimer() {
    progressTimer?.invalidate()
    progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      guard let self = self, let player = self.player, !self.usingLocalProcessor else { return }
      let currentTime = player.currentTime().seconds
      if currentTime.isFinite && currentTime > 0 {
        self.progress = currentTime / self.totalDuration
        self.currentTimeString = timeString(for: currentTime)
        UserDefaultsManager.nowPlayingProgress = self.progress
      }
    }
  }

  private func stopProgressTimer() {
    progressTimer?.invalidate()
    progressTimer = nil
  }

  private func initNowPlayingInfo(title: String, artist: String, playbackDuration: Double) {
    var nowPlayingInfo = [String: Any]()
    DispatchQueue.global().async {
      let url: URL
      let albumCoverArt = self.getAlbumCoverArt()
      if albumCoverArt.hasPrefix("/") {
        url = URL(fileURLWithPath: albumCoverArt)
      } else {
        guard let remoteURL = URL(string: albumCoverArt) else { return }
        url = remoteURL
      }
      if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
      }
      DispatchQueue.main.async {
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = playbackDuration
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
      }
    }
  }

  func updateNowPlayingInfo(progress: TimeInterval, rate: Float) {
    var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress * totalDuration
    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = totalDuration
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }

  private func setupRemoteCommandCenter() {
    let center = MPRemoteCommandCenter.shared()
    center.playCommand.addTarget { [unowned self] _ in self.play(); return .success }
    center.pauseCommand.addTarget { [unowned self] _ in self.pause(); return .success }
    center.nextTrackCommand.addTarget { _ in self.nextSong(); return .success }
    center.previousTrackCommand.addTarget { _ in self.prevSong(); return .success }
    center.changePlaybackPositionCommand.addTarget { event in
      if let event = event as? MPChangePlaybackPositionCommandEvent {
        self.seek(to: event.positionTime / self.totalDuration)
        return .success
      }
      return .commandFailed
    }
  }

  func play() {
    if usingLocalProcessor {
      AudioProcessor.shared.resume()
      isPlaying = true
    } else {
      if isFinished { stop(); updateNowPlayingInfo(progress: progress, rate: 0) }
      player?.play()
      isFinished = false
      isPlaying = true
      updateNowPlayingInfo(progress: progress, rate: 1)
    }
  }

  func pause() {
    if usingLocalProcessor {
      AudioProcessor.shared.pause()
      isPlaying = false
    } else {
      player?.pause()
      isPlaying = false
      updateNowPlayingInfo(progress: progress, rate: 0)
    }
  }

  func stop() {
    if usingLocalProcessor {
      AudioProcessor.shared.stop()
      isPlaying = false
    } else {
      player?.pause()
      player?.seek(to: .zero)
      isFinished = true
      isPlaying = false
    }
    stopProgressTimer()
  }

  func seek(to progress: Double) {
    if usingLocalProcessor { return } // not implemented
    let newTime = CMTime(seconds: progress * totalDuration, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    player?.seek(to: newTime)
    updateNowPlayingInfo(progress: progress, rate: 1)
  }

  func setPlaybackMode() {
    if playbackMode == .defaultPlayback {
      playbackMode = .repeatAlbum
    } else if playbackMode == .repeatAlbum {
      playbackMode = .repeatOnce
    } else {
      playbackMode = .defaultPlayback
    }
    UserDefaultsManager.playbackMode = playbackMode
  }

  func playBySong<T: Playable>(idx: Int, item: T, isFromLocal: Bool) {
    let q = PlaybackService.shared.addToQueue(item: item, isFromLocal: isFromLocal)
    addToQueue(idx: idx, item: q)
  }

  func playItem<T: Playable>(item: T, isFromLocal: Bool) {
    let q = PlaybackService.shared.addToQueue(item: item, isFromLocal: isFromLocal)
    addToQueue(idx: 0, item: q)
  }

  func shuffleItem<T: Playable>(item: T, isFromLocal: Bool) {
    var shuffled = item
    shuffled.songs.shuffle()
    let q = PlaybackService.shared.addToQueue(item: shuffled, isFromLocal: isFromLocal)
    addToQueue(idx: 0, item: q)
  }

  func shuffleCurrentQueue() {
    isShuffling.toggle()
    if isShuffling {
      queue = PlaybackService.shared.shuffleQueue(currentIdx: activeQueueIdx)
    } else {
      queue = PlaybackService.shared.getQueue()
    }
  }

  func playFromQueue(idx: Int) {
    activeQueueIdx = idx
    setNowPlaying()
    UserDefaultsManager.queueActiveIdx = activeQueueIdx
  }

  func prevSong() {
    if activeQueueIdx != 0, playbackMode != .repeatOnce {
      activeQueueIdx -= 1
    } else {
      activeQueueIdx = 0
    }
    setNowPlaying()
  }

  func nextSong() {
    if queue.count == 1 {
      if playbackMode == .defaultPlayback { stop() } else { setNowPlaying() }
    } else {
      switch playbackMode {
      case .repeatOnce:
        setNowPlaying()
      case .repeatAlbum:
        if activeQueueIdx + 1 > queue.count - 1 {
          activeQueueIdx = 0
        } else {
          activeQueueIdx += 1
        }
        setNowPlaying()
      default:
        if activeQueueIdx + 1 > queue.count - 1 {
          stop()
        } else {
          activeQueueIdx += 1
          setNowPlaying()
        }
      }
    }
    UserDefaultsManager.queueActiveIdx = activeQueueIdx
  }

  func destroyPlayerAndQueue() {
    stop()
    progress = 0
    isLocallySaved = false
    shouldHidePlayer = true
    PlaybackService.shared.clearQueue()
    UserDefaultsManager.removeObject(key: UserDefaultsKeys.nowPlayingProgress)
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }

  deinit {
    if let token = timeObserverToken { player?.removeTimeObserver(token) }
    player?.pause()
    progressTimer?.invalidate()
  }
}
