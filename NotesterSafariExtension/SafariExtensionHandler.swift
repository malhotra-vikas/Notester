import SafariServices

class NotesterSafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let item = context.inputItems[0] as! NSExtensionItem
        let message = item.userInfo?[SFExtensionMessageKey]
        let response = NSExtensionItem()
        
        if let message = message as? [String: Any],
           let messageName = message["name"] as? String,
           messageName == "selectedText",
           let text = message["text"] as? String {
            saveNote(text)
            response.userInfo = [ SFExtensionMessageKey: [ "response": "Note saved" ] ]
        } else {
            response.userInfo = [ SFExtensionMessageKey: [ "response": "Invalid message" ] ]
        }
        
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
    
    func saveNote(_ text: String) {
        let userDefaults = UserDefaults(suiteName: "group.com.mconsultants.Notester")
        if let userEmail = userDefaults?.string(forKey: "UserEmail") {
            let key = "SavedNotes-\(userEmail)"
            var savedNotes = userDefaults?.array(forKey: key) as? [[String: Any]] ?? []
            let newNote: [String: Any] = ["content": text, "isVoiceNote": false]
            savedNotes.append(newNote)
            userDefaults?.set(savedNotes, forKey: key)
            
            // Set a flag to indicate that a new note has been added
            userDefaults?.set(true, forKey: "NewNoteAdded")
        }
    }
}