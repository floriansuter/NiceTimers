//
//  ContentView.swift
//  WatchNiceTimer Watch App
//
//  Created by Florian Suter on 16.08.2025.
//

import SwiftUI

struct ContentView: View {
  @StateObject private var manager = TimerSequenceManager()
  @State private var showingSequenceList = false
  @State private var showingEditView = false
  
  var body: some View {
    NavigationView {
      VStack {
        if let currentSequence = manager.currentSequence {
          // Sequence selector button
          Button(action: { showingSequenceList = true }) {
            HStack {
              Text(currentSequence.name)
                .lineLimit(1)
              Image(systemName: "chevron.down")
                .font(.caption)
            }
          }
          .buttonStyle(.plain)
          .foregroundColor(.blue)
          
          if manager.isRunning {
            // Running timer display
            RunningTimerView(manager: manager)
          } else {
            // Timer list
            if currentSequence.timers.isEmpty {
              Text("No timers")
                .foregroundColor(.secondary)
                .padding()
            } else {
              List {
                ForEach(currentSequence.timers) { timer in
                  HStack {
                    Text(timer.name)
                      .lineLimit(1)
                    Spacer()
                    Text("\(timer.duration)s")
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                }
              }
              .listStyle(.carousel)
            }
            
            // Control buttons
            HStack {
              Button(action: { manager.start() }) {
                Image(systemName: "play.fill")
              }
              .foregroundColor(.green)
              .disabled(currentSequence.timers.isEmpty)
              
              Button(action: { showingEditView = true }) {
                Image(systemName: "pencil")
              }
              .foregroundColor(.orange)
            }
          }
        } else {
          Text("No sequences")
          Button("Create Sequence") {
            manager.addSequence(name: "New Sequence")
          }
        }
      }
      .navigationTitle("Timers")
      .navigationBarTitleDisplayMode(.inline)
    }
    .sheet(isPresented: $showingSequenceList) {
      SequenceListView(manager: manager)
    }
    .sheet(isPresented: $showingEditView) {
      if let sequence = manager.currentSequence {
        EditSequenceView(manager: manager, sequence: sequence)
      }
    }
  }
}

struct RunningTimerView: View {
  @ObservedObject var manager: TimerSequenceManager
  
  var body: some View {
    VStack(spacing: 8) {
      if let sequence = manager.currentSequence {
        Text(sequence.timers[manager.currentTimerIndex].name)
          .font(.headline)
        
        Text("\(manager.remainingTime)")
          .font(.system(size: 48, weight: .thin, design: .monospaced))
        
        // Progress indicator
        ProgressView(
          value: Double(manager.remainingTime),
          total: Double(sequence.timers[manager.currentTimerIndex].duration)
        )
        .progressViewStyle(.circular)
        
        Text("\(manager.currentTimerIndex + 1) of \(sequence.timers.count)")
          .font(.caption)
          .foregroundColor(.secondary)
        
        Button("Stop") {
          manager.stop()
        }
        .foregroundColor(.red)
      }
    }
  }
}

struct SequenceListView: View {
  @ObservedObject var manager: TimerSequenceManager
  @Environment(\.dismiss) var dismiss
  @State private var showingNewSequence = false
  @State private var newSequenceName = ""
  
  var body: some View {
    NavigationView {
      List {
        ForEach(manager.sequences) { sequence in
          Button(action: {
            manager.selectSequence(sequence)
            dismiss()
          }) {
            VStack(alignment: .leading) {
              Text(sequence.name)
                .font(.headline)
              Text("\(sequence.timers.count) timers")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
        .onDelete { indexSet in
          indexSet.forEach { index in
            manager.deleteSequence(manager.sequences[index])
          }
        }
        
        Button("New Sequence") {
          showingNewSequence = true
        }
        .foregroundColor(.green)
      }
      .navigationTitle("Sequences")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
      }
      .alert("New Sequence", isPresented: $showingNewSequence) {
        TextField("Name", text: $newSequenceName)
        Button("Create") {
          if !newSequenceName.isEmpty {
            manager.addSequence(name: newSequenceName)
            newSequenceName = ""
            dismiss()
          }
        }
        Button("Cancel", role: .cancel) {
          newSequenceName = ""
        }
      }
    }
  }
}

struct EditSequenceView: View {
  @ObservedObject var manager: TimerSequenceManager
  var sequence: TimerSequenceData
  @Environment(\.dismiss) var dismiss
  @State private var editingSequence: TimerSequenceData
  @State private var showingAddTimer = false
  
  init(manager: TimerSequenceManager, sequence: TimerSequenceData) {
    self.manager = manager
    self.sequence = sequence
    self._editingSequence = State(initialValue: sequence)
  }
  
  var body: some View {
    NavigationView {
      List {
        Section {
          TextField("Sequence Name", text: $editingSequence.name)
        }
        
        Section("Timers") {
          ForEach(editingSequence.timers) { timer in
            HStack {
              Text(timer.name)
              Spacer()
              Text("\(timer.duration)s")
                .foregroundColor(.secondary)
            }
          }
          .onDelete { indexSet in
            editingSequence.timers.remove(atOffsets: indexSet)
          }
          
          Button("Add Timer") {
            showingAddTimer = true
          }
          .foregroundColor(.green)
        }
      }
      .navigationTitle("Edit")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            // Update the sequence in manager
            if let index = manager.sequences.firstIndex(where: { $0.id == sequence.id }) {
              manager.sequences[index] = editingSequence
              manager.currentSequence = editingSequence
            }
            dismiss()
          }
        }
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .sheet(isPresented: $showingAddTimer) {
        AddTimerView(sequence: $editingSequence)
      }
    }
  }
}

struct AddTimerView: View {
  @Binding var sequence: TimerSequenceData
  @Environment(\.dismiss) var dismiss
  @State private var name = ""
  @State private var duration = 30
  
  var body: some View {
    NavigationView {
      VStack {
        TextField("Timer Name", text: $name)
          .padding()
        
        Stepper("\(duration) seconds", value: $duration, in: 1...300, step: 5)
          .padding()
        
        Button("Add") {
          let timer = TimerItem(
            name: name.isEmpty ? "Timer" : name,
            duration: duration
          )
          sequence.timers.append(timer)
          dismiss()
        }
        .disabled(duration == 0)
      }
      .navigationTitle("Add Timer")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
  }
}
