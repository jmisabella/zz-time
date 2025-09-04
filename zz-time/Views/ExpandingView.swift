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
    
    var body: some View {
        ZStack {
            ZStack {
                BreathingBackground(color: color)
                    .ignoresSafeArea()
                
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
                    maxValue: 480,
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
                
                HStack(spacing: 40) {
                    Button {
                        print("Sun button tapped, triggering flash and setting dim duration to \(defaultDimDurationMinutes) minutes")
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
                        print("Moon button tapped, setting dim duration to 4 seconds")
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
                        if translationHeight > 100 {
                            print("Downward swipe detected")
                            withAnimation(.easeInOut(duration: 0.3)) {
                                dismiss()
                            }
                        } else if translationWidth < -50 {
                            print("Left swipe detected, moving to next room")
                            changeRoom(1)
                            roomChangeTrigger.toggle()
                        } else if translationWidth > 50 {
                            print("Right swipe detected, moving to previous room")
                            changeRoom(-1)
                            roomChangeTrigger.toggle()
                        }
                    }
            )
        )
        .onAppear {
            dimMode = .duration(defaultDimDurationSeconds)
            if case .duration(let seconds) = dimMode {
                print("ExpandingView appeared with dim duration: \(seconds) seconds")
                flashOverlayOpacity = 0
                withAnimation(.linear(duration: seconds)) {
                    dimOverlayOpacity = 1
                }
            }
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
    }
}

//import SwiftUI
//
//struct ExpandingView: View {
//    // Centralized dimming duration in minutes
//    private let defaultDimDurationMinutes: Double = 3
//    
//    // Computed property to convert minutes to seconds
//    private var defaultDimDurationSeconds: Double {
//        defaultDimDurationMinutes * 60
//    }
//    
//    let color: Color
//    let dismiss: () -> Void
//    @Binding var durationMinutes: Double
//    @Binding var isAlarmActive: Bool
//    @Binding var isAlarmEnabled: Bool
//    let changeRoom: (Int) -> Void
//    let currentIndex: Int
//    let maxIndex: Int
//    let selectAlarm: () -> Void
//    
//    @State private var showLabel: Bool = false
//    @State private var dimOverlayOpacity: Double = 0.0
//    @State private var flashOverlayOpacity: Double = 0.0
//    @State private var dimMode: DimMode = .duration(0) // Will be set in onAppear
//    @State private var roomChangeTrigger: Bool = false
//    
//    var body: some View {
//        ZStack {
//            ZStack {
//                BreathingBackground(color: color)
//                    .ignoresSafeArea()
//                
//                Rectangle()
//                    .fill(isAlarmActive ? Color(hue: 0.58, saturation: 0.3, brightness: 0.9) : .black)
//                    .opacity(dimOverlayOpacity)
//                    .ignoresSafeArea()
//                
//                Rectangle()
//                    .fill(Color.white)
//                    .opacity(flashOverlayOpacity)
//                    .ignoresSafeArea()
//            }
//            
//            VStack {
//                CustomSlider(
//                    value: $durationMinutes,
//                    minValue: 0,
//                    maxValue: 480,
//                    step: 1,
//                    onEditingChanged: { editing in
//                        showLabel = editing
//                    }
//                )
//                .padding(.horizontal, 40)
//                
//                if showLabel {
//                    let text: String = {
//                        if durationMinutes == 0 {
//                            return "infinite"
//                        } else if durationMinutes < 60 {
//                            let minutes = Int(durationMinutes)
//                            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
//                        } else {
//                            let hours = Int(durationMinutes / 60)
//                            let minutes = Int(durationMinutes.truncatingRemainder(dividingBy: 60))
//                            if minutes == 0 {
//                                return "\(hours) hour\(hours == 1 ? "" : "s")"
//                            } else {
//                                return "\(hours) hour\(hours == 1 ? "" : "s"), \(minutes) minute\(minutes == 1 ? "" : "s")"
//                            }
//                        }
//                    }()
//                    
//                    Text(text)
//                        .font(.title)
//                        .foregroundColor(.white)
//                        .padding()
//                        .background(Color.black.opacity(0.5))
//                        .cornerRadius(8)
//                }
//                
//                Spacer()
//                
//                HStack(spacing: 40) {
//                    Button {
//                        print("Sun button tapped, triggering flash and setting dim duration to \(defaultDimDurationMinutes) minutes")
//                        dimMode = .duration(defaultDimDurationSeconds)
//                        dimOverlayOpacity = 0
//                        flashOverlayOpacity = 0.8
//                        withAnimation(.linear(duration: 0.5)) {
//                            flashOverlayOpacity = 0
//                        }
//                        withAnimation(.linear(duration: defaultDimDurationSeconds)) {
//                            dimOverlayOpacity = 1
//                        }
//                    } label: {
//                        Image(systemName: "sun.max.fill")
//                            .font(.title)
//                            .foregroundColor(Color(white: 0.7))
//                            .padding(10)
//                            .background(Circle().fill(Color.black.opacity(0.5)))
//                    }
//                    .contentShape(Circle())
//                    
//                    Button {
//                        print("Moon button tapped, setting dim duration to 4 seconds")
//                        dimMode = .duration(4)
//                        dimOverlayOpacity = 0
//                        flashOverlayOpacity = 0
//                        withAnimation(.linear(duration: 4)) {
//                            dimOverlayOpacity = 1
//                        }
//                    } label: {
//                        Image(systemName: "moon.fill")
//                            .font(.title)
//                            .foregroundColor(Color(white: 0.7))
//                            .padding(10)
//                            .background(Circle().fill(Color.black.opacity(0.5)))
//                    }
//                    .contentShape(Circle())
//                    
//                    Button {
//                        if durationMinutes > 0 {
//                            isAlarmEnabled.toggle()
//                            UserDefaults.standard.set(isAlarmEnabled, forKey: "isAlarmEnabled")
//                        }
//                    } label: {
//                        Image(systemName: isAlarmEnabled ? "bell.fill" : "bell.slash.fill")
//                            .font(.title)
//                            .foregroundColor(Color(white: 0.7))
//                            .padding(10)
//                            .background(Circle().fill(Color.black.opacity(0.5)))
//                    }
//                    .contentShape(Circle())
//                    .disabled(durationMinutes == 0)
//                    .opacity(durationMinutes == 0 ? 0.5 : 1.0)
//                    
//                    if isAlarmEnabled && durationMinutes > 0 {
//                        Button {
//                            selectAlarm()
//                        } label: {
//                            Image(systemName: "gearshape.fill")
//                                .font(.title)
//                                .foregroundColor(Color(white: 0.7))
//                                .padding(10)
//                                .background(Circle().fill(Color.black.opacity(0.5)))
//                        }
//                        .contentShape(Circle())
//                    }
//                }
//                .padding(.bottom, 40)
//            }
//        }
//        .gesture(
//            SimultaneousGesture(
//                TapGesture()
//                    .onEnded { _ in
//                        print("Background tapped")
//                        withAnimation(.easeInOut(duration: 0.3)) {
//                            dismiss()
//                        }
//                    },
//                DragGesture(minimumDistance: 20, coordinateSpace: .global)
//                    .onEnded { value in
//                        let translationHeight = value.translation.height
//                        let translationWidth = value.translation.width
//                        if translationHeight > 100 {
//                            print("Downward swipe detected")
//                            withAnimation(.easeInOut(duration: 0.3)) {
//                                dismiss()
//                            }
//                        } else if translationWidth < -50 {
//                            print("Left swipe detected, moving to next room")
//                            changeRoom(1)
//                            roomChangeTrigger.toggle()
//                        } else if translationWidth > 50 {
//                            print("Right swipe detected, moving to previous room")
//                            changeRoom(-1)
//                            roomChangeTrigger.toggle()
//                        }
//                    }
//            )
//        )
//        .onAppear {
//            dimMode = .duration(defaultDimDurationSeconds)
//            if case .duration(let seconds) = dimMode {
//                print("ExpandingView appeared with dim duration: \(seconds) seconds")
//                flashOverlayOpacity = 0
//                withAnimation(.linear(duration: seconds)) {
//                    dimOverlayOpacity = 1
//                }
//            }
//        }
//        .onChange(of: isAlarmActive) { _, newValue in
//            if newValue {
//                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
//                    dimOverlayOpacity = 0.8
//                }
//            } else {
//                withAnimation(.none) {
//                    dimOverlayOpacity = 0
//                }
//                if case .duration(let seconds) = dimMode {
//                    withAnimation(.linear(duration: seconds)) {
//                        dimOverlayOpacity = 1
//                    }
//                }
//            }
//        }
//        .onChange(of: roomChangeTrigger) { _, _ in
//            flashOverlayOpacity = 0.8
//            dimOverlayOpacity = 0
//            withAnimation(.linear(duration: 0.5)) {
//                flashOverlayOpacity = 0
//            }
//            if case .duration(let seconds) = dimMode {
//                withAnimation(.linear(duration: seconds)) {
//                    dimOverlayOpacity = 1
//                }
//            }
//        }
//    }
//}
