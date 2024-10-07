//
//  ShareViewController.swift
//  NotesterShareExtension
//
//  Created by Vikas Malhotra on 10/7/24.
//

import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        
        let textTypes = [UTType.text.identifier, UTType.plainText.identifier, UTType.utf8PlainText.identifier]
        let urlTypes = [UTType.url.identifier]
        
        for type in textTypes + urlTypes {
            if itemProvider.hasItemConformingToTypeIdentifier(type) {
                itemProvider.loadItem(forTypeIdentifier: type, options: nil) { (item, error) in
                    if let error = error {
                        print("Error loading item: \(error.localizedDescription)")
                        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                        return
                    }
                    
                    var text: String?
                    
                    if let urlString = item as? String {
                        text = self.decodeURLString(urlString)
                    } else if let url = item as? URL {
                        text = self.decodeURLString(url.absoluteString)
                    } else if let string = item as? String {
                        text = self.decodeURLString(string)
                    }
                    
                    if let text = text {
                        self.saveNote(text)
                    }
                    
                    self.openMainApp()
                }
                return
            }
        }
        
        // If we reach here, we couldn't handle the shared content
        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    func decodeURLString(_ string: String) -> String {
        return string.removingPercentEncoding ?? string
    }
    
    func saveNote(_ text: String) {
        let userDefaults = UserDefaults(suiteName: "group.com.mconsultants.Notester")
        var savedNotes = userDefaults?.array(forKey: "SavedNotes") as? [[String: Any]] ?? []
        let newNote: [String: Any] = ["content": text, "isVoiceNote": false]
        savedNotes.append(newNote)
        userDefaults?.set(savedNotes, forKey: "SavedNotes")
    }
    
    func openMainApp() {
        let url = URL(string: "notester://")!
        self.extensionContext?.completeRequest(returningItems: nil) { _ in
            _ = self.openURL(url)
        }
    }
    
    @objc func openURL(_ url: URL) -> Bool {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                return application.perform(#selector(UIApplication.open(_:options:completionHandler:)), with: url, with: [:]) != nil
            }
            responder = responder?.next
        }
        return false
    }
}
