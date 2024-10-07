import Foundation
import GoogleSignIn
import SwiftUI

class AuthenticationManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var userEmail: String?
    @Published var errorMessage: String?
    
    static let shared = AuthenticationManager()
    
    private let userDefaults = UserDefaults(suiteName: "group.com.mconsultants.Notester")
    
    private init() {
        print("AuthenticationManager initializing...")
        checkSignInStatus()
    }
    
    func checkSignInStatus() {
        print("Checking sign-in status...")
        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            print("Previous sign-in found, attempting to restore...")
            GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
                DispatchQueue.main.async {
                    if let user = user {
                        print("Sign-in restored for user: \(user.profile?.email ?? "Unknown")")
                        self?.isSignedIn = true
                        self?.userEmail = user.profile?.email
                        self?.userDefaults?.set(user.profile?.email, forKey: "UserEmail")
                    } else if let error = error {
                        print("Failed to restore sign-in: \(error.localizedDescription)")
                        self?.errorMessage = "Failed to restore sign-in: \(error.localizedDescription)"
                    } else {
                        print("No user and no error when restoring sign-in")
                    }
                }
            }
        } else {
            print("No previous sign-in found")
        }
    }
    
    func signIn() {
        guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {
            print("Failed to get root view controller")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error: \(error.localizedDescription)")
                self.errorMessage = "Sign in error: \(error.localizedDescription)"
                return
            }
            
            guard let user = result?.user else {
                print("Error: No user found")
                self.errorMessage = "Sign in error: No user found"
                return
            }
            
            print("User signed in: \(user.profile?.email ?? "Unknown")")
            self.isSignedIn = true
            self.userEmail = user.profile?.email
            self.userDefaults?.set(user.profile?.email, forKey: "UserEmail")
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        userEmail = nil
        userDefaults?.removeObject(forKey: "UserEmail")
    }
}