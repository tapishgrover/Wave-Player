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

// MARK: - AudioProcessor (embedded)
class AudioProcessor: ObservableObject {
    static let shared = AudioProcessor()
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 6)
    // Limiter temporarily disabled to fix build
    // private let limiter = AVAudioUnitPeakLimiter()
    
    @Published var eqBands: [Float] = [0, 0, 0, 0, 0, 0] {
        didSet { applyEQ() }
    }
    
    // Limiter properties – commented out for now
    /*
    @Published var limiterAttack: Float = 1.0 {
        didSet { limiter.attackTime = limiterAttack / 1000.0 }
    }
    @Published var limiterRelease: Float = 60.0 {
        didSet { limiter.releaseTime = limiterRelease / 1000.0 }
    }
    @Published var limiterPreGain: Float = 0.0 {
        didSet { limiter.preGain = limiterPreGain }
    }
    */
    
    private init() {
        setupEQ()
        // setupLimiter() // disabled
        setupEngine()
        loadSettings()
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
    
    /*
    private func setupLimiter() {
        limiter.attackTime = limiterAttack / 1000.0
        limiter.releaseTime = limiterRelease / 1000.0
        limiter.preGain = limiterPreGain
    }
    */
    
    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(eq)
        // engine.attach(limiter)
        
        engine.connect(playerNode, to: eq, format: nil)
        // engine.connect(eq, to: limiter, format: nil)
        // engine.connect(limiter, to: engine.mainMixerNode, format: nil)
        engine.connect(eq, to: engine.mainMixerNode, format: nil) // direct connection
    }
    
    func play(url: URL) {
        playerNode.stop()
        
        guard let file = try? AVAudioFile(forReading: url) else { return }
        playerNode.scheduleFile(file, at: nil)
        playerNode.play()
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
        // limiter settings not loaded
        /*
        limiterAttack = UserDefaults.standard.float(forKey: "limiterAttack")
        limiterRelease = UserDefaults.standard.float(forKey: "limiterRelease")
        limiterPreGain = UserDefaults.standard.float(forKey: "limiterPreGain")
        */
    }
    
    func saveSettings() {
        UserDefaults.standard.set(eqBands, forKey: "eqBands")
        // limiter settings not saved
        /*
        UserDefaults.standard.set(limiterAttack, forKey: "limiterAttack")
        UserDefaults.standard.set(limiterRelease, forKey: "limiterRelease")
        UserDefaults.standard.set(limiterPreGain, forKey: "limiterPreGain")
        */
    }
}

// MARK: - PlayerViewModel (unchanged, keep your existing PlayerViewModel below)
class PlayerViewModel: ObservableObject {
  // ... (the rest of your PlayerViewModel code remains exactly as before) ...
}
