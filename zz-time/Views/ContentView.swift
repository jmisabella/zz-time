import SwiftUI
import AVFoundation

struct ContentView: View {
    let files: [String] = (1...30).map { String(format: "ambient_%02d", $0) }
    
    @Namespace private var animation: Namespace.ID
    @State private var selectedItem: SelectedItem? = nil
    @State private var currentPlayer: AVAudioPlayer? = nil
    @State private var currentTimer: Timer? = nil
    @State private var currentAudioFile: String? = nil
    @State private var durationMinutes: Double = UserDefaults.standard.double(forKey: "durationMinutes")
    @State private var stopTimer: Timer? = nil
    @State private var alarmPlayer: AVAudioPlayer? = nil
    @State private var alarmTimer: Timer? = nil
    @State private var hapticGenerator: UINotificationFeedbackGenerator? = nil
    @State private var isAlarmActive: Bool = false
    @State private var backgroundOpacity: Double = UserDefaults.standard.bool(forKey: "hasLaunched") ? 1.0 : 0.0
    @State private var selectedAlarmIndex: Int? = UserDefaults.standard.object(forKey: "selectedAlarmIndex") as? Int
    @State private var showingAlarmSelection: Bool = false
    
    private func findNextValidIndex(from currentIndex: Int, direction: Int) -> Int? {
        var newIndex = currentIndex + direction
        while newIndex >= 0 && newIndex < files.count {
            if !files[newIndex].isEmpty {
                return newIndex
            }
            newIndex += direction
        }
        return nil
    }
    
    private func colorFor(row: Int, col: Int) -> Color {
        let diag = CGFloat(row + col) / 9.0 // Max sum of row (0-5) + col (0-4) = 9
        if row <= 1 {
            // White noise (rows 0-1): Diagonal dark purple gradient
            let startHue: CGFloat = 0.67 // Dark purple
            let endHue: CGFloat = 0.75 // Lighter purple
            let startSaturation: CGFloat = 0.7
            let endSaturation: CGFloat = 0.5
            let startBrightness: CGFloat = 0.5 // Darker
            let endBrightness: CGFloat = 0.7 // Lighter
            let hue = startHue + (endHue - startHue) * diag
            let saturation = startSaturation - (startSaturation - endSaturation) * diag
            let brightness = startBrightness + (endBrightness - startBrightness) * diag
            return Color(hue: hue, saturation: saturation, brightness: brightness)
        } else if row <= 3 {
            // Nighttime music (rows 2-3): Pink/purple/green diagonal gradient
            let origRow = row - 2
            let diag = CGFloat(origRow + col) / 6.0 // Max sum of origRow (0-1) + col (0-4) = 5
            let startHue: CGFloat = 0.8 // Pink
            let endHue: CGFloat = 0.33 // Green
            let hue = startHue - (startHue - endHue) * diag
            let saturation: CGFloat = 0.3
            let brightness: CGFloat = 0.9
            return Color(hue: hue, saturation: saturation, brightness: brightness)
        } else {
            // Waking audio (rows 4-5): Beige/orange diagonal gradient
            let origRow = row - 4
            let diag = CGFloat(origRow + col) / 5.0 // Max sum of origRow (0-1) + col (0-4) = 5
            let startHue: CGFloat = 0.0 // Light grey
            let endHue: CGFloat = 0.083 // Muted orange
            let startSaturation: CGFloat = 0.1 // Light grey
            let endSaturation: CGFloat = 0.6 // Muted orange
            let startBrightness: CGFloat = 0.9 // Light grey
            let endBrightness: CGFloat = 0.7 // Muted orange
            let hue = startHue + (endHue - startHue) * diag
            let saturation = startSaturation + (endSaturation - startSaturation) * diag
            let brightness = startBrightness - (startBrightness - endBrightness) * diag
            return Color(hue: hue, saturation: saturation, brightness: brightness)
        }
    }

    var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(white: 0.15),
                Color(white: 0.30)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .opacity(backgroundOpacity)
        .ignoresSafeArea()
    }
    
    var backgroundColor: some View {
        Color(white: 0.8)
            .opacity(1.0 - backgroundOpacity)
            .ignoresSafeArea()
    }
    
    var roomGrid: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 10
            let padding: CGFloat = 20
            let availW = geo.size.width - 2 * padding
            let availH = geo.size.height - 2 * padding
            let numCols: CGFloat = 5
            let numRows: CGFloat = 6
            let itemW = (availW - spacing * (numCols - 1)) / numCols
            let maxItemH = (availH - spacing * (numRows - 1)) / numRows
            let itemH = min(itemW, maxItemH)
            let aspect = itemW / itemH
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: 5), spacing: spacing) {
                ForEach(0..<30) { index in
                    AlarmItemView(
                        index: index,
                        aspect: aspect,
                        colorFor: colorFor,
                        files: files,
                        selectedItem: selectedItem,
                        animation: animation
                    ) { selectedIndex in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedItem = SelectedItem(id: selectedIndex)
                        }
                    }
                }
            }
            .disabled(selectedItem != nil)
        }
        .padding(20)
    }
    
    var body: some View {
        ZStack {
            if selectedItem == nil {
                backgroundGradient
            } else {
                backgroundColor
            }
            
            if selectedItem == nil {
                roomGrid
            }
            
            if let item = selectedItem {
                let index = item.id
                let row = index / 5
                let col = index % 5
                let color = colorFor(row: row, col: col)
                
                ExpandingView(
                    color: color,
                    dismiss: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedItem = nil
                        }
                    },
                    durationMinutes: $durationMinutes,
                    isAlarmActive: $isAlarmActive,
                    changeRoom: { direction in
                        if let nextIndex = findNextValidIndex(from: index, direction: direction) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedItem = SelectedItem(id: nextIndex)
                            }
                        }
                    },
                    currentIndex: index,
                    maxIndex: files.count - 1,
                    selectAlarm: {
                        showingAlarmSelection = true
                    }
                )
                .matchedGeometryEffect(id: index, in: animation)
                .zIndex(1)
            }
            
            if isAlarmActive {
                ZStack {
                    Color.black.opacity(0.5)
                    VStack {
//                        Text("Tap to stop alarm")
//                            .font(.title)
//                            .foregroundColor(.white)
                    }
                }
                .ignoresSafeArea()
                .onTapGesture {
                    fadeOutAlarm {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedItem = nil
                        }
                    }
                }
                .zIndex(2)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onEnded { value in
                    let translationHeight = value.translation.height
                    if translationHeight < -50 && selectedItem == nil && !isAlarmActive {
                        showingAlarmSelection = true
                    }
                }
        )
        .onAppear {
            configureAudioSession()
            if !UserDefaults.standard.bool(forKey: "hasLaunched") {
                withAnimation(.easeInOut(duration: 2.0)) {
                    backgroundOpacity = 1.0
                }
                UserDefaults.standard.set(true, forKey: "hasLaunched")
            }
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            if let old = oldValue, newValue == nil {
                // Exiting a room: Clean up both current audio and alarm
                fadeOutCurrent()
                fadeOutAlarm() // Ensure alarm is stopped and cleaned up
                stopTimer?.invalidate() // Invalidate stopTimer to prevent it from triggering startAlarm
                stopTimer = nil
                UserDefaults.standard.removeObject(forKey: "lastWakeTime") // Clear wake time
            } else if let new = newValue {
                let selectedIndex = new.id
                fadeOutCurrent {
                    playAudio(for: selectedIndex)
                    if durationMinutes > 0 {
                        stopTimer?.invalidate()
                        let durationSeconds = durationMinutes * 60
                        stopTimer = Timer.scheduledTimer(withTimeInterval: durationSeconds, repeats: false) { _ in
                            if self.selectedAlarmIndex != nil && self.selectedItem != nil { // Only start alarm if still in a room
                                self.startAlarm()
                            } else {
                                self.fadeOutCurrent {
                                    UserDefaults.standard.removeObject(forKey: "lastWakeTime")
                                }
                            }
                        }
                    } else {
                        stopTimer?.invalidate()
                        stopTimer = nil
                    }
                }
            }
        }
        .onChange(of: durationMinutes) { old, new in
            UserDefaults.standard.set(new, forKey: "durationMinutes")
            if let item = selectedItem {
                if new > 0 {
                    stopTimer?.invalidate()
                    let durationSeconds = new * 60
                    stopTimer = Timer.scheduledTimer(withTimeInterval: durationSeconds, repeats: false) { _ in
                        if self.selectedAlarmIndex != nil {
                            self.startAlarm()
                        } else {
                            self.fadeOutCurrent {
                                UserDefaults.standard.removeObject(forKey: "lastWakeTime")
                            }
                        }
                    }
                    let now = Date()
                    let newWakeDate = now.addingTimeInterval(new * 60)
                    UserDefaults.standard.set(newWakeDate, forKey: "lastWakeTime")
                } else {
                    stopTimer?.invalidate()
                    stopTimer = nil
                    UserDefaults.standard.removeObject(forKey: "lastWakeTime")
                }
            }
        }
        .onChange(of: selectedAlarmIndex) { _, new in
            UserDefaults.standard.set(new, forKey: "selectedAlarmIndex")
        }
        .sheet(isPresented: $showingAlarmSelection) {
            AlarmSelectionView(
                selectedAlarmIndex: $selectedAlarmIndex,
                files: files,
                fadeMainTo: { target in
                    fadeCurrentTo(target: target)
                }
            )
            .presentationDetents([.medium])
        }
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error configuring AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    private func playAudio(for index: Int) {
        let file = files[index]
        guard let url = Bundle.main.url(forResource: file, withExtension: "mp3") else {
            print("Audio file not found: \(file).mp3")
            return
        }
        do {
            configureAudioSession() // Ensure session is set before playing
            currentPlayer = try AVAudioPlayer(contentsOf: url)
            currentPlayer?.numberOfLoops = -1
            currentPlayer?.volume = 0.0
            currentPlayer?.play()
            
            let fadeDuration: Double = 2.0
            let fadeSteps: Int = 20
            let stepDuration = fadeDuration / Double(fadeSteps)
            let stepIncrement = 1.0 / Float(fadeSteps)
            
            currentTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
                if let currentVolume = self.currentPlayer?.volume, currentVolume < 1.0 {
                    self.currentPlayer?.volume = min(1.0, currentVolume + stepIncrement)
                } else {
                    self.currentTimer?.invalidate()
                    self.currentTimer = nil
                }
            }
            currentAudioFile = file
        } catch {
            print("Error playing audio: \(error.localizedDescription)")
        }
    }
    
    private func fadeOutCurrent(completion: (() -> Void)? = nil) {
        if let player = currentPlayer, player.volume > 0.0 {
            currentTimer?.invalidate()
            let vol = player.volume
            let fadeDuration = 2.0 * Double(vol) / 1.0
            let fadeSteps = 20
            let stepDuration = fadeDuration / Double(fadeSteps)
            let stepDecrement = vol / Float(fadeSteps)
            
            currentTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
                if let currentVolume = self.currentPlayer?.volume, currentVolume > 0.0 {
                    self.currentPlayer?.volume = max(0.0, currentVolume - stepDecrement)
                } else {
                    self.currentTimer?.invalidate()
                    self.currentTimer = nil
                    self.currentPlayer?.stop()
                    self.currentPlayer = nil
                    self.currentAudioFile = nil
                    completion?()
                }
            }
        } else {
            currentPlayer?.stop()
            currentPlayer = nil
            currentAudioFile = nil
            completion?()
        }
    }
    
    private func fadeCurrentTo(target: Float, duration: Double = 2.0) {
        guard let player = currentPlayer else { return }
        currentTimer?.invalidate()
        let currentVol = player.volume
        if currentVol == target { return }
        let direction = target > currentVol ? 1 : -1
        let remaining = abs(target - currentVol)
        let fadeDuration = duration * Double(remaining) / 1.0
        let steps = 20
        let stepDuration = fadeDuration / Double(steps)
        let stepChange = Float(remaining) / Float(steps) * Float(direction)
        currentTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
            if let vol = self.currentPlayer?.volume {
                let newVol = vol + stepChange
                if (direction > 0 && newVol > target) || (direction < 0 && newVol < target) {
                    self.currentPlayer?.volume = target
                    self.currentTimer?.invalidate()
                    self.currentTimer = nil
                } else {
                    self.currentPlayer?.volume = newVol
                }
            } else {
                self.currentTimer?.invalidate()
                self.currentTimer = nil
            }
        }
    }
    
    private func startAlarm() {
        // Only start the alarm if a room is active
        guard selectedItem != nil else {
            print("No room active, skipping alarm")
            isAlarmActive = false
            stopTimer?.invalidate()
            stopTimer = nil
            UserDefaults.standard.removeObject(forKey: "lastWakeTime")
            return
        }
        
        if alarmPlayer != nil {
            return
        }
        
        stopTimer?.invalidate()
        stopTimer = nil
        isAlarmActive = true
        
        guard let idx = selectedAlarmIndex,
              idx >= 0 && idx < files.count,
              !files[idx].isEmpty else {
            print("Invalid alarm index or empty file")
            isAlarmActive = false
            return
        }
        
        let alarmFile = files[idx]
        guard let url = Bundle.main.url(forResource: alarmFile, withExtension: "mp3") else {
            print("Alarm audio file not found: \(alarmFile).mp3")
            isAlarmActive = false
            return
        }
        
        fadeOutCurrent()
        UserDefaults.standard.removeObject(forKey: "lastWakeTime")
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.0
            player.play()
            self.alarmPlayer = player
            
            let fadeDuration: Double = 0.5
            let fadeSteps: Int = 10
            let stepDuration = fadeDuration / Double(fadeSteps)
            let stepIncrement = 1.0 / Float(fadeSteps)
            
            let fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
                if let currentVolume = self.alarmPlayer?.volume, currentVolume < 1.0 {
                    self.alarmPlayer?.volume = min(1.0, currentVolume + stepIncrement)
                } else {
                    timer.invalidate()
                }
            }
            
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.warning)
            self.hapticGenerator = haptic
            
            let interval = player.duration
            self.alarmTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                self.hapticGenerator?.notificationOccurred(.warning)
            }
        } catch {
            print("Error playing alarm: \(error.localizedDescription)")
            isAlarmActive = false
        }
    }
    
    private func fadeOutAlarm(completion: (() -> Void)? = nil) {
        if let player = alarmPlayer, player.volume > 0.0 {
            alarmTimer?.invalidate()
            alarmTimer = nil
            hapticGenerator = nil
            isAlarmActive = false
            
            let vol = player.volume
            let remaining = Double(vol)
            let fadeDuration = 2.0 * (remaining / 1.0)
            let fadeSteps = 20
            let stepDuration = fadeDuration / Double(fadeSteps)
            let stepDecrement = vol / Float(fadeSteps)
            
            let fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
                if let currentVolume = self.alarmPlayer?.volume, currentVolume > 0.0 {
                    self.alarmPlayer?.volume = max(0.0, currentVolume - stepDecrement)
                } else {
                    timer.invalidate()
                    self.alarmPlayer?.stop()
                    self.alarmPlayer = nil
                    completion?()
                }
            }
        } else {
            alarmPlayer?.stop()
            alarmPlayer = nil
            alarmTimer?.invalidate()
            alarmTimer = nil
            hapticGenerator = nil
            isAlarmActive = false
            completion?()
        }
    }
}

//import SwiftUI
//import AVFoundation
//
//struct ContentView: View {
//    let files: [String] = (1...30).map { String(format: "ambient_%02d", $0) }
//    
//    @Namespace private var animation: Namespace.ID
//    @State private var selectedItem: SelectedItem? = nil
//    @State private var currentPlayer: AVAudioPlayer? = nil
//    @State private var currentTimer: Timer? = nil
//    @State private var currentAudioFile: String? = nil
//    @State private var durationMinutes: Double = UserDefaults.standard.double(forKey: "durationMinutes")
//    @State private var stopTimer: Timer? = nil
//    @State private var alarmPlayer: AVAudioPlayer? = nil
//    @State private var alarmTimer: Timer? = nil
//    @State private var hapticGenerator: UINotificationFeedbackGenerator? = nil
//    @State private var isAlarmActive: Bool = false
//    @State private var backgroundOpacity: Double = UserDefaults.standard.bool(forKey: "hasLaunched") ? 1.0 : 0.0
//    @State private var selectedAlarmIndex: Int? = UserDefaults.standard.object(forKey: "selectedAlarmIndex") as? Int
//    @State private var showingAlarmSelection: Bool = false
//    
//    private func findNextValidIndex(from currentIndex: Int, direction: Int) -> Int? {
//        var newIndex = currentIndex + direction
//        while newIndex >= 0 && newIndex < files.count {
//            if !files[newIndex].isEmpty {
//                return newIndex
//            }
//            newIndex += direction
//        }
//        return nil
//    }
//    
//    private func colorFor(row: Int, col: Int) -> Color {
//        let diag = CGFloat(row + col) / 9.0 // Max sum of row (0-5) + col (0-4) = 9
//        if row <= 1 {
//            // White noise (rows 0-1): Diagonal dark purple gradient
//            let startHue: CGFloat = 0.67 // Dark purple
//            let endHue: CGFloat = 0.75 // Lighter purple
//            let startSaturation: CGFloat = 0.7
//            let endSaturation: CGFloat = 0.5
//            let startBrightness: CGFloat = 0.5 // Darker
//            let endBrightness: CGFloat = 0.7 // Lighter
//            let hue = startHue + (endHue - startHue) * diag
//            let saturation = startSaturation - (startSaturation - endSaturation) * diag
//            let brightness = startBrightness + (endBrightness - startBrightness) * diag
//            return Color(hue: hue, saturation: saturation, brightness: brightness)
//        } else if row <= 3 {
//            // Nighttime music (rows 2-3): Pink/purple/green diagonal gradient
//            let origRow = row - 2
//            let diag = CGFloat(origRow + col) / 6.0 // Max sum of origRow (0-1) + col (0-4) = 5
//            let startHue: CGFloat = 0.8 // Pink
//            let endHue: CGFloat = 0.33 // Green
//            let hue = startHue - (startHue - endHue) * diag
//            let saturation: CGFloat = 0.3
//            let brightness: CGFloat = 0.9
//            return Color(hue: hue, saturation: saturation, brightness: brightness)
//        } else {
//            // Waking audio (rows 4-5): Beige/orange diagonal gradient
//            let origRow = row - 4
//            let diag = CGFloat(origRow + col) / 5.0 // Max sum of origRow (0-1) + col (0-4) = 5
//            let startHue: CGFloat = 0.0 // Light grey
//            let endHue: CGFloat = 0.083 // Muted orange
//            let startSaturation: CGFloat = 0.1 // Light grey
//            let endSaturation: CGFloat = 0.6 // Muted orange
//            let startBrightness: CGFloat = 0.9 // Light grey
//            let endBrightness: CGFloat = 0.7 // Muted orange
//            let hue = startHue + (endHue - startHue) * diag
//            let saturation = startSaturation + (endSaturation - startSaturation) * diag
//            let brightness = startBrightness - (startBrightness - endBrightness) * diag
//            return Color(hue: hue, saturation: saturation, brightness: brightness)
//        }
//    }
//
//    var backgroundGradient: some View {
//        LinearGradient(
//            gradient: Gradient(colors: [
//                Color(white: 0.15),
//                Color(white: 0.30)
//            ]),
//            startPoint: .top,
//            endPoint: .bottom
//        )
//        .opacity(backgroundOpacity)
//        .ignoresSafeArea()
//    }
//    
//    var backgroundColor: some View {
//        Color(white: 0.8)
//            .opacity(1.0 - backgroundOpacity)
//            .ignoresSafeArea()
//    }
//    
//    var roomGrid: some View {
//        GeometryReader { geo in
//            let spacing: CGFloat = 10
//            let padding: CGFloat = 20
//            let availW = geo.size.width - 2 * padding
//            let availH = geo.size.height - 2 * padding
//            let numCols: CGFloat = 5
//            let numRows: CGFloat = 6
//            let itemW = (availW - spacing * (numCols - 1)) / numCols
//            let maxItemH = (availH - spacing * (numRows - 1)) / numRows
//            let itemH = min(itemW, maxItemH)
//            let aspect = itemW / itemH
//            
//            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: 5), spacing: spacing) {
//                ForEach(0..<30) { index in
//                    AlarmItemView(
//                        index: index,
//                        aspect: aspect,
//                        colorFor: colorFor,
//                        files: files,
//                        selectedItem: selectedItem,
//                        animation: animation
//                    ) { selectedIndex in
//                        withAnimation(.easeInOut(duration: 0.3)) {
//                            selectedItem = SelectedItem(id: selectedIndex)
//                        }
//                    }
//                }
//            }
//            .disabled(selectedItem != nil)
//        }
//        .padding(20)
//    }
//    
//    var body: some View {
//        ZStack {
//            if selectedItem == nil {
//                backgroundGradient
//            } else {
//                backgroundColor
//            }
//            
//            if selectedItem == nil {
//                roomGrid
//            }
//            
//            if let item = selectedItem {
//                let index = item.id
//                let row = index / 5
//                let col = index % 5
//                let color = colorFor(row: row, col: col)
//                
//                ExpandingView(
//                    color: color,
//                    dismiss: {
//                        withAnimation(.easeInOut(duration: 0.3)) {
//                            selectedItem = nil
//                        }
//                    },
//                    durationMinutes: $durationMinutes,
//                    isAlarmActive: $isAlarmActive,
//                    changeRoom: { direction in
//                        if let nextIndex = findNextValidIndex(from: index, direction: direction) {
//                            withAnimation(.easeInOut(duration: 0.3)) {
//                                selectedItem = SelectedItem(id: nextIndex)
//                            }
//                        }
//                    },
//                    currentIndex: index,
//                    maxIndex: files.count - 1,
//                    selectAlarm: {
//                        showingAlarmSelection = true
//                    }
//                )
//                .matchedGeometryEffect(id: index, in: animation)
//                .zIndex(1)
//            }
//            
//            if isAlarmActive {
//                ZStack {
//                    Color.black.opacity(0.5)
//                    VStack {
//                        Text("Tap to stop alarm")
//                            .font(.title)
//                            .foregroundColor(.white)
//                    }
//                }
//                .ignoresSafeArea()
//                .onTapGesture {
//                    fadeOutAlarm {
//                        withAnimation(.easeInOut(duration: 0.3)) {
//                            selectedItem = nil
//                        }
//                    }
//                }
//                .zIndex(2)
//            }
//        }
//        .gesture(
//            DragGesture(minimumDistance: 20, coordinateSpace: .global)
//                .onEnded { value in
//                    let translationHeight = value.translation.height
//                    if translationHeight < -50 && selectedItem == nil && !isAlarmActive {
//                        showingAlarmSelection = true
//                    }
//                }
//        )
//        .onAppear {
//            if !UserDefaults.standard.bool(forKey: "hasLaunched") {
//                withAnimation(.easeInOut(duration: 2.0)) {
//                    backgroundOpacity = 1.0
//                }
//                UserDefaults.standard.set(true, forKey: "hasLaunched")
//            }
//        }
//        .onChange(of: selectedItem) { oldValue, newValue in
//            if let old = oldValue, newValue == nil {
//                fadeOutCurrent()
//            } else if let new = newValue {
//                let selectedIndex = new.id
//                fadeOutCurrent {
//                    playAudio(for: selectedIndex)
//                    if durationMinutes > 0 {
//                        stopTimer?.invalidate()
//                        let durationSeconds = durationMinutes * 60
//                        stopTimer = Timer.scheduledTimer(withTimeInterval: durationSeconds, repeats: false) { _ in
//                            if self.selectedAlarmIndex != nil {
//                                self.startAlarm()
//                            } else {
//                                self.fadeOutCurrent {
//                                    UserDefaults.standard.removeObject(forKey: "lastWakeTime")
//                                }
//                            }
//                        }
//                    } else {
//                        stopTimer?.invalidate()
//                        stopTimer = nil
//                    }
//                }
//            }
//        }
//        .onChange(of: durationMinutes) { old, new in
//            UserDefaults.standard.set(new, forKey: "durationMinutes")
//            if let item = selectedItem {
//                if new > 0 {
//                    stopTimer?.invalidate()
//                    let durationSeconds = new * 60
//                    stopTimer = Timer.scheduledTimer(withTimeInterval: durationSeconds, repeats: false) { _ in
//                        if self.selectedAlarmIndex != nil {
//                            self.startAlarm()
//                        } else {
//                            self.fadeOutCurrent {
//                                UserDefaults.standard.removeObject(forKey: "lastWakeTime")
//                            }
//                        }
//                    }
//                    let now = Date()
//                    let newWakeDate = now.addingTimeInterval(new * 60)
//                    UserDefaults.standard.set(newWakeDate, forKey: "lastWakeTime")
//                } else {
//                    stopTimer?.invalidate()
//                    stopTimer = nil
//                    UserDefaults.standard.removeObject(forKey: "lastWakeTime")
//                }
//            }
//        }
//        .onChange(of: selectedAlarmIndex) { _, new in
//            UserDefaults.standard.set(new, forKey: "selectedAlarmIndex")
//        }
//        .sheet(isPresented: $showingAlarmSelection) {
//            AlarmSelectionView(
//                selectedAlarmIndex: $selectedAlarmIndex,
//                files: files,
//                fadeMainTo: { target in
//                    fadeCurrentTo(target: target)
//                }
//            )
//            .presentationDetents([.medium])
//        }
//    }
//    
//    private func playAudio(for index: Int) {
//        let file = files[index]
//        guard let url = Bundle.main.url(forResource: file, withExtension: "mp3") else {
//            print("Audio file not found: \(file).mp3")
//            return
//        }
//        do {
//            currentPlayer = try AVAudioPlayer(contentsOf: url)
//            currentPlayer?.numberOfLoops = -1
//            currentPlayer?.volume = 0.0
//            currentPlayer?.play()
//            
//            let fadeDuration: Double = 2.0
//            let fadeSteps: Int = 20
//            let stepDuration = fadeDuration / Double(fadeSteps)
//            let stepIncrement = 1.0 / Float(fadeSteps)
//            
//            currentTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
//                if let currentVolume = self.currentPlayer?.volume, currentVolume < 1.0 {
//                    self.currentPlayer?.volume = min(1.0, currentVolume + stepIncrement)
//                } else {
//                    self.currentTimer?.invalidate()
//                    self.currentTimer = nil
//                }
//            }
//            currentAudioFile = file
//        } catch {
//            print("Error playing audio: \(error.localizedDescription)")
//        }
//    }
//    
//    private func fadeOutCurrent(completion: (() -> Void)? = nil) {
//        if let player = currentPlayer, player.volume > 0.0 {
//            currentTimer?.invalidate()
//            let vol = player.volume
//            let fadeDuration = 2.0 * Double(vol) / 1.0
//            let fadeSteps = 20
//            let stepDuration = fadeDuration / Double(fadeSteps)
//            let stepDecrement = vol / Float(fadeSteps)
//            
//            currentTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
//                if let currentVolume = self.currentPlayer?.volume, currentVolume > 0.0 {
//                    self.currentPlayer?.volume = max(0.0, currentVolume - stepDecrement)
//                } else {
//                    self.currentTimer?.invalidate()
//                    self.currentTimer = nil
//                    self.currentPlayer?.stop()
//                    self.currentPlayer = nil
//                    self.currentAudioFile = nil
//                    completion?()
//                }
//            }
//        } else {
//            currentPlayer?.stop()
//            currentPlayer = nil
//            currentAudioFile = nil
//            completion?()
//        }
//    }
//    
//    private func fadeCurrentTo(target: Float, duration: Double = 2.0) {
//        guard let player = currentPlayer else { return }
//        currentTimer?.invalidate()
//        let currentVol = player.volume
//        if currentVol == target { return }
//        let direction = target > currentVol ? 1 : -1
//        let remaining = abs(target - currentVol)
//        let fadeDuration = duration * Double(remaining) / 1.0
//        let steps = 20
//        let stepDuration = fadeDuration / Double(steps)
//        let stepChange = Float(remaining) / Float(steps) * Float(direction)
//        currentTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
//            if let vol = self.currentPlayer?.volume {
//                let newVol = vol + stepChange
//                if (direction > 0 && newVol > target) || (direction < 0 && newVol < target) {
//                    self.currentPlayer?.volume = target
//                    self.currentTimer?.invalidate()
//                    self.currentTimer = nil
//                } else {
//                    self.currentPlayer?.volume = newVol
//                }
//            } else {
//                self.currentTimer?.invalidate()
//                self.currentTimer = nil
//            }
//        }
//    }
//    
//    private func startAlarm() {
//        if alarmPlayer != nil {
//            return
//        }
//        
//        stopTimer?.invalidate()
//        stopTimer = nil
//        isAlarmActive = true
//        
//        guard let idx = selectedAlarmIndex,
//              idx >= 0 && idx < files.count,
//              !files[idx].isEmpty else {
//            return
//        }
//        
//        let alarmFile = files[idx]
//        guard let url = Bundle.main.url(forResource: alarmFile, withExtension: "mp3") else {
//            print("Alarm audio file not found: \(alarmFile).mp3")
//            return
//        }
//        
//        fadeOutCurrent()
//        UserDefaults.standard.removeObject(forKey: "lastWakeTime")
//        
//        do {
//            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
//            try AVAudioSession.sharedInstance().setActive(true)
//            
//            let player = try AVAudioPlayer(contentsOf: url)
//            player.numberOfLoops = -1
//            player.volume = 0.0
//            player.play()
//            self.alarmPlayer = player
//            
//            let fadeDuration: Double = 0.5
//            let fadeSteps: Int = 10
//            let stepDuration = fadeDuration / Double(fadeSteps)
//            let stepIncrement = 1.0 / Float(fadeSteps)
//            
//            let fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
//                if let currentVolume = self.alarmPlayer?.volume, currentVolume < 1.0 {
//                    self.alarmPlayer?.volume = min(1.0, currentVolume + stepIncrement)
//                } else {
//                    timer.invalidate()
//                }
//            }
//            
//            let haptic = UINotificationFeedbackGenerator()
//            haptic.notificationOccurred(.warning)
//            self.hapticGenerator = haptic
//            
//            let interval = player.duration
//            self.alarmTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
//                self.hapticGenerator?.notificationOccurred(.warning)
//            }
//        } catch {
//            print("Error playing alarm: \(error.localizedDescription)")
//        }
//    }
//    
//    private func fadeOutAlarm(completion: (() -> Void)? = nil) {
//        if let player = alarmPlayer, player.volume > 0.0 {
//            alarmTimer?.invalidate()
//            alarmTimer = nil
//            hapticGenerator = nil
//            isAlarmActive = false
//            
//            let vol = player.volume
//            let remaining = Double(vol)
//            let fadeDuration = 2.0 * (remaining / 1.0)
//            let fadeSteps = 20
//            let stepDuration = fadeDuration / Double(fadeSteps)
//            let stepDecrement = vol / Float(fadeSteps)
//            
//            let fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
//                if let currentVolume = self.alarmPlayer?.volume, currentVolume > 0.0 {
//                    self.alarmPlayer?.volume = max(0.0, currentVolume - stepDecrement)
//                } else {
//                    timer.invalidate()
//                    self.alarmPlayer?.stop()
//                    self.alarmPlayer = nil
//                    completion?()
//                }
//            }
//        } else {
//            alarmPlayer?.stop()
//            alarmPlayer = nil
//            alarmTimer?.invalidate()
//            alarmTimer = nil
//            hapticGenerator = nil
//            isAlarmActive = false
//            completion?()
//        }
//    }
//}
