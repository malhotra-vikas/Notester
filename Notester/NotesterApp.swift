//
//  NotesterApp.swift
//  Notester
//
//  Created by Vikas Malhotra on 10/7/24.
//

import SwiftUI
import GoogleSignIn
import os

@main
struct NotesterApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var shouldRefresh = false

    init() {
        print("NotesterApp initializing...")
        configureGoogleSignIn()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(shouldRefresh: $shouldRefresh)
                .onAppear {
                    print("ContentView appeared")
                }
                .onOpenURL { url in
                    print("Handling URL: \(url)")
                    if url.scheme == "notester" && url.host == "refresh" {
                        shouldRefresh = true
                    } else {
                        GIDSignIn.sharedInstance.handle(url)
                    }
                }
                .environmentObject(authManager)
        }
    }
    
    private func configureGoogleSignIn() {
        print("Configuring Google Sign-In...")
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
            print("Client ID found: \(clientID)")
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            print("Google Sign-In configured successfully")
        } else {
            print("No Google Sign-In client ID found in Info.plist")
            if let dict = Bundle.main.infoDictionary {
                print("Info.plist contents:")
                for (key, value) in dict {
                    print("\(key): \(value)")
                }
            }
        }
    }
}
