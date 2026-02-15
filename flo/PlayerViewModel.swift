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
    
    // For fallback – we'll let the main player know if we failed
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
    
    func play(url: URL) -> Bool {  // Returns success
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
        playerNode.play()
        didFail = false
        return true
    }
    
    func pause() {
        playerNode.pause()
    }
    
    func resume() {
        playerNode.play()
    }
    
    func stop() {
        playerNode.stop()
    }
    
    private func applyEQ() {
        for (index, gain) in eqBands.enumerated() {
            eq.bands[index].gain = gain
        }
    }
    
    // MARK: - Persistence
    private func loadSettings() {
        if let saved = UserDefaults.standard.array(forKey: "eqBands") as? [Float] {
            eqBands = saved
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(eqBands, forKey: "eqBands")
    }
}
