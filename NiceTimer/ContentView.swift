//
//  ContentView.swift
//  NiceTimer
//
//  Created by Florian Suter on 16.08.2025.
//

import SwiftUI

struct ContentView: View {
  @StateObject private var manager = TimerSequenceManager()
  @State private var showingEditView = false
  @State private var showingNewSequence = false
  @State private var selectedSequence: TimerSequenceData?
  
  var body: some View {
    NavigationView {
      // Sidebar with sequences
      SequenceSidebarView(manager: manager, selectedSequence: $selectedSequence)
      
      // Main content
      if let sequence = selectedSequence ?? manager.currentSequence {
        SequenceDetailView(manager: manager, sequence: sequence)
      } else {
        EmptyStateView(showingNewSequence: $showingNewSequence)
      }
    }
    .sheet(isPresented: $showingNewSequence) {
      NewSequenceView(manager: manager)
    }
  }
}

struct SequenceSidebarView: View {
  @ObservedObject var manager: TimerSequenceManager
  @Binding var selectedSequence: TimerSequenceData?
  @State private var showingNewSequence = false
  
  var body: some View {
    List {
      Section("Sequences") {
        ForEach(manager.sequences) { sequence in
          SequenceRowView(
            sequence: sequence,
            isSelected: selectedSequence?.id == sequence.id ||
                       (selectedSequence == nil && manager.currentSequence?.id == sequence.id),
            manager: manager
          )
          .onTapGesture {
            selectedSequence = sequence
            manager.selectSequence(sequence)
          }
        }
        .onDelete { indexSet in
          indexSet.forEach { index in
            manager.deleteSequence(manager.sequences[index])
          }
        }
      }
    }
    .navigationTitle("Timer Sequences")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button(action: { showingNewSequence = true }) {
          Label("Add Sequence", systemImage: "plus")
        }
      }
    }
    .sheet(isPresented: $showingNewSequence) {
      NewSequenceView(manager: manager)
    }
  }
}

struct SequenceRowView: View {
  let sequence: TimerSequenceData
  let isSelected: Bool
  let manager: TimerSequenceManager
  
  var totalDuration: Int {
    sequence.timers.reduce(0) { $0 + $1.duration }
  }
  
  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(sequence.name)
          .font(.headline)
          .foregroundColor(isSelected ? .accentColor : .primary)
        
        HStack {
          Label("\(sequence.timers.count)", systemImage: "timer")
          Text("•")
          Text(formatTotalTime(totalDuration))
        }
        .font(.caption)
        .foregroundColor(.secondary)
      }
      
      Spacer()
      
      if manager.currentSequence?.id == sequence.id && manager.isRunning {
        Image(systemName: "play.fill")
          .foregroundColor(.green)
          .font(.caption)
      }
    }
    .padding(.vertical, 4)
  }
  
  func formatTotalTime(_ seconds: Int) -> String {
    if seconds >= 3600 {
      let hours = seconds / 3600
      let mins = (seconds % 3600) / 60
      return "\(hours)h \(mins)m"
    } else {
      let mins = seconds / 60
      let secs = seconds % 60
      return "\(mins)m \(secs)s"
    }
  }
}

struct SequenceDetailView: View {
  @ObservedObject var manager: TimerSequenceManager
  let sequence: TimerSequenceData
  @State private var showingEditView = false
  
  var body: some View {
    VStack(spacing: 0) {
      // Timer display area
      if manager.currentSequence?.id == sequence.id && manager.isRunning {
        RunningTimerView(manager: manager)
          .frame(maxHeight: 300)
          .background(Color(UIColor.secondarySystemBackground))
      }
      
      // Sequence content
      List {
        Section {
          ForEach(Array(sequence.timers.enumerated()), id: \.element.id) { index, timer in
            TimerRowView(
              timer: timer,
              index: index,
              isActive: manager.currentSequence?.id == sequence.id &&
                       manager.isRunning &&
                       manager.currentTimerIndex == index
            )
          }
        } header: {
          HStack {
            Text("Timers")
            Spacer()
            Text("Total: \(formatTotalTime(sequence.timers.reduce(0) { $0 + $1.duration }))")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
      
      // Control buttons
      TimerControlsView(manager: manager, sequence: sequence)
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    .navigationTitle(sequence.name)
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      ToolbarItemGroup(placement: .navigationBarTrailing) {
        Button(action: { showingEditView = true }) {
          Label("Edit", systemImage: "pencil")
        }
        
        Menu {
          Button(action: { manager.duplicateSequence(sequence) }) {
            Label("Duplicate", systemImage: "doc.on.doc")
          }
          
          Button(role: .destructive, action: { manager.deleteSequence(sequence) }) {
            Label("Delete", systemImage: "trash")
          }
        } label: {
          Label("More", systemImage: "ellipsis.circle")
        }
      }
    }
    .sheet(isPresented: $showingEditView) {
      EditSequenceView(manager: manager, sequence: sequence)
    }
  }
  
  func formatTotalTime(_ seconds: Int) -> String {
    let mins = seconds / 60
    let secs = seconds % 60
    return String(format: "%02d:%02d", mins, secs)
  }
}

struct TimerRowView: View {
  let timer: TimerItem
  let index: Int
  let isActive: Bool
  
  var body: some View {
    HStack {
      Text("\(index + 1)")
        .font(.caption)
        .foregroundColor(.secondary)
        .frame(width: 20)
      
      Text(timer.name)
        .font(.body)
        .fontWeight(isActive ? .semibold : .regular)
      
      Spacer()
      
      Text(formatTime(timer.duration))
        .font(.system(.body, design: .monospaced))
        .foregroundColor(isActive ? .accentColor : .secondary)
      
      if isActive {
        Image(systemName: "play.fill")
          .font(.caption)
          .foregroundColor(.green)
      }
    }
    .padding(.vertical, 4)
    .background(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
    .cornerRadius(8)
  }
  
  func formatTime(_ seconds: Int) -> String {
    let mins = seconds / 60
    let secs = seconds % 60
    return String(format: "%02d:%02d", mins, secs)
  }
}

struct RunningTimerView: View {
  @ObservedObject var manager: TimerSequenceManager
  
  var body: some View {
    VStack(spacing: 20) {
      if let sequence = manager.currentSequence {
        Text(sequence.timers[manager.currentTimerIndex].name)
          .font(.title2)
          .fontWeight(.semibold)
        
        Text(formatTime(manager.remainingTime))
          .font(.system(size: 72, weight: .thin, design: .monospaced))
        
        // Progress ring
        ZStack {
          Circle()
            .stroke(Color.gray.opacity(0.2), lineWidth: 10)
          
          Circle()
            .trim(
              from: 0,
              to: CGFloat(manager.remainingTime) / CGFloat(sequence.timers[manager.currentTimerIndex].duration)
            )
            .stroke(Color.accentColor, lineWidth: 10)
            .rotationEffect(.degrees(-90))
            .animation(.linear(duration: 1), value: manager.remainingTime)
        }
        .frame(width: 150, height: 150)
        
        HStack {
          Text("Timer \(manager.currentTimerIndex + 1) of \(sequence.timers.count)")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
    .padding()
  }
  
  func formatTime(_ seconds: Int) -> String {
    let mins = seconds / 60
    let secs = seconds % 60
    return String(format: "%02d:%02d", mins, secs)
  }
}

struct TimerControlsView: View {
  @ObservedObject var manager: TimerSequenceManager
  let sequence: TimerSequenceData
  
  var body: some View {
    HStack(spacing: 20) {
      if manager.currentSequence?.id == sequence.id && manager.isRunning {
        Button(action: { manager.stop() }) {
          Label("Stop", systemImage: "stop.fill")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(.red)
      } else {
        Button(action: {
          manager.selectSequence(sequence)
          manager.start()
        }) {
          Label("Start", systemImage: "play.fill")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(sequence.timers.isEmpty)
      }
    }
  }
}

struct EditSequenceView: View {
  @ObservedObject var manager: TimerSequenceManager
  let sequence: TimerSequenceData
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
      Form {
        Section("Sequence Name") {
          TextField("Name", text: $editingSequence.name)
        }
        
        Section("Timers") {
          ForEach(Array(editingSequence.timers.enumerated()), id: \.element.id) { index, timer in
            NavigationLink(destination: EditTimerView(timer: $editingSequence.timers[index])) {
              HStack {
                Text("\(index + 1)")
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .frame(width: 20)
                
                Text(timer.name)
                
                Spacer()
                
                Text(formatTime(timer.duration))
                  .foregroundColor(.secondary)
              }
            }
          }
          .onDelete { indexSet in
            editingSequence.timers.remove(atOffsets: indexSet)
          }
          .onMove { source, destination in
            editingSequence.timers.move(fromOffsets: source, toOffset: destination)
          }
          
          Button(action: { showingAddTimer = true }) {
            Label("Add Timer", systemImage: "plus.circle.fill")
          }
        }
      }
      .navigationTitle("Edit Sequence")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            manager.updateSequence(editingSequence)
            dismiss()
          }
        }
        
        ToolbarItem(placement: .principal) {
          EditButton()
        }
      }
      .sheet(isPresented: $showingAddTimer) {
        AddTimerView(sequence: $editingSequence)
      }
    }
  }
  
  func formatTime(_ seconds: Int) -> String {
    let mins = seconds / 60
    let secs = seconds % 60
    return String(format: "%02d:%02d", mins, secs)
  }
}

struct EditTimerView: View {
  @Binding var timer: TimerItem
  @Environment(\.dismiss) var dismiss
  
  @State private var minutes: Int
  @State private var seconds: Int
  
  init(timer: Binding<TimerItem>) {
    self._timer = timer
    let totalSeconds = timer.wrappedValue.duration
    self._minutes = State(initialValue: totalSeconds / 60)
    self._seconds = State(initialValue: totalSeconds % 60)
  }
  
  var body: some View {
    Form {
      Section("Timer Name") {
        TextField("Name", text: $timer.name)
      }
      
      Section("Duration") {
        Picker("Minutes", selection: $minutes) {
          ForEach(0..<100) { min in
            Text("\(min) min").tag(min)
          }
        }
        
        Picker("Seconds", selection: $seconds) {
          ForEach(0..<60) { sec in
            Text("\(sec) sec").tag(sec)
          }
        }
      }
    }
    .navigationTitle("Edit Timer")
    .navigationBarTitleDisplayMode(.inline)
    .onDisappear {
      timer.duration = (minutes * 60) + seconds
    }
  }
}

struct AddTimerView: View {
  @Binding var sequence: TimerSequenceData
  @Environment(\.dismiss) var dismiss
  
  @State private var name = ""
  @State private var minutes = 0
  @State private var seconds = 30
  
  var body: some View {
    NavigationView {
      Form {
        Section("Timer Name") {
          TextField("Name", text: $name)
        }
        
        Section("Duration") {
          Picker("Minutes", selection: $minutes) {
            ForEach(0..<100) { min in
              Text("\(min) min").tag(min)
            }
          }
          
          Picker("Seconds", selection: $seconds) {
            ForEach(0..<60) { sec in
              Text("\(sec) sec").tag(sec)
            }
          }
        }
      }
      .navigationTitle("Add Timer")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") {
            let duration = (minutes * 60) + seconds
            let timer = TimerItem(
              name: name.isEmpty ? "Timer" : name,
              duration: duration
            )
            sequence.timers.append(timer)
            dismiss()
          }
          .disabled(minutes == 0 && seconds == 0)
        }
      }
    }
  }
}

struct NewSequenceView: View {
  @ObservedObject var manager: TimerSequenceManager
  @Environment(\.dismiss) var dismiss
  @State private var name = ""
  
  var body: some View {
    NavigationView {
      Form {
        Section("Sequence Name") {
          TextField("Name", text: $name)
        }
      }
      .navigationTitle("New Sequence")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") {
            if !name.isEmpty {
              _ = manager.addSequence(name: name)
              dismiss()
            }
          }
          .disabled(name.isEmpty)
        }
      }
    }
  }
}

struct EmptyStateView: View {
  @Binding var showingNewSequence: Bool
  
  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "timer")
        .font(.system(size: 60))
        .foregroundColor(.secondary)
      
      Text("No Timer Sequences")
        .font(.title2)
        .fontWeight(.semibold)
      
      Text("Create your first timer sequence to get started")
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
      
      Button(action: { showingNewSequence = true }) {
        Label("Create Sequence", systemImage: "plus")
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
    }
    .padding()
  }
}
