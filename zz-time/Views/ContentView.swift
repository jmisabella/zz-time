import SwiftUI
import AVFoundation

struct ContentView: View {
    let files: [String] = (1...30).map { String(format: "ambient-%02d", $0) }
    
    private func colorFor(row: Int, col: Int) -> Color {
        if row == 0 {
            let hue: CGFloat = 0.67 // Blue hue
            let saturation: CGFloat = 0.6
            let diag = CGFloat(col) / 4.0
            let startBright: CGFloat = 0.6 // starts darkish blue
            let endBright: CGFloat = 0.8 // ends lighter blue
            let brightness = startBright + (endBright - startBright) * diag
            return Color(hue: hue, saturation: saturation, brightness: brightness)
        } else {
            let origRow = row - 1
            let diag = CGFloat(origRow + col) / 8.0
            let startHue: CGFloat = 0.8
            let endHue: CGFloat = 0.33
            let hue = startHue - (startHue - endHue) * diag
            let saturation: CGFloat = 0.3
            let brightness: CGFloat = 0.9
            return Color(hue: hue, saturation: saturation, brightness: brightness)
        }
    }
    
    @Namespace private var animation: Namespace.ID
    @State private var selectedItem: SelectedItem? = nil
    @State private var currentPlayer: AVAudioPlayer? = nil
    @State private var currentTimer: Timer? = nil
    @State private var currentAudioFile: String? = nil
    @State private var durationMinutes: Double = UserDefaults.standard.double(forKey: "durationMinutes")
    @State private var isAlarmEnabled: Bool = UserDefaults.standard.bool(forKey: "isAlarmEnabled")
    @State private var stopTimer: Timer? = nil
    @State private var alarmPlayer: AVAudioPlayer? = nil
    @State private var alarmTimer: Timer? = nil
    @State private var hapticGenerator: UINotificationFeedbackGenerator? = nil
    @State private var isAlarmActive: Bool = false
    @State private var backgroundOpacity: Double = UserDefaults.standard.bool(forKey: "hasLaunched") ? 1.0 : 0.0
    
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
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(white: 0.45),
                    Color(white: 0.35)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(backgroundOpacity)
            .ignoresSafeArea()
            
            Color(white: 0.8)
                .opacity(1.0 - backgroundOpacity)
                .ignoresSafeArea()
            
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
                        let row = index / 5
                        let col = index % 5
                        let color = colorFor(row: row, col: col)
                        let file = index < files.count ? files[index] : ""
                        
                        Button(action: {
                            if !file.isEmpty {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedItem = SelectedItem(id: index)
                                }
                            }
                        }) {
                            Rectangle()
                                .fill(color)
                                .aspectRatio(aspect, contentMode: .fit)
                                .cornerRadius(8)
                        }
                        .matchedGeometryEffect(id: index, in: animation)
                        .opacity(selectedItem?.id == index ? 0 : 1)
                        .disabled(file.isEmpty)
                    }
                }
                .disabled(selectedItem != nil)
            }
            .padding(20)
            
            if let selected = selectedItem {
                let row = selected.id / 5
                let col = selected.id % 5
                let color = colorFor(row: row, col: col)
                
                ExpandingView(
                    color: color,
                    dismiss: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedItem = nil
                            isAlarmActive = false
                        }
                    },
                    durationMinutes: $durationMinutes,
                    isAlarmActive: $isAlarmActive,
                    isAlarmEnabled: $isAlarmEnabled,
                    changeRoom: { direction in
                        if let newIndex = findNextValidIndex(from: selected.id, direction: direction) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedItem = SelectedItem(id: newIndex)
                            }
                        }
                    },
                    currentIndex: selected.id,
                    maxIndex: files.count
                )
                .matchedGeometryEffect(id: selected.id, in: animation)
            }
        }
        .onAppear {
            if !UserDefaults.standard.bool(forKey: "hasLaunched") {
                withAnimation(.easeInOut(duration: 1.0)) {
                    backgroundOpacity = 1.0
                }
                UserDefaults.standard.set(true, forKey: "hasLaunched")
            }
            if durationMinutes == 0 {
                isAlarmEnabled = false
                UserDefaults.standard.set(false, forKey: "isAlarmEnabled")
            }
        }
        .onChange(of: selectedItem) { _, newValue in
            if newValue == nil {
                // No need to set backgroundOpacity here; it's already 1.0
            }
            if let new = newValue {
                let file = files[new.id]
                if !file.isEmpty {
                    if let currFile = currentAudioFile, currFile == file {
                        currentTimer?.invalidate()
                        if let vol = currentPlayer?.volume, vol < 1.0 {
                            let remaining = 1.0 - Double(vol)
                            let fadeDuration = 2.0 * (remaining / 1.0)
                            let fadeSteps = 20
                            let stepDuration = fadeDuration / Double(fadeSteps)
                            let stepIncrement = Float(remaining) / Float(fadeSteps)
                            currentTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
                                if let currentVolume = self.currentPlayer?.volume, currentVolume < 1.0 {
                                    self.currentPlayer?.volume = min(1.0, currentVolume + stepIncrement)
                                } else {
                                    self.currentTimer?.invalidate()
                                    self.currentTimer = nil
                                }
                            }
                        }
                    } else {
                        fadeOutCurrent {
                            setupNewAudio(file: file)
                        }
                    }
                }
            } else {
                fadeOutCurrent()
                fadeOutAlarm()
                stopTimer?.invalidate()
                stopTimer = nil
                isAlarmActive = false
            }
        }
        .onChange(of: durationMinutes) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "durationMinutes")
            if newValue == 0 {
                isAlarmEnabled = false
                UserDefaults.standard.set(false, forKey: "isAlarmEnabled")
            }
            if let _ = selectedItem {
                stopTimer?.invalidate()
                stopTimer = nil
                if newValue > 0 {
                    let seconds = newValue * 60
                    stopTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
                        self.fadeOutCurrent {
                            if self.isAlarmEnabled {
                                self.startAlarm()
                            }
                        }
                    }
                }
            }
        }
    }
    
//    var body: some View {
//        ZStack {
//            LinearGradient(
//                gradient: Gradient(colors: [
//                    Color(white: 0.45),
//                    Color(white: 0.35)
//                ]),
//                startPoint: .top,
//                endPoint: .bottom
//            )
//            .opacity(backgroundOpacity)
//            .ignoresSafeArea()
//            
//            Color(white: 0.8)
//                .opacity(1.0 - backgroundOpacity)
//                .ignoresSafeArea()
//            
//            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
//                ForEach(0..<30) { index in
//                    let row = index / 5
//                    let col = index % 5
//                    let color = colorFor(row: row, col: col)
//                    let file = index < files.count ? files[index] : ""
//                    
//                    Button(action: {
//                        if !file.isEmpty {
//                            withAnimation(.easeInOut(duration: 0.3)) {
//                                selectedItem = SelectedItem(id: index)
//                            }
//                        }
//                    }) {
//                        Rectangle()
//                            .fill(color)
//                            .aspectRatio(1, contentMode: .fit)
//                            .cornerRadius(8)
//                    }
//                    .matchedGeometryEffect(id: index, in: animation)
//                    .opacity(selectedItem?.id == index ? 0 : 1)
//                    .disabled(file.isEmpty)
//                }
//            }
//            .padding(20)
//            .disabled(selectedItem != nil)
//            
//            if let selected = selectedItem {
//                let row = selected.id / 5
//                let col = selected.id % 5
//                let color = colorFor(row: row, col: col)
//                
//                ExpandingView(
//                    color: color,
//                    dismiss: {
//                        withAnimation(.easeInOut(duration: 0.3)) {
//                            selectedItem = nil
//                            isAlarmActive = false
//                        }
//                    },
//                    durationMinutes: $durationMinutes,
//                    isAlarmActive: $isAlarmActive,
//                    isAlarmEnabled: $isAlarmEnabled,
//                    changeRoom: { direction in
//                        if let newIndex = findNextValidIndex(from: selected.id, direction: direction) {
//                            withAnimation(.easeInOut(duration: 0.3)) {
//                                selectedItem = SelectedItem(id: newIndex)
//                            }
//                        }
//                    },
//                    currentIndex: selected.id,
//                    maxIndex: files.count
//                )
//                .matchedGeometryEffect(id: selected.id, in: animation)
//            }
//        }
//        .onAppear {
//            if !UserDefaults.standard.bool(forKey: "hasLaunched") {
//                withAnimation(.easeInOut(duration: 1.0)) {
//                    backgroundOpacity = 1.0
//                }
//                UserDefaults.standard.set(true, forKey: "hasLaunched")
//            }
//            if durationMinutes == 0 {
//                isAlarmEnabled = false
//                UserDefaults.standard.set(false, forKey: "isAlarmEnabled")
//            }
//        }
//        .onChange(of: selectedItem) { _, newValue in
//            if newValue == nil {
//                // No need to set backgroundOpacity here; it's already 1.0
//            }
//            if let new = newValue {
//                let file = files[new.id]
//                if !file.isEmpty {
//                    if let currFile = currentAudioFile, currFile == file {
//                        currentTimer?.invalidate()
//                        if let vol = currentPlayer?.volume, vol < 1.0 {
//                            let remaining = 1.0 - Double(vol)
//                            let fadeDuration = 2.0 * (remaining / 1.0)
//                            let fadeSteps = 20
//                            let stepDuration = fadeDuration / Double(fadeSteps)
//                            let stepIncrement = Float(remaining) / Float(fadeSteps)
//                            currentTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
//                                if let currentVolume = self.currentPlayer?.volume, currentVolume < 1.0 {
//                                    self.currentPlayer?.volume = min(1.0, currentVolume + stepIncrement)
//                                } else {
//                                    self.currentTimer?.invalidate()
//                                    self.currentTimer = nil
//                                }
//                            }
//                        }
//                    } else {
//                        fadeOutCurrent {
//                            setupNewAudio(file: file)
//                        }
//                    }
//                }
//            } else {
//                fadeOutCurrent()
//                fadeOutAlarm()
//                stopTimer?.invalidate()
//                stopTimer = nil
//                isAlarmActive = false
//            }
//        }
//        .onChange(of: durationMinutes) { _, newValue in
//            UserDefaults.standard.set(newValue, forKey: "durationMinutes")
//            if newValue == 0 {
//                isAlarmEnabled = false
//                UserDefaults.standard.set(false, forKey: "isAlarmEnabled")
//            }
//            if let _ = selectedItem {
//                stopTimer?.invalidate()
//                stopTimer = nil
//                if newValue > 0 {
//                    let seconds = newValue * 60
//                    stopTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
//                        self.fadeOutCurrent {
//                            if self.isAlarmEnabled {
//                                self.startAlarm()
//                            }
//                        }
//                    }
//                }
//            }
//        }
//    }
    
    private func setupNewAudio(file: String) {
        guard let url = Bundle.main.url(forResource: file, withExtension: "mp3") else {
            print("Audio file not found: \(file).mp3")
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            currentPlayer = try AVAudioPlayer(contentsOf: url)
            currentPlayer?.numberOfLoops = -1
            currentPlayer?.volume = 0.0
            currentPlayer?.play()
            currentAudioFile = file
            
            currentTimer?.invalidate()
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
            
            if durationMinutes > 0 {
                let seconds = durationMinutes * 60
                stopTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
                    self.fadeOutCurrent {
                        if self.isAlarmEnabled {
                            self.startAlarm()
                        }
                    }
                }
            }
        } catch {
            print("Error playing audio: \(error.localizedDescription)")
        }
    }
    
    private func fadeOutCurrent(completion: (() -> Void)? = nil) {
        if let player = currentPlayer, player.volume > 0.0 {
            currentTimer?.invalidate()
            let vol = player.volume
            let remaining = Double(vol)
            let fadeDuration = 2.0 * (remaining / 1.0)
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
    
    private func startAlarm() {
        if alarmPlayer != nil {
            return
        }
        
        stopTimer?.invalidate()
        stopTimer = nil
        isAlarmActive = true
        
        guard let url = Bundle.main.url(forResource: "alarm-01", withExtension: "mp3") else {
            print("Alarm audio file not found: alarm-01.mp3")
            return
        }
        
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

//
//import SwiftUI
//import AVFoundation
//
//struct ContentView: View {
//    let files: [String] = (1...25).map { String(format: "ambient-%02d", $0) } + Array(repeating: "", count: 7)
//    
//    private func colorFor(row: Int, col: Int) -> Color {
//        let diag = CGFloat(row + col) / 8.0
//        let startHue: CGFloat = 0.8
//        let endHue: CGFloat = 0.33
//        let hue = startHue - (startHue - endHue) * diag
//        let saturation: CGFloat = 0.3
//        let brightness: CGFloat = 0.9
//        return Color(hue: hue, saturation: saturation, brightness: brightness)
//    }
//    
//    @Namespace private var animation: Namespace.ID
//    @State private var selectedItem: SelectedItem? = nil
//    @State private var currentPlayer: AVAudioPlayer? = nil
//    @State private var currentTimer: Timer? = nil
//    @State private var currentAudioFile: String? = nil
//    @State private var durationMinutes: Double = UserDefaults.standard.double(forKey: "durationMinutes")
//    @State private var isAlarmEnabled: Bool = UserDefaults.standard.bool(forKey: "isAlarmEnabled")
//    @State private var stopTimer: Timer? = nil
//    @State private var alarmPlayer: AVAudioPlayer? = nil
//    @State private var alarmTimer: Timer? = nil
//    @State private var hapticGenerator: UINotificationFeedbackGenerator? = nil
//    @State private var isAlarmActive: Bool = false
//    @State private var backgroundOpacity: Double = UserDefaults.standard.bool(forKey: "hasLaunched") ? 1.0 : 0.0
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
//    var body: some View {
//        ZStack {
//            LinearGradient(
//                gradient: Gradient(colors: [
//                    Color(white: 0.45),
//                    Color(white: 0.35)
//                ]),
//                startPoint: .top,
//                endPoint: .bottom
//            )
//            .opacity(backgroundOpacity)
//            .ignoresSafeArea()
//            
//            Color(white: 0.8)
//                .opacity(1.0 - backgroundOpacity)
//                .ignoresSafeArea()
//            
//            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
//                ForEach(0..<25) { index in
//                    let row = index / 5
//                    let col = index % 5
//                    let color = colorFor(row: row, col: col)
//                    let file = index < files.count ? files[index] : ""
//                    
//                    Button(action: {
//                        if !file.isEmpty {
//                            withAnimation(.easeInOut(duration: 0.3)) {
//                                selectedItem = SelectedItem(id: index)
//                            }
//                        }
//                    }) {
//                        Rectangle()
//                            .fill(color)
//                            .aspectRatio(1, contentMode: .fit)
//                            .cornerRadius(8)
//                    }
//                    .matchedGeometryEffect(id: index, in: animation)
//                    .opacity(selectedItem?.id == index ? 0 : 1)
//                    .disabled(file.isEmpty)
//                }
//            }
//            .padding(20)
//            .disabled(selectedItem != nil)
//            
//            if let selected = selectedItem {
//                let row = selected.id / 5
//                let col = selected.id % 5
//                let color = colorFor(row: row, col: col)
//                
//                ExpandingView(
//                    color: color,
//                    dismiss: {
//                        withAnimation(.easeInOut(duration: 0.3)) {
//                            selectedItem = nil
//                            isAlarmActive = false
//                        }
//                    },
//                    durationMinutes: $durationMinutes,
//                    isAlarmActive: $isAlarmActive,
//                    isAlarmEnabled: $isAlarmEnabled,
//                    changeRoom: { direction in
//                        if let newIndex = findNextValidIndex(from: selected.id, direction: direction) {
//                            withAnimation(.easeInOut(duration: 0.3)) {
//                                selectedItem = SelectedItem(id: newIndex)
//                            }
//                        }
//                    },
//                    currentIndex: selected.id,
//                    maxIndex: files.count
//                )
//                .matchedGeometryEffect(id: selected.id, in: animation)
//            }
//        }
//        .onAppear {
//            if !UserDefaults.standard.bool(forKey: "hasLaunched") {
//                withAnimation(.easeInOut(duration: 1.0)) {
//                    backgroundOpacity = 1.0
//                }
//                UserDefaults.standard.set(true, forKey: "hasLaunched")
//            }
//            if durationMinutes == 0 {
//                isAlarmEnabled = false
//                UserDefaults.standard.set(false, forKey: "isAlarmEnabled")
//            }
//        }
//        .onChange(of: selectedItem) { _, newValue in
//            if newValue == nil {
//                // No need to set backgroundOpacity here; it's already 1.0
//            }
//            if let new = newValue {
//                let file = files[new.id]
//                if !file.isEmpty {
//                    if let currFile = currentAudioFile, currFile == file {
//                        currentTimer?.invalidate()
//                        if let vol = currentPlayer?.volume, vol < 1.0 {
//                            let remaining = 1.0 - Double(vol)
//                            let fadeDuration = 2.0 * (remaining / 1.0)
//                            let fadeSteps = 20
//                            let stepDuration = fadeDuration / Double(fadeSteps)
//                            let stepIncrement = Float(remaining) / Float(fadeSteps)
//                            currentTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
//                                if let currentVolume = self.currentPlayer?.volume, currentVolume < 1.0 {
//                                    self.currentPlayer?.volume = min(1.0, currentVolume + stepIncrement)
//                                } else {
//                                    self.currentTimer?.invalidate()
//                                    self.currentTimer = nil
//                                }
//                            }
//                        }
//                    } else {
//                        fadeOutCurrent {
//                            setupNewAudio(file: file)
//                        }
//                    }
//                }
//            } else {
//                fadeOutCurrent()
//                fadeOutAlarm()
//                stopTimer?.invalidate()
//                stopTimer = nil
//                isAlarmActive = false
//            }
//        }
//        .onChange(of: durationMinutes) { _, newValue in
//            UserDefaults.standard.set(newValue, forKey: "durationMinutes")
//            if newValue == 0 {
//                isAlarmEnabled = false
//                UserDefaults.standard.set(false, forKey: "isAlarmEnabled")
//            }
//            if let _ = selectedItem {
//                stopTimer?.invalidate()
//                stopTimer = nil
//                if newValue > 0 {
//                    let seconds = newValue * 60
//                    stopTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
//                        self.fadeOutCurrent {
//                            if self.isAlarmEnabled {
//                                self.startAlarm()
//                            }
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    private func setupNewAudio(file: String) {
//        guard let url = Bundle.main.url(forResource: file, withExtension: "mp3") else {
//            print("Audio file not found: \(file).mp3")
//            return
//        }
//        do {
//            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
//            try AVAudioSession.sharedInstance().setActive(true)
//            
//            currentPlayer = try AVAudioPlayer(contentsOf: url)
//            currentPlayer?.numberOfLoops = -1
//            currentPlayer?.volume = 0.0
//            currentPlayer?.play()
//            currentAudioFile = file
//            
//            currentTimer?.invalidate()
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
//            
//            if durationMinutes > 0 {
//                let seconds = durationMinutes * 60
//                stopTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
//                    self.fadeOutCurrent {
//                        if self.isAlarmEnabled {
//                            self.startAlarm()
//                        }
//                    }
//                }
//            }
//        } catch {
//            print("Error playing audio: \(error.localizedDescription)")
//        }
//    }
//    
//    private func fadeOutCurrent(completion: (() -> Void)? = nil) {
//        if let player = currentPlayer, player.volume > 0.0 {
//            currentTimer?.invalidate()
//            let vol = player.volume
//            let remaining = Double(vol)
//            let fadeDuration = 2.0 * (remaining / 1.0)
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
//    private func startAlarm() {
//        if alarmPlayer != nil {
//            return
//        }
//        
//        stopTimer?.invalidate()
//        stopTimer = nil
//        isAlarmActive = true
//        
//        guard let url = Bundle.main.url(forResource: "alarm-01", withExtension: "mp3") else {
//            print("Alarm audio file not found: alarm-01.mp3")
//            return
//        }
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
