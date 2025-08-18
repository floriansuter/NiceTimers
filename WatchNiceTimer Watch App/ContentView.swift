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
      VStack(spacing: 8) {
        if let currentSequence = manager.currentSequence {
          // Sequence selector button
          Button(action: { showingSequenceList = true }) {
            HStack {
              Text(currentSequence.name)
                .lineLimit(1)
                .font(.caption)
              Image(systemName: "chevron.down")
                .font(.caption2)
            }
          }
          .buttonStyle(.plain)
          .foregroundColor(.blue)
          
          if manager.isRunning {
            // Running timer display
            RunningTimerView(manager: manager)
          } else {
            // Timer list or empty state
            if currentSequence.timers.isEmpty {
              VStack(spacing: 12) {
                Image(systemName: "timer")
                  .font(.largeTitle)
                  .foregroundColor(.secondary)
                
                Text("No timers")
                  .font(.caption)
                  .foregroundColor(.secondary)
                
                Button("Add Timer") {
                  showingEditView = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
              }
              .padding()
            } else {
              // Timer list
              ScrollView {
                LazyVStack(spacing: 4) {
                  ForEach(Array(currentSequence.timers.enumerated()), id: \.element.id) { index, timer in
                    TimerRowView(timer: timer, index: index)
                  }
                }
                .padding(.horizontal, 4)
              }
              
              // Total time
              Text("Total: \(formatTotalTime(currentSequence.timers.reduce(0) { $0 + $1.duration }))")
                .font(.caption2)
                .foregroundColor(.secondary)
              
              // Control buttons
              HStack(spacing: 8) {
                Button(action: { manager.start() }) {
                  Image(systemName: "play.fill")
                    .font(.title3)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(currentSequence.timers.isEmpty)
                
                Button(action: { showingEditView = true }) {
                  Image(systemName: "pencil")
                    .font(.title3)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
              }
            }
          }
        } else {
          // Empty state - no sequences
          VStack(spacing: 12) {
            Image(systemName: "timer")
              .font(.largeTitle)
              .foregroundColor(.secondary)
            
            Text("No sequences")
              .font(.caption)
              .foregroundColor(.secondary)
            
            Button("Create Sequence") {
              _ = manager.addSequence(name: "New Sequence")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
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
  
  func formatTotalTime(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let mins = (seconds % 3600) / 60
    let secs = seconds % 60
    
    if hours > 0 {
      return String(format: "%dh %02dm", hours, mins)
    } else {
      return String(format: "%02d:%02d", mins, secs)
    }
  }
}

struct TimerRowView: View {
  let timer: TimerItem
  let index: Int
  
  var body: some View {
    HStack {
      Text("\(index + 1)")
        .font(.caption2)
        .foregroundColor(.secondary)
        .frame(width: 16)
      
      Text(timer.name)
        .font(.caption)
        .lineLimit(1)
      
      Spacer()
      
      Text(formatTime(timer.duration))
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .padding(.vertical, 2)
  }
  
  func formatTime(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let mins = (seconds % 3600) / 60
    let secs = seconds % 60
    
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, mins, secs)
    } else {
      return String(format: "%02d:%02d", mins, secs)
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
          .lineLimit(2)
          .multilineTextAlignment(.center)
        
        Text(formatTime(manager.remainingTime))
          .font(.system(size: 32, weight: .thin, design: .monospaced))
        
        // Progress ring
        ZStack {
          Circle()
            .stroke(Color.gray.opacity(0.3), lineWidth: 6)
          
          Circle()
            .trim(
              from: 0,
              to: CGFloat(manager.remainingTime) / CGFloat(sequence.timers[manager.currentTimerIndex].duration)
            )
            .stroke(Color.green, lineWidth: 6)
            .rotationEffect(.degrees(-90))
            .animation(.linear(duration: 1), value: manager.remainingTime)
        }
        .frame(width: 80, height: 80)
        
        Text("\(manager.currentTimerIndex + 1) of \(sequence.timers.count)")
          .font(.caption2)
          .foregroundColor(.secondary)
        
        Button("Stop") {
          manager.stop()
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .controlSize(.small)
      }
    }
  }
  
  func formatTime(_ seconds: Int) -> String {
    let mins = seconds / 60
    let secs = seconds % 60
    return String(format: "%02d:%02d", mins, secs)
  }
}

struct SequenceListView: View {
  @ObservedObject var manager: TimerSequenceManager
  @Environment(\.dismiss) var dismiss
  @State private var showingNewSequence = false
  @State private var newSequenceName = ""
  
  var body: some View {
    NavigationView {
      ScrollView {
        LazyVStack(spacing: 8) {
          ForEach(manager.sequences) { sequence in
            let timerCount = sequence.timers.count
            let totalDuration = sequence.timers.reduce(0) { $0 + $1.duration }
            let formattedTime = formatTotalTime(totalDuration)
            let isCurrentSequence = manager.currentSequence?.id == sequence.id
            
            Button(action: {
              manager.selectSequence(sequence)
              dismiss()
            }) {
              VStack(alignment: .leading, spacing: 4) {
                HStack {
                  Text(sequence.name)
                    .font(.headline)
                    .lineLimit(1)
                  Spacer()
                  if isCurrentSequence {
                    Image(systemName: "checkmark.circle.fill")
                      .foregroundColor(.green)
                      .font(.caption)
                  }
                }
                
                HStack {
                  Image(systemName: "timer")
                  Text("\(timerCount)")
                  Text("•")
                  Text(formattedTime)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
              }
              .padding(8)
              .background(Color(UIColor.secondarySystemBackground))
              .cornerRadius(8)
            }
            .buttonStyle(.plain)
          }
          
          Button("New Sequence") {
            showingNewSequence = true
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
        }
        .padding()
      }
      .navigationTitle("Sequences")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
      }
      .alert("New Sequence", isPresented: $showingNewSequence) {
        TextField("Name", text: $newSequenceName)
        Button("Create") {
          if !newSequenceName.isEmpty {
            let newSeq = manager.addSequence(name: newSequenceName)
            manager.selectSequence(newSeq)
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
  
  func formatTotalTime(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let mins = (seconds % 3600) / 60
    
    if hours > 0 {
      return "\(hours)h \(mins)m"
    } else {
      return "\(mins)m"
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
      ScrollView {
        VStack(spacing: 16) {
          // Sequence name
          VStack(alignment: .leading, spacing: 4) {
            Text("Sequence Name")
              .font(.caption)
              .foregroundColor(.secondary)
            TextField("Name", text: $editingSequence.name)
          }
          
          // Timers section
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Timers")
                .font(.caption)
                .foregroundColor(.secondary)
              Spacer()
              Button("Add Timer") {
                showingAddTimer = true
              }
              .font(.caption)
              .foregroundColor(.green)
            }
            
            if editingSequence.timers.isEmpty {
              Text("No timers yet")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
            } else {
              ForEach(Array(editingSequence.timers.enumerated()), id: \.element.id) { index, timer in
                let timerDuration = formatTime(timer.duration)
                
                NavigationLink(destination: EditTimerView(timer: $editingSequence.timers[index])) {
                  HStack {
                    Text("\(index + 1)")
                      .font(.caption2)
                      .foregroundColor(.secondary)
                      .frame(width: 16)
                    
                    Text(timer.name)
                      .font(.caption)
                      .lineLimit(1)
                    
                    Spacer()
                    
                    Text(timerDuration)
                      .font(.caption2)
                      .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                      .font(.caption2)
                      .foregroundColor(.secondary)
                  }
                  .padding(8)
                  .background(Color(UIColor.secondarySystemBackground))
                  .cornerRadius(6)
                }
                .buttonStyle(.plain)
              }
              .onDelete { indexSet in
                editingSequence.timers.remove(atOffsets: indexSet)
              }
            }
          }
        }
        .padding()
      }
      .navigationTitle("Edit")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            manager.updateSequence(editingSequence)
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
  
  func formatTime(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let mins = (seconds % 3600) / 60
    let secs = seconds % 60
    
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, mins, secs)
    } else {
      return String(format: "%02d:%02d", mins, secs)
    }
  }
}

struct EditTimerView: View {
  @Binding var timer: TimerItem
  @Environment(\.dismiss) var dismiss
  @State private var timerDate = Date()
  
  init(timer: Binding<TimerItem>) {
    self._timer = timer
    
    // Convert duration to Date for the picker
    let duration = timer.wrappedValue.duration
    let calendar = Calendar.current
    let baseDate = calendar.startOfDay(for: Date())
    let timerDate = calendar.date(byAdding: .second, value: duration, to: baseDate) ?? baseDate
    self._timerDate = State(initialValue: timerDate)
  }
  
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 16) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Timer Name")
              .font(.caption)
              .foregroundColor(.secondary)
            TextField("Name", text: $timer.name)
          }
          
          VStack(alignment: .leading, spacing: 4) {
            Text("Duration")
              .font(.caption)
              .foregroundColor(.secondary)
            
            DatePicker(
              "Duration",
              selection: $timerDate,
              displayedComponents: [.hourMinuteAndSecond]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
          }
        }
        .padding()
      }
      .navigationTitle("Edit Timer")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            // Convert Date back to duration in seconds
            let calendar = Calendar.current
            let baseDate = calendar.startOfDay(for: Date())
            let components = calendar.dateComponents([.hour, .minute, .second], from: baseDate, to: timerDate)
            timer.duration = (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0)
            dismiss()
          }
        }
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
  }
}

struct AddTimerView: View {
  @Binding var sequence: TimerSequenceData
  @Environment(\.dismiss) var dismiss
  @State private var name = ""
  @State private var timerDate = Date()
  
  init(sequence: Binding<TimerSequenceData>) {
    self._sequence = sequence
    
    // Set default to 30 seconds
    let calendar = Calendar.current
    let baseDate = calendar.startOfDay(for: Date())
    let defaultDate = calendar.date(byAdding: .second, value: 30, to: baseDate) ?? baseDate
    self._timerDate = State(initialValue: defaultDate)
  }
  
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 16) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Timer Name")
              .font(.caption)
              .foregroundColor(.secondary)
            TextField("Name", text: $name)
          }
          
          VStack(alignment: .leading, spacing: 4) {
            Text("Duration")
              .font(.caption)
              .foregroundColor(.secondary)
            
            DatePicker(
              "Duration",
              selection: $timerDate,
              displayedComponents: [.hourMinuteAndSecond]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
          }
        }
        .padding()
      }
      .navigationTitle("Add Timer")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") {
            // Convert Date to duration in seconds
            let calendar = Calendar.current
            let baseDate = calendar.startOfDay(for: Date())
            let components = calendar.dateComponents([.hour, .minute, .second], from: baseDate, to: timerDate)
            let duration = (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0)
            
            let timer = TimerItem(
              name: name.isEmpty ? "Timer" : name,
              duration: max(1, duration) // Ensure at least 1 second
            )
            sequence.timers.append(timer)
            dismiss()
          }
        }
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
  }
}
