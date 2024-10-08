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
    @Binding var shouldRefresh: Bool
    @State private var showVerificationAlert = false
    @State private var isVerifying = false
    @State private var verificationMessage = ""
    @State private var showingVeraView = false
    @State private var verificationURL: String = ""

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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            checkForNewNotes()
        }
        .onChange(of: shouldRefresh) { newValue in
            if newValue {
                loadNotes()
                shouldRefresh = false
            }
        }
        .sheet(isPresented: $showingVeraView) {
            VeraView(url: verificationURL, emailLoggedIn: authManager.userEmail ?? "Not signed in")
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
                
                Button(action: {
                    verifyNote()
                    showingVeraView = true
                }) {
                    Text("Verify")
                }
                .foregroundColor(.green)
                .disabled(isVerifying)
            }
            .padding()
            
            if isVerifying {
                ProgressView("Verifying...")
            }
            
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            loadNotes()
        }
        .alert(isPresented: $showVerificationAlert) {
            Alert(title: Text("Verification"), message: Text(verificationMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    func saveNote() {
        if !noteText.isEmpty {
            savedNotes.append(Note(content: noteText, isVoiceNote: false))
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
    
    func checkForNewNotes() {
        if authManager.isSignedIn {
            if userDefaults?.bool(forKey: "NewNoteAdded") == true {
                loadNotes()
                userDefaults?.set(false, forKey: "NewNoteAdded")
            }
        }
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
        let apiGatewayUrl = "https://q6bi91a3x8.execute-api.us-east-2.amazonaws.com/default/StoreVeraUsers"
        guard let url = URL(string: apiGatewayUrl) else {
            showVerificationAlert = true
            verificationMessage = "Invalid URL for user creation"
            return
        }

        let trialCredits = "5"
        let userData = [
            "email": email,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "subscription_status": "New User",
            "credits": trialCredits
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: userData)
        } catch {
            showVerificationAlert = true
            verificationMessage = "Error creating user data: \(error.localizedDescription)"
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.showVerificationAlert = true
                    self.verificationMessage = "Error creating user: \(error.localizedDescription)"
                } else if let data = data {
                    if let result = String(data: data, encoding: .utf8) {
                        self.showVerificationAlert = true
                        self.verificationMessage = "New user created: \(result)"
                        
                        // Send new-user notification
                        self.sendNotification(notificationType: "new-user", email: email)
                    } else {
                        self.showVerificationAlert = true
                        self.verificationMessage = "Unable to parse user creation response"
                    }
                }
            }
        }.resume()
    }

    func sendNotification(notificationType: String, email: String) {
        let url = URL(string: "https://q6bi91a3x8.execute-api.us-east-2.amazonaws.com/default/NotificationQueueAppender")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "notificationType": notificationType,
            "email": email
        ]

        if notificationType == "trial-expired-2-day-reminder" {
            let twoDaysFromNow = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            payload["delayDate"] = dateFormatter.string(from: twoDaysFromNow)
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("Error creating notification payload: \(error.localizedDescription)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending notification: \(error.localizedDescription)")
            } else {
                print("Notification sent successfully (no-cors mode, response cannot be read).")
            }
        }.resume()
    }
}

struct Note: Identifiable {
    let id = UUID()
    let content: Any
    let isVoiceNote: Bool
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(shouldRefresh: .constant(false))
    }
}
