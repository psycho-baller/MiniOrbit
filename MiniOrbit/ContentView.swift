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

/// Represents a meetup request created by a user (Task 3).
struct MeetupRequest: Identifiable, Codable {
    var id: UUID = UUID()
    var creatorID: UUID
    var time: Date
    var location: String
    var discussionTopic: String
    var conversationStarter: String
    var approvedBy: [UUID] = []  // IDs of users who approved this request.
}

/// Represents a single chat message.
struct ChatMessage: Identifiable {
    var id: UUID = UUID()
    var senderID: UUID
    var text: String
    var timestamp: Date = Date()
}

/// Represents a chat room between two users.
struct ChatRoom: Identifiable {
    var id: UUID = UUID()
    var participantIDs: [UUID]  // Should contain exactly 2 users.
    var messages: [ChatMessage] = []
}

// MARK: - Simulated Database (Orbit Data)

/// This ObservableObject simulates our full‑stack database.
class OrbitData: ObservableObject {
    @Published var users: [User] = [
        User(
            fullName: "Alice Johnson", email: "alice@example.com", university: "University A",
            interests: ["Reading", "Hiking"], universityID: "U12345", isVerified: true),
        User(
            fullName: "Bob Smith", email: "bob@example.com", university: "University B",
            interests: ["Cooking", "Gaming"], universityID: "U67890", isVerified: true),
    ]
    @Published var currentUser: User? = nil

    @Published var meetupRequests: [MeetupRequest] = []
    @Published var chatRooms: [ChatRoom] = []
    // A mapping from a user id to a list of blocked user ids.
    @Published var blockedUsers: [UUID: [UUID]] = [:]

    /// Adds a new user and sets them as the current user.
    func addUser(_ user: User) {
        users.append(user)
        currentUser = user
    }

    /// Updates an existing user.
    func updateUser(_ updatedUser: User) {
        if let index = users.firstIndex(where: { $0.id == updatedUser.id }) {
            users[index] = updatedUser
            currentUser = updatedUser
        }
    }

    /// Adds a new meetup request.
    func addMeetupRequest(_ request: MeetupRequest) {
        meetupRequests.append(request)

    }

    /// Approves a meetup request for the given user.
    func approveMeetupRequest(_ request: MeetupRequest, by userID: UUID) {
        if let index = meetupRequests.firstIndex(where: { $0.id == request.id }) {
            // Avoid duplicate approvals.
            if !meetupRequests[index].approvedBy.contains(userID) {
                meetupRequests[index].approvedBy.append(userID)
            }
            // If both the creator and an approver have matched, create a chat room.
            let creatorID = meetupRequests[index].creatorID
            if meetupRequests[index].approvedBy.contains(creatorID) == false,  // Creator never approves own request
                meetupRequests[index].approvedBy.contains(userID),
                userID != creatorID
            {
                // Check if a chat room already exists between these two users.
                if !chatRooms.contains(where: {
                    $0.participantIDs.sorted() == [creatorID, userID].sorted()
                }) {
                    let newChatRoom = ChatRoom(participantIDs: [creatorID, userID])
                    chatRooms.append(newChatRoom)
                }
            }
        }
    }

    /// Blocks a user for the current user.
    func blockUser(blockerID: UUID, blockedID: UUID) {
        if blockedUsers[blockerID] != nil {
            if !blockedUsers[blockerID]!.contains(blockedID) {
                blockedUsers[blockerID]!.append(blockedID)
            }
        } else {
            blockedUsers[blockerID] = [blockedID]
        }
        // Remove any chat room between these users.
        chatRooms.removeAll { room in
            room.participantIDs.contains(blockedID) && room.participantIDs.contains(blockerID)
        }
    }
}

// MARK: - Onboarding & Profile Editing (Tasks 1 & 2)

/// Onboarding flow: new users input personal info and verify their university ID.
struct OnboardingView: View {
    @ObservedObject var orbitData: OrbitData

    @State private var selectedUserIndex: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Select User")) {
                    Picker("User", selection: $selectedUserIndex) {
                        ForEach(0..<orbitData.users.count, id: \.self) { index in
                            Text(orbitData.users[index].fullName)
                        }
                    }
                }
            }
            .navigationTitle("Onboarding")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        orbitData.currentUser = orbitData.users[selectedUserIndex]
                    }
                }
            }
        }
    }
}

/// Displays current user’s profile and allows editing.
struct ProfileView: View {
    @ObservedObject var orbitData: OrbitData

    var body: some View {
        NavigationStack {
            if let user = orbitData.currentUser {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Name: \(user.fullName)")
                    Text("Email: \(user.email)")
                    Text("University: \(user.university)")
                    Text("Interests: \(user.interests.joined(separator: ", "))")
                    Text("University ID: \(user.universityID)")
                    Text("Verified: \(user.isVerified ? "Yes" : "No")")

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

/// Allows a user to update personal information.
struct EditProfileView: View {
    @State var user: User
    @ObservedObject var orbitData: OrbitData

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
                    let interestsArray = interests.split(separator: ",").map {
                        $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    var updatedUser = user
                    updatedUser.fullName = fullName
                    updatedUser.email = email
                    updatedUser.university = university
                    updatedUser.interests = interestsArray
                    updatedUser.universityID = universityID
                    orbitData.updateUser(updatedUser)
                }
            }
        }
        .onAppear {
            fullName = user.fullName
            email = user.email
            university = user.university
            interests = user.interests.joined(separator: ", ")
            universityID = user.universityID
        }
    }
}

// MARK: - Meetup Request Flow (Tasks 3 & 4)

/// Task 3: Create a Meetup Request (for users like Mark).
struct CreateMeetupRequestView: View {
    @ObservedObject var orbitData: OrbitData
    @State private var selectedTime: Date = Date()
    @State private var location: String = ""
    @State private var discussionTopic: String = ""
    @State private var conversationStarter: String = ""

    var body: some View {
        Form {
            Section(header: Text("Schedule Your Meetup")) {
                DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                TextField("Location (e.g., Mac Hall)", text: $location)
            }
            Section(header: Text("Conversation Details")) {
                TextField("Discussion Topic", text: $discussionTopic)
                TextField("Conversation Starter", text: $conversationStarter)
            }
        }
        .navigationTitle("Create Meetup Request")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Send Request") {
                    guard let currentUser = orbitData.currentUser, !location.isEmpty,
                        !discussionTopic.isEmpty, !conversationStarter.isEmpty
                    else { return }
                    let newRequest = MeetupRequest(
                        creatorID: currentUser.id,
                        time: selectedTime,
                        location: location,
                        discussionTopic: discussionTopic,
                        conversationStarter: conversationStarter
                    )
                    orbitData.addMeetupRequest(newRequest)
                }
            }
        }
    }
}

/// Task 4: Browse and Approve Meetup Requests (for users like Ken).
struct BrowseMeetupRequestsView: View {
    @ObservedObject var orbitData: OrbitData

    var body: some View {
        NavigationStack {
            List {
                ForEach(orbitData.meetupRequests) { request in
                    // Show only requests not created by the current user.
                    if let currentUser = orbitData.currentUser, request.creatorID != currentUser.id
                    {
                        VStack(alignment: .leading) {
                            Text("Topic: \(request.discussionTopic)")
                                .font(.headline)
                            Text("Location: \(request.location)")
                            Text(
                                "Time: \(request.time.formatted(date: .omitted, time: .shortened))")
                            Text("Starter: \(request.conversationStarter)")
                                .italic()
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing) {
                            Button("Approve") {
                                orbitData.approveMeetupRequest(request, by: currentUser.id)
                            }
                            .tint(.green)
                        }
                    }
                }
            }
            .navigationTitle("Browse Requests")
        }
    }
}

// MARK: - Chat & Meetup Coordination (Tasks 5 & 6)

/// Displays the list of chat rooms (matches) for the current user.
struct ChatListView: View {
    @ObservedObject var orbitData: OrbitData

    var body: some View {
        NavigationStack {
            List {
                ForEach(
                    orbitData.chatRooms.filter { room in
                        // Only show chat rooms where currentUser is a participant.
                        if let currentUser = orbitData.currentUser {
                            return room.participantIDs.contains(currentUser.id)
                        }
                        return false
                    }
                ) { room in
                    NavigationLink {
                        ChatRoomView(chatRoom: room, orbitData: orbitData)
                    } label: {
                        if let currentUser = orbitData.currentUser,
                            let otherID = room.participantIDs.first(where: { $0 != currentUser.id }
                            ),
                            let otherUser = orbitData.users.first(where: { $0.id == otherID })
                        {
                            Text("Chat with \(otherUser.fullName)")
                        } else {
                            Text("Chat")
                        }
                    }
                }
            }
            .navigationTitle("Chats")
        }
    }
}

/// ChatRoomView shows messages between two matched users and includes controls for organizing the meetup (location sharing) as well as blocking/reporting (Task 6).
struct ChatRoomView: View {
    let chatRoom: ChatRoom
    @ObservedObject var orbitData: OrbitData

    @State private var messageText: String = ""
    // For simulating location sharing.
    @State private var sharedLocation: String = ""
    @State private var showLocationSharedAlert: Bool = false
    @State private var showBlockReportActionSheet: Bool = false
    @State private var localChatRoom: ChatRoom

    init(chatRoom: ChatRoom, orbitData: OrbitData) {
        self.chatRoom = chatRoom
        self.orbitData = orbitData
        // Create a local copy to allow editing.
        _localChatRoom = State(initialValue: chatRoom)
    }

    var body: some View {
        VStack {
            List(localChatRoom.messages) { message in
                HStack {
                    if let currentUser = orbitData.currentUser {
                        let isCurrentUser = message.senderID == currentUser.id
                        Text(message.text)
                            .padding()
                            .background(
                                isCurrentUser ? Color.blue.opacity(0.3) : Color.gray.opacity(0.3)
                            )
                            .cornerRadius(8)
                            .frame(
                                maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading
                            )
                    }
                }
            }
            HStack {
                TextField("Message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Send") {
                    sendMessage()
                }
            }
            .padding()
            Divider()
            // Meetup Coordination Section (Task 5)
            VStack {
                Text("Organize Meetup")
                    .font(.headline)
                TextField("Enter meeting spot (e.g., beside Bake Chef)", text: $sharedLocation)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                Button("Share My Location") {
                    // Simulate sharing location (in a real app, you'd use MapKit/location sharing)
                    showLocationSharedAlert = true
                }
                .alert("Location Shared", isPresented: $showLocationSharedAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Your location (\(sharedLocation)) has been shared with your match.")
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Block/Report button (Task 6)
                Button {
                    showBlockReportActionSheet = true
                } label: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .actionSheet(isPresented: $showBlockReportActionSheet) {
                    ActionSheet(
                        title: Text("Block or Report"),
                        message: Text("Select an action to protect your experience."),
                        buttons: [
                            .destructive(Text("Block User")) {
                                blockUser()
                            },
                            .default(Text("Report User")) {
                                reportUser()
                            },
                            .cancel(),
                        ])
                }
            }
        }
    }

    private func sendMessage() {
        guard let currentUser = orbitData.currentUser, !messageText.isEmpty else { return }
        let newMessage = ChatMessage(senderID: currentUser.id, text: messageText)
        localChatRoom.messages.append(newMessage)
        // Update the global chatRooms array.
        if let index = orbitData.chatRooms.firstIndex(where: { $0.id == localChatRoom.id }) {
            orbitData.chatRooms[index] = localChatRoom
        }
        messageText = ""
    }

    private func blockUser() {
        // Block the other user from this chat.
        guard let currentUser = orbitData.currentUser else { return }
        if let otherID = localChatRoom.participantIDs.first(where: { $0 != currentUser.id }) {
            orbitData.blockUser(blockerID: currentUser.id, blockedID: otherID)
        }
    }

    private func reportUser() {
        // For demo: simply block the user after reporting.
        blockUser()
        // In a real app, you would send a report to a moderation team.
    }
}

// MARK: - Main App Navigation (TabView)

struct MainTabView: View {
    @ObservedObject var orbitData: OrbitData

    var body: some View {
        TabView {
            NavigationStack {
                ProfileView(orbitData: orbitData)
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }

            NavigationStack {
                VStack(spacing: 20) {
                    NavigationLink(
                        "Create Meetup Request",
                        destination: CreateMeetupRequestView(orbitData: orbitData))
                    NavigationLink(
                        "Browse Requests",
                        destination: BrowseMeetupRequestsView(orbitData: orbitData))
                }
                .navigationTitle("Meetups")
            }
            .tabItem {
                Label("Meetups", systemImage: "calendar")
            }

            NavigationStack {
                ChatListView(orbitData: orbitData)
            }
            .tabItem {
                Label("Chats", systemImage: "message")
            }
        }
    }
}

// MARK: - ContentView: Entry Point for Logged-in Users

struct ContentView: View {
    @StateObject var orbitData = OrbitData()

    var body: some View {
        if orbitData.currentUser == nil {
            // If no user is logged in, show onboarding.
            OnboardingView(orbitData: orbitData)
        } else {
            MainTabView(orbitData: orbitData)
        }
    }
}

#Preview {
    ContentView()
}
#Preview {
    ContentView()
}
