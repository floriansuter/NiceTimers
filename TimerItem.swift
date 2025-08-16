//
//  TimerItem.swift
//  NiceTimer
//
//  Created by Florian Suter on 16.08.2025.
//

import Foundation
import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct TimerItem: Identifiable, Codable {
  var id = UUID()
  var name: String
  var duration: Int
}

struct TimerSequenceData: Identifiable, Codable {
  var id = UUID()
  var name: String
  var timers: [TimerItem]
  var lastUsed: Date = Date()
}

class TimerSequenceManager: ObservableObject {
  @Published var sequences: [TimerSequenceData] = [] {
    didSet {
      saveSequences()
    }
  }
  @Published var currentSequence: TimerSequenceData? {
    didSet {
      if let sequence = currentSequence {
        UserDefaults.standard.set(sequence.id.uuidString, forKey: "currentSequenceId")
      }
    }
  }
  @Published var currentTimerIndex = 0
  @Published var remainingTime = 0
  @Published var isRunning = false
  
  private var timer: Timer?
  
  // Use App Groups for sharing between iOS and Watch
  private var sharedDefaults: UserDefaults {
    // You'll need to set up an App Group in your project capabilities
    // For now, we'll use standard UserDefaults
    return UserDefaults(suiteName: "group.flodev.NiceTimers") ?? UserDefaults.standard

  }
  
  init() {
    loadSequences()
  }
  
  func loadSequences() {
    if let data = sharedDefaults.data(forKey: "timerSequences"),
       let decoded = try? JSONDecoder().decode([TimerSequenceData].self, from: data) {
      sequences = decoded
    } else {
      // Add default sequences on first launch
      sequences = [
        TimerSequenceData(
          name: "Quick Workout",
          timers: [
            TimerItem(name: "Warm-up", duration: 30),
            TimerItem(name: "Exercise", duration: 60),
            TimerItem(name: "Rest", duration: 15),
            TimerItem(name: "Exercise", duration: 60),
            TimerItem(name: "Cool-down", duration: 30)
          ]
        ),
        TimerSequenceData(
          name: "Pomodoro",
          timers: [
            TimerItem(name: "Focus", duration: 1500),
            TimerItem(name: "Short Break", duration: 300),
            TimerItem(name: "Focus", duration: 1500),
            TimerItem(name: "Long Break", duration: 900)
          ]
        ),
        TimerSequenceData(
          name: "Meditation",
          timers: [
            TimerItem(name: "Breathing", duration: 60),
            TimerItem(name: "Body Scan", duration: 180),
            TimerItem(name: "Focus", duration: 120),
            TimerItem(name: "Relaxation", duration: 60)
          ]
        )
      ]
    }
    
    // Restore current sequence
    if let idString = sharedDefaults.string(forKey: "currentSequenceId"),
       let id = UUID(uuidString: idString),
       let sequence = sequences.first(where: { $0.id == id }) {
      currentSequence = sequence
    } else {
      currentSequence = sequences.first
    }
  }
  
  func saveSequences() {
    if let encoded = try? JSONEncoder().encode(sequences) {
      sharedDefaults.set(encoded, forKey: "timerSequences")
    }
  }
  
  func selectSequence(_ sequence: TimerSequenceData) {
    currentSequence = sequence
    if let index = sequences.firstIndex(where: { $0.id == sequence.id }) {
      sequences[index].lastUsed = Date()
    }
  }
  
  func addSequence(name: String) -> TimerSequenceData {
    let newSequence = TimerSequenceData(name: name, timers: [])
    sequences.append(newSequence)
    currentSequence = newSequence
    return newSequence
  }
  
  func updateSequence(_ sequence: TimerSequenceData) {
    if let index = sequences.firstIndex(where: { $0.id == sequence.id }) {
      sequences[index] = sequence
      if currentSequence?.id == sequence.id {
        currentSequence = sequence
      }
    }
  }
  
  func deleteSequence(_ sequence: TimerSequenceData) {
    sequences.removeAll { $0.id == sequence.id }
    if currentSequence?.id == sequence.id {
      currentSequence = sequences.first
    }
  }
  
  func duplicateSequence(_ sequence: TimerSequenceData) {
    var newSequence = sequence
    newSequence.id = UUID()
    newSequence.name = "\(sequence.name) Copy"
    sequences.append(newSequence)
  }
  
  func start() {
    guard let sequence = currentSequence, !sequence.timers.isEmpty else { return }
    isRunning = true
    currentTimerIndex = 0
    remainingTime = sequence.timers[currentTimerIndex].duration
    startTimer()
  }
  
  private func startTimer() {
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
      self.remainingTime -= 1
      
      if self.remainingTime <= 0 {
        self.signalTimerComplete()
        self.moveToNextTimer()
      }
    }
  }
  
  private func moveToNextTimer() {
    guard let sequence = currentSequence else { return }
    currentTimerIndex += 1
    if currentTimerIndex < sequence.timers.count {
      remainingTime = sequence.timers[currentTimerIndex].duration
    } else {
      stop()
      signalSequenceComplete()
    }
  }
  
  private func signalTimerComplete() {
    #if os(watchOS)
    WKInterfaceDevice.current().play(.notification)
    #else
    // iOS haptic feedback
    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    impactFeedback.impactOccurred()
    #endif
  }
  
  private func signalSequenceComplete() {
    #if os(watchOS)
    WKInterfaceDevice.current().play(.success)
    #else
    let notificationFeedback = UINotificationFeedbackGenerator()
    notificationFeedback.notificationOccurred(.success)
    #endif
  }
  
  func stop() {
    timer?.invalidate()
    timer = nil
    isRunning = false
  }
  
  func pause() {
    timer?.invalidate()
    timer = nil
  }
  
  func resume() {
    if isRunning {
      startTimer()
    }
  }
}
