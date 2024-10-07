import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var noteText = ""
    @State private var savedNotes: [Note] = []
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    
    var body: some View {
        VStack {
            TextField("Enter your note", text: $noteText, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            HStack {
                Button(action: saveNote) {
                    Text("Save Note")
                }
                
                Button(action: toggleRecording) {
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                }
                .foregroundColor(isRecording ? .red : .blue)
            }
            .padding()
            
            List(savedNotes) { note in
                if note.isVoiceNote {
                    Button(action: {
                        if let url = note.content as? URL {
                            playVoiceNote(url: url)
                        }
                    }) {
                        Text("Voice Note: \((note.content as? URL)?.lastPathComponent ?? "")")
                    }
                } else {
                    Text(note.content as? String ?? "")
                }
            }
        }
        .onAppear(perform: loadNotes)
    }
    
    func saveNote() {
        if !noteText.isEmpty {
            savedNotes.append(Note(content: noteText, isVoiceNote: false))
            noteText = ""
            saveNotesToUserDefaults()
        }
    }
    
    func loadNotes() {
        if let loadedNotes = UserDefaults.standard.array(forKey: "SavedNotes") as? [[String: Any]] {
            savedNotes = loadedNotes.compactMap { dict in
                guard let content = dict["content"] as? String,
                      let isVoiceNote = dict["isVoiceNote"] as? Bool else {
                    return nil
                }
                return Note(content: isVoiceNote ? URL(fileURLWithPath: content) : content,
                            isVoiceNote: isVoiceNote)
            }
        }
    }
    
    func saveNotesToUserDefaults() {
        let notesToSave = savedNotes.map { note -> [String: Any] in
            ["content": note.isVoiceNote ? (note.content as? URL)?.path ?? "" : (note.content as? String ?? ""),
             "isVoiceNote": note.isVoiceNote]
        }
        UserDefaults.standard.set(notesToSave, forKey: "SavedNotes")
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("recording-\(Date().timeIntervalSince1970).m4a")
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            
            isRecording = true
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        if let recorder = audioRecorder {
            savedNotes.append(Note(content: recorder.url, isVoiceNote: true))
            saveNotesToUserDefaults()
        }
    }
    
    func playVoiceNote(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Failed to play voice note: \(error.localizedDescription)")
        }
    }
}

struct Note: Identifiable {
    let id = UUID()
    let content: Any
    let isVoiceNote: Bool
}

#Preview {
    ContentView()
}
