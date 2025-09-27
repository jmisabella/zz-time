import SwiftUI

struct ExpandingView: View {
    // Centralized dimming duration in minutes
    private let defaultDimDurationMinutes: Double = 3
    
    // Computed property to convert minutes to seconds
    private var defaultDimDurationSeconds: Double {
        defaultDimDurationMinutes * 60
    }
    
    let color: Color
    let dismiss: () -> Void
    @Binding var durationMinutes: Double
    @Binding var isAlarmActive: Bool
    @Binding var isAlarmEnabled: Bool
    let changeRoom: (Int) -> Void
    let currentIndex: Int
    let maxIndex: Int
    let selectAlarm: () -> Void
    
    @State private var showLabel: Bool = false
    @State private var dimOverlayOpacity: Double = 0.0
    @State private var flashOverlayOpacity: Double = 0.0
    @State private var dimMode: DimMode = .duration(0) // Will be set in onAppear
    @State private var roomChangeTrigger: Bool = false
    @State private var showTimePicker: Bool = false
    @State private var tempWakeTime: Date = Date()
    @State private var usePlasmaStyle: Bool = Bool.random()
    @State private var remainingTimer: Timer? = nil
    
    var body: some View {
        ZStack {
            ZStack {
                if usePlasmaStyle {
                    PlasmaBackground(color: color).ignoresSafeArea()
                } else {
                    BreathingBackground(color: color).ignoresSafeArea()
                }
                
                Rectangle()
                    .fill(isAlarmActive ? Color(hue: 0.58, saturation: 0.3, brightness: 0.9) : .black)
                    .opacity(dimOverlayOpacity)
                    .ignoresSafeArea()
                
                Rectangle()
                    .fill(Color.white)
                    .opacity(flashOverlayOpacity)
                    .ignoresSafeArea()
            }
            
            VStack {
                CustomSlider(
                    value: $durationMinutes,
                    minValue: 0,
                    maxValue: 1440,  // 24 hours in minutes
                    step: 1,
                    onEditingChanged: { editing in
                        showLabel = editing
                    }
                )
                .padding(.horizontal, 40)
                
                if showLabel {
                    let text: String = {
                        if durationMinutes == 0 {
                            return "infinite"
                        } else if durationMinutes < 60 {
                            let minutes = Int(durationMinutes)
                            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
                        } else {
                            let hours = Int(durationMinutes / 60)
                            let minutes = Int(durationMinutes.truncatingRemainder(dividingBy: 60))
                            if minutes == 0 {
                                return "\(hours) hour\(hours == 1 ? "" : "s")"
                            } else {
                                return "\(hours) hour\(hours == 1 ? "" : "s"), \(minutes) minute\(minutes == 1 ? "" : "s")"
                            }
                        }
                    }()
                    
                    Text(text)
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                Text("room \(currentIndex + 1)")
                    .font(.system(size: 14, weight: .light, design: .rounded))
                    .foregroundColor((currentIndex < 10) ? Color(white: 0.7) : Color(white: 0.3))
                    .padding(.bottom, 20)
                
                HStack(spacing: 40) {
                    Button {
                        dimMode = .duration(defaultDimDurationSeconds)
                        dimOverlayOpacity = 0
                        flashOverlayOpacity = 0.8
                        withAnimation(.linear(duration: 0.5)) {
                            flashOverlayOpacity = 0
                        }
                        withAnimation(.linear(duration: defaultDimDurationSeconds)) {
                            dimOverlayOpacity = 1
                        }
                    } label: {
                        Image(systemName: "sun.max.fill")
                            .font(.title)
                            .foregroundColor(Color(white: 0.7))
                            .padding(10)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .contentShape(Circle())
                    
                    Button {
                        dimMode = .duration(4)
                        dimOverlayOpacity = 0
                        flashOverlayOpacity = 0
                        withAnimation(.linear(duration: 4)) {
                            dimOverlayOpacity = 1
                        }
                    } label: {
                        Image(systemName: "moon.fill")
                            .font(.title)
                            .foregroundColor(Color(white: 0.7))
                            .padding(10)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .contentShape(Circle())
                    
                    Button {
                        if durationMinutes > 0 {
                            let wasEnabled = isAlarmEnabled
                            isAlarmEnabled.toggle()
                            UserDefaults.standard.set(isAlarmEnabled, forKey: "isAlarmEnabled")
                            if !wasEnabled {
                                let now = Date()
                                let newWakeDate = now.addingTimeInterval(durationMinutes * 60)
                                UserDefaults.standard.set(newWakeDate, forKey: "lastWakeTime")
                                selectAlarm()
                            }
                        }
                    } label: {
                        Image(systemName: isAlarmEnabled ? "bell.fill" : "bell.slash.fill")
                            .font(.title)
                            .foregroundColor(Color(white: 0.7))
                            .padding(10)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .contentShape(Circle())
                    .disabled(durationMinutes == 0)
                    .opacity(durationMinutes == 0 ? 0.5 : 1.0)
                    
                    Button {
                        if let savedTime = UserDefaults.standard.object(forKey: "lastWakeTime") as? Date {
                            tempWakeTime = savedTime
                        } else {
                            let now = Date()
                            if durationMinutes > 0 {
                                tempWakeTime = now.addingTimeInterval(durationMinutes * 60)
                            } else {
                                tempWakeTime = Calendar.current.date(byAdding: .hour, value: 8, to: now) ?? now
                            }
                        }
                        showTimePicker = true
                    } label: {
                        Image(systemName: "clock")
                            .font(.title)
                            .foregroundColor(Color(white: 0.7))
                            .padding(10)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .contentShape(Circle())
                    .disabled(durationMinutes == 0 && !isAlarmEnabled)
                    .opacity(durationMinutes == 0 && !isAlarmEnabled ? 0.5 : 1.0)
                }
                .padding(.bottom, 40)
            }
        }
        .gesture(
            SimultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        print("Background tapped")
                        withAnimation(.easeInOut(duration: 0.3)) {
                            dismiss()
                        }
                    },
                DragGesture(minimumDistance: 20, coordinateSpace: .global)
                    .onEnded { value in
                        let translationHeight = value.translation.height
                        let translationWidth = value.translation.width
                        if translationHeight < -50 {
                            selectAlarm()
                        } else if translationHeight > 100 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                dismiss()
                            }
                        } else if translationWidth < -50 {
                            changeRoom(1)
                            roomChangeTrigger.toggle()
                        } else if translationWidth > 50 {
                            changeRoom(-1)
                            roomChangeTrigger.toggle()
                        }
                    }
            )
        )
        .onAppear {
            dimMode = .duration(defaultDimDurationSeconds)
            if case .duration(let seconds) = dimMode {
                flashOverlayOpacity = 0
                withAnimation(.linear(duration: seconds)) {
                    dimOverlayOpacity = 1
                }
            }
            if isAlarmEnabled {
                updateDurationToRemaining()
                remainingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                    updateDurationToRemaining()
                }
            }
        }
        .onDisappear {
            remainingTimer?.invalidate()
            remainingTimer = nil
        }
        .onChange(of: isAlarmActive) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    dimOverlayOpacity = 0.8
                }
            } else {
                withAnimation(.none) {
                    dimOverlayOpacity = 0
                }
                if case .duration(let seconds) = dimMode {
                    withAnimation(.linear(duration: seconds)) {
                        dimOverlayOpacity = 1
                    }
                }
            }
        }
        .onChange(of: roomChangeTrigger) { _, _ in
            flashOverlayOpacity = 0.8
            dimOverlayOpacity = 0
            withAnimation(.linear(duration: 0.5)) {
                flashOverlayOpacity = 0
            }
            if case .duration(let seconds) = dimMode {
                withAnimation(.linear(duration: seconds)) {
                    dimOverlayOpacity = 1
                }
            }
        }
        .sheet(isPresented: $showTimePicker) {
            VStack(spacing: 20) {
                DatePicker("Wake Up Time", selection: $tempWakeTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                
                Button("Set") {
                    let now = Date()
                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.hour, .minute], from: tempWakeTime)
                    var wakeDate = calendar.date(bySettingHour: components.hour ?? 0,
                                                 minute: components.minute ?? 0,
                                                 second: 0,
                                                 of: now) ?? now
                    
                    if wakeDate <= now {
                        wakeDate = calendar.date(byAdding: .day, value: 1, to: wakeDate) ?? wakeDate
                    }
                    
                    let durationSeconds = wakeDate.timeIntervalSince(now)
                    durationMinutes = max(1, min(1440, durationSeconds / 60))  // Clamp to min 1 min, max 24 hours
                    
                    UserDefaults.standard.set(wakeDate, forKey: "lastWakeTime") // Save the absolute wake date
                    
                    if !isAlarmEnabled {
                        isAlarmEnabled = true
                        UserDefaults.standard.set(true, forKey: "isAlarmEnabled")
                        selectAlarm()
                    }
                    
                    showTimePicker = false
                }
                .font(.headline)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .presentationDetents([.medium])
        }
    }
    
    private func updateDurationToRemaining() {
        if let wakeDate = UserDefaults.standard.object(forKey: "lastWakeTime") as? Date {
            let now = Date()
            let remainingMinutes = wakeDate.timeIntervalSince(now) / 60
            if remainingMinutes > 0 {
                durationMinutes = min(1440, remainingMinutes)
            } else {
                durationMinutes = 0
                isAlarmEnabled = false
                UserDefaults.standard.set(false, forKey: "isAlarmEnabled")
            }
            UserDefaults.standard.set(durationMinutes, forKey: "durationMinutes")
        }
    }
}

