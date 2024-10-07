import Foundation
import GoogleSignIn
import SwiftUI

class AuthenticationManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var userEmail: String?
    @Published var errorMessage: String?
    
    static let shared = AuthenticationManager()
    
    private init() {
        checkSignInStatus()
    }
    
    func checkSignInStatus() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // Mock sign-in for preview
            self.isSignedIn = true
            self.userEmail = "preview@example.com"
            return
        }
        #endif
        
        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            print("Attempting to restore previous sign-in")
            GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
                DispatchQueue.main.async {
                    if let user = user {
                        self?.isSignedIn = true
                        self?.userEmail = user.profile?.email
                        print("Successfully restored sign-in for user: \(user.profile?.email ?? "Unknown")")
                    } else if let error = error {
                        self?.errorMessage = "Failed to restore sign-in: \(error.localizedDescription)"
                        print("Failed to restore sign-in: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            print("No previous sign-in found")
        }
    }
    
    func signIn() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // Mock sign-in for preview
            self.isSignedIn = true
            self.userEmail = "preview@example.com"
            return
        }
        #endif
        
        print("Attempting to sign in")
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            self.errorMessage = "Failed to get root view controller"
            print("Failed to get root view controller")
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.isSignedIn = true
                    self?.userEmail = result.user.profile?.email
                    print("Successfully signed in user: \(result.user.profile?.email ?? "Unknown")")
                } else if let error = error {
                    self?.errorMessage = "Sign in failed: \(error.localizedDescription)"
                    print("Sign in failed: \(error.localizedDescription)")
                } else {
                    self?.errorMessage = "Sign in failed: Unknown error"
                    print("Sign in failed: Unknown error")
                }
            }
        }
    }
    
    func signOut() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // Mock sign-out for preview
            self.isSignedIn = false
            self.userEmail = nil
            return
        }
        #endif
        
        print("Attempting to sign out")
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        userEmail = nil
        print("Successfully signed out")
    }
}