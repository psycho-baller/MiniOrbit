//
//  ContentView.swift
//  MiniOrbit
//
//  Created by Rami Maalouf on 2025-02-08.
//

import SwiftUI

// MARK: - Models

/// Represents a user in the Orbit app.
struct User: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var fullName: String
    var email: String
    var university: String
    var interests: [String]
    var universityID: String
    var isVerified: Bool = false
}

// MARK: - Simulated Database

/// A simple in-memory user database.
class UserDatabase: ObservableObject {
    @Published var users: [User] = []
    // For this demo, we keep track of the currently logged in user.
    @Published var currentUser: User?

    func addUser(_ user: User) {
        users.append(user)
        currentUser = user
    }

    func updateUser(_ updatedUser: User) {
        if let index = users.firstIndex(where: { $0.id == updatedUser.id }) {
            users[index] = updatedUser
            currentUser = updatedUser
        }
    }
}

// MARK: - Onboarding View

/// The onboarding flow where users input personal info and verify their university ID.
struct OnboardingView: View {
    @ObservedObject var userDB: UserDatabase

    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var university: String = ""
    @State private var interests: String = ""  // Comma-separated list.
    @State private var universityID: String = ""
    @State private var isVerified: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("Full Name", text: $fullName)
                        .textCase(.uppercase)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                    TextField("University", text: $university)
                }

                Section(header: Text("Interests")) {
                    TextField(
                        "Enter interests (comma separated)", text: $interests)
                }

                Section(header: Text("University ID Verification")) {
                    TextField("Enter your University ID", text: $universityID)
                        .textCase(.lowercase)
                    Button(action: {
                        // For demo purposes, we assume any non-empty universityID means verification.
                        if !universityID.isEmpty {
                            isVerified = true
                        }
                    }) {
                        Text(isVerified ? "Verified" : "Verify University ID")
                    }
                    .disabled(isVerified)
                }
            }
            .navigationTitle("Onboarding")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        // Ensure required fields are filled and university ID is verified.
                        guard isVerified, !fullName.isEmpty, !email.isEmpty,
                            !university.isEmpty
                        else { return }
                        let interestsArray =
                            interests
                            .split(separator: ",")
                            .map {
                                $0.trimmingCharacters(
                                    in: .whitespacesAndNewlines)
                            }
                        let newUser = User(
                            fullName: fullName,
                            email: email,
                            university: university,
                            interests: interestsArray,
                            universityID: universityID,
                            isVerified: isVerified
                        )
                        userDB.addUser(newUser)
                    }
                }
            }
        }
    }
}

// MARK: - Profile and Editing Views

/// Displays the current user's profile and a link to edit their information.
struct ProfileView: View {
    @ObservedObject var userDB: UserDatabase

    var body: some View {
        NavigationStack {
            if let user = userDB.currentUser {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Name: \(user.fullName)")
                    Text("Email: \(user.email)")
                    Text("University: \(user.university)")
                    Text("Interests: \(user.interests.joined(separator: ", "))")
                    Text("University ID: \(user.universityID)")
                    Text("Verified: \(user.isVerified ? "Yes" : "No")")

                    NavigationLink("Edit Profile") {
                        EditProfileView(user: user, userDB: userDB)
                    }
                    .padding(.top, 20)
                }
                .padding()
                .navigationTitle("Profile")
            } else {
                Text("No user logged in.")
            }
        }
    }
}

/// Allows the user to update personal information after account creation.
struct EditProfileView: View {
    @State var user: User
    @ObservedObject var userDB: UserDatabase

    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var university: String = ""
    @State private var interests: String = ""
    @State private var universityID: String = ""

    var body: some View {
        Form {
            Section(header: Text("Personal Information")) {
                TextField("Full Name", text: $fullName)
                    .textCase(.uppercase)
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                TextField("University", text: $university)
            }
            Section(header: Text("Interests")) {
                TextField("Enter interests (comma separated)", text: $interests)
            }
            Section(header: Text("University ID")) {
                TextField("University ID", text: $universityID)
                    .textCase(.lowercase)
            }
        }
        .navigationTitle("Edit Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let interestsArray =
                        interests
                        .split(separator: ",")
                        .map {
                            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    var updatedUser = user
                    updatedUser.fullName = fullName
                    updatedUser.email = email
                    updatedUser.university = university
                    updatedUser.interests = interestsArray
                    updatedUser.universityID = universityID
                    // In a real app, you might re-verify sensitive changes.
                    userDB.updateUser(updatedUser)
                }
            }
        }
        .onAppear {
            // Initialize fields with the user's current information.
            fullName = user.fullName
            email = user.email
            university = user.university
            interests = user.interests.joined(separator: ", ")
            universityID = user.universityID
        }
    }
}

// MARK: - Main ContentView

struct ContentView: View {
    @StateObject var userDB = UserDatabase()

    var body: some View {
        NavigationStack {
            if userDB.currentUser != nil {
                ProfileView(userDB: userDB)
            } else {
                OnboardingView(userDB: userDB)
            }
        }
    }
}

#Preview {
    ContentView()
}
