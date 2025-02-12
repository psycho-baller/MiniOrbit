//
//  ProfileView.swift
//  MiniOrbit
//
//  Created by Nathaniel D'Orazio on 2025-02-09.
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var orbitData: OrbitData

    var body: some View {
        NavigationStack {
            if let user = orbitData.currentUser {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Name: \(user.fullName)")
                        .accessibilityIdentifier("nameText") // For UI tests to find the element
                        .accessibilityLabel("User's full name is \(user.fullName)") // For VoiceOver to read
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Email: \(user.email)")
//                        .accessibilityIdentifier("email")
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("University: \(user.university)")
//                        .accessibilityIdentifier("university")
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Interests: \(user.interests.joined(separator: ", "))")
                        .accessibilityIdentifier("interests")
//                        .lineLimit(nil)
//                        .fixedSize(horizontal: false, vertical: true)
                    Text("University ID: \(user.universityID)")
                        .accessibilityIdentifier("universityId")
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Verified: \(user.isVerified ? "Yes" : "No")")
                        .accessibilityIdentifier("verified")
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    NavigationLink("Edit Profile") {
                        EditProfileView(user: user, orbitData: orbitData)
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

#Preview {
    let previewData = OrbitData()
    previewData.currentUser = previewData.users[0]
    return ProfileView(orbitData: previewData)
}
