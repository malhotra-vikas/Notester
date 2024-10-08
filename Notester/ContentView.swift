import SwiftUI
import AVFoundation
import GoogleSignIn

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var noteText = ""
    @State private var savedNotes: [Note] = []
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var showingVeraView = false
    @State private var isVerifying = false
    @State private var showVerificationAlert = false
    @State private var verificationMessage = ""
    @State private var verificationURL = ""
    @Binding var shouldRefresh: Bool
    
    let userDefaults = UserDefaults(suiteName: "group.com.mconsultants.Notester")
    
    var body: some View {
        Group {
            if authManager.isSignedIn {
                mainView
            } else {
                signInView
            }
        }
        .alert(isPresented: Binding<Bool>(
            get: { authManager.errorMessage != nil },
            set: { _ in authManager.errorMessage = nil }
        )) {
            Alert(title: Text("Error"), message: Text(authManager.errorMessage ?? "Unknown error"), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showingVeraView) {
            VeraView(url: verificationURL, emailLoggedIn: authManager.userEmail ?? "")
        }
    }
    
    var signInView: some View {
        VStack {
            Text("Welcome to Notester")
                .font(.largeTitle)
                .padding()
            
            Button("Sign in with Google") {
                authManager.signIn()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
    
    var mainView: some View {
        VStack {
            HStack {
                Text("Welcome, \(authManager.userEmail ?? "")")
                Spacer()
                Button("Sign Out") {
                    authManager.signOut()
                    savedNotes.removeAll()
                }
            }
            .padding()
            
            HStack {
                TextField("Enter your note", text: $noteText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: clearNoteText) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .disabled(noteText.isEmpty)
            }
            .padding()
            
            HStack {
                Button(action: saveNote) {
                    Text("Save Note")
                }
                
                Button(action: toggleRecording) {
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                }
                .foregroundColor(isRecording ? .red : .blue)
                
                Button(action: verifyNote) {
                    Text("Verify")
                }
                .foregroundColor(.green)
                .disabled(isVerifying)
            }
            .padding()
            
            if isVerifying {
                ProgressView("Verifying...")
            }
            
            List {
                ForEach(savedNotes) { note in
                    VStack(alignment: .leading, spacing: 5) {
                        if note.isVoiceNote {
                            Button(action: {
                                if let url = note.content as? URL {
                                    playVoiceNote(url: url)
                                }
                            }) {
                                Text("Voice Note: \((note.content as? URL)?.lastPathComponent ?? "")")
                            }
                        } else {
                            Text(decodeURLString(note.content as? String ?? ""))
                        }
                        if let sourceURL = note.sourceURL, let url = URL(string: sourceURL) {
                            Link("Source", destination: url)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteNote(note)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            verifyNote(note)
                        } label: {
                            Label("Verify", systemImage: "checkmark.seal")
                        }
                        .tint(.green)
                    }
                }
            }
        }
        .onAppear(perform: loadNotes)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            loadNotes()
        }
        .alert(isPresented: $showVerificationAlert) {
            Alert(title: Text("Verification"), message: Text(verificationMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    func saveNote() {
        if !noteText.isEmpty {
            savedNotes.append(Note(content: noteText, isVoiceNote: false, sourceURL: nil))
            noteText = ""
            saveNotesToUserDefaults()
        }
    }
    
    func loadNotes() {
        if let loadedNotes = userDefaults?.array(forKey: "SavedNotes-\(authManager.userEmail ?? "")") as? [[String: Any]] {
            savedNotes = loadedNotes.compactMap { dict in
                guard let content = dict["content"] as? String,
                      let isVoiceNote = dict["isVoiceNote"] as? Bool else {
                    return nil
                }
                let sourceURL = dict["sourceURL"] as? String
                return Note(content: isVoiceNote ? URL(fileURLWithPath: content) : content,
                            isVoiceNote: isVoiceNote,
                            sourceURL: sourceURL)
            }
        }
    }
    
    func saveNotesToUserDefaults() {
        let notesToSave = savedNotes.map { note -> [String: Any] in
            ["content": note.isVoiceNote ? (note.content as? URL)?.path ?? "" : (note.content as? String ?? ""),
             "isVoiceNote": note.isVoiceNote,
             "sourceURL": note.sourceURL ?? ""]
        }
        userDefaults?.set(notesToSave, forKey: "SavedNotes-\(authManager.userEmail ?? "")")
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
            savedNotes.append(Note(content: recorder.url, isVoiceNote: true, sourceURL: nil))
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
    
    func decodeURLString(_ string: String) -> String {
        return string.removingPercentEncoding ?? string
    }
    
    func verifyNote() {
        guard let email = authManager.userEmail else {
            showVerificationAlert = true
            verificationMessage = "No user email found. Please sign in again."
            return
        }

        isVerifying = true
        verificationURL = "https://q6bi91a3x8.execute-api.us-east-2.amazonaws.com/default/StoreVeraUsers?email=\(email)"
        
        URLSession.shared.dataTask(with: URL(string: verificationURL)!) { data, response, error in
            DispatchQueue.main.async {
                self.isVerifying = false
                if let error = error {
                    self.showVerificationAlert = true
                    self.verificationMessage = "Error: \(error.localizedDescription)"
                } else if let data = data {
                    if let result = String(data: data, encoding: .utf8) {
                        if result.contains("User not found") {
                            self.createNewUser(email: email)
                        } else {
                            self.showingVeraView = true
                        }
                    } else {
                        self.showVerificationAlert = true
                        self.verificationMessage = "Unable to parse API response"
                    }
                }
            }
        }.resume()
    }
    
    func createNewUser(email: String) {
        // Implement user creation logic here
        // For now, we'll just show an alert
        showVerificationAlert = true
        verificationMessage = "New user creation not implemented yet."
    }
    
    func checkForNewNotes() {
        if authManager.isSignedIn {
            if userDefaults?.bool(forKey: "NewNoteAdded") == true {
                loadNotes()
                userDefaults?.set(false, forKey: "NewNoteAdded")
            }
        }
    }
    
    func deleteNote(_ note: Note) {
        if let index = savedNotes.firstIndex(where: { $0.id == note.id }) {
            savedNotes.remove(at: index)
            saveNotesToUserDefaults()
        }
    }
    
    func verifyNote(_ note: Note) {
        if let content = note.content as? String {
            noteText = content
            verifyNote()
        }
    }
    
    func clearNoteText() {
        noteText = ""
    }
}

struct Note: Identifiable {
    let id = UUID()
    let content: Any
    let isVoiceNote: Bool
    let sourceURL: String?
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(shouldRefresh: .constant(false))
    }
}