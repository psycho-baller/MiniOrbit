//
//  ContentView.swift
//  MiniOrbit
//
//  Created by Rami Maalouf on 2025-02-08.
//

import Combine
import SwiftUI
import Vapi

// MARK: - Models

/// Represents a user in the Orbit app.
struct User: Identifiable, Codable, Equatable {
    let id: UUID
    var fullName: String
    var email: String
    var university: String
    var interests: [String]
    var universityID: String
    var isVerified: Bool = false

    init(
        id: UUID = UUID(), fullName: String, email: String,
        university: String, interests: [String], universityID: String,
        isVerified: Bool
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.university = university
        self.interests = interests
        self.universityID = universityID
        self.isVerified = isVerified
    }
}

/// Represents a meetup request created by a user.
struct MeetupRequest: Identifiable, Codable {
    var id: UUID
    var creatorID: UUID
    var time: Date
    var location: String
    var discussionTopic: String
    var conversationStarter: String
    var approvedBy: [UUID] = []  // IDs of users who approved this request.

    init(
        id: UUID = UUID(), creatorID: UUID, time: Date,
        location: String, discussionTopic: String, conversationStarter: String
    ) {
        self.id = id
        self.creatorID = creatorID
        self.time = time
        self.location = location
        self.discussionTopic = discussionTopic
        self.conversationStarter = conversationStarter
    }
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
    @Published var users: [User] = []
    @Published var currentUser: User? = nil
    @Published var meetupRequests: [MeetupRequest] = []
    @Published var chatRooms: [ChatRoom] = []
    // A mapping from a user id to a list of blocked user ids.
    @Published var blockedUsers: [UUID: [UUID]] = [:]

    init() {
        // Create users with UUIDs
        let mark = User(
            fullName: "Mark Prem", email: "mark@example.com",
            university: "University B",
            interests: ["Cooking", "Gaming"], universityID: "U67890",
            isVerified: true)

        let ken = User(
            fullName: "Ken Jin", email: "ken@example.com",
            university: "University A",
            interests: ["Reading", "Hiking"], universityID: "U12345",
            isVerified: true)

        self.users = [ken, mark]

        // Create meetup requests after users are initialized
        self.meetupRequests = [
            MeetupRequest(
                creatorID: mark.id,
                time: Date().addingTimeInterval(3600),  // 1 hour from now
                location: "Library",
                discussionTopic: "Swift Programming",
                conversationStarter: "What's your favorite Swift feature?"
            )
        ]
    }
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
            print("Approving meetup request for \(request.id)")
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
                print("Creating chat room for \(creatorID) and \(userID)")
                // Check if a chat room already exists between these two users.
                if !chatRooms.contains(where: {
                    $0.participantIDs.sorted() == [creatorID, userID].sorted()
                }) {
                    let newChatRoom = ChatRoom(participantIDs: [
                        creatorID, userID,
                    ])
                    chatRooms.append(newChatRoom)
                    print(" Created chat room: \(newChatRoom)")
                    print("chatrooms \(chatRooms)")
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
            room.participantIDs.contains(blockedID)
                && room.participantIDs.contains(blockerID)
        }
    }
}

class CallManager: ObservableObject {
    enum CallState {
        case started, loading, ended
    }

    @Published var callState: CallState = .ended
    var vapiEvents = [Vapi.Event]()
    private var cancellables = Set<AnyCancellable>()
    let vapi: Vapi

    init() {
        vapi = Vapi(
            publicKey: ""
        )
    }

    func setupVapi() {
        vapi.eventPublisher
            .sink { [weak self] event in
                self?.vapiEvents.append(event)
                switch event {
                case .callDidStart:
                    self?.callState = .started
                case .callDidEnd:
                    self?.callState = .ended
                case .error(let error):
                    print("Error: \(error)")
                default:
                    print("Unknown event: \(event)")
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    func handleCallAction() async {
        if callState == .ended {
            await startCall()
        } else {
            endCall()
        }
    }

    @MainActor
    func startCall() async {
        callState = .loading
        let assistant =
            [
                "model": [
                    "provider": "openai",
                    "model": "gpt-3.5-turbo",
                    "messages": [
                        [
                            "role": "system",
                            "content": """
                            1. Overview

                            You are the Orbit Human Assistant. Your role is to ensure that every Orbit user—especially those who cannot fully navigate the app’s interface—can perform all essential tasks. You will act as their intermediary, taking verbal or written instructions and carrying out the actions they request. This includes onboarding, profile management, meetup request creation and browsing, chat coordination, and handling safety features such as blocking or reporting. You must perform these tasks with care, confidentiality, and accuracy.

                            2. Your Capabilities

                            2.1. Onboarding and Account Setup
                            	•	Assisted Onboarding:
                            	•	You shall guide the user through the onboarding process by asking for their full name, email address, university name, interests, and university ID.
                            	•	You shall explain the purpose of each piece of information and how it helps Orbit match them with like-minded individuals.
                            	•	You shall help verify the university ID to confirm the user’s student status.
                            	•	Once the data is collected, you shall confirm the information with the user and submit it to create their account.

                            2.2. Profile Management and Updates
                            	•	Profile Viewing:
                            	•	You shall retrieve and read out the user’s current profile information (name, email, university, interests, and verification status) whenever they request it.
                            	•	Profile Editing:
                            	•	When a user asks to update their profile—for example, adding a new hobby or changing their email—you shall ask for the new details.
                            	•	You shall confirm these changes with the user and update their profile accordingly.
                            	•	If the change involves sensitive information (like an email update), you shall verify the update as required before proceeding.

                            2.3. Meetup Request Management
                            	•	Creating Meetup Requests:
                            	•	You shall help the user create a new meetup request by collecting the following details:
                            	•	Time: Ask them when they want to meet (for example, “12:00 PM – 12:30 PM”).
                            	•	Location: Ask for the meeting spot (for example, “Mac Hall”).
                            	•	Discussion Topic: Ask what topic they want to discuss (for example, “How to make the best of your university experience”).
                            	•	Conversation Starter: Ask if they want to include a conversation starter (for example, “What is one thing that you plan to do more of during your time in university?”).
                            	•	Once you have all the details, you shall confirm with the user and submit the meetup request on their behalf.
                            	•	Browsing and Filtering Meetup Requests:
                            	•	When a user asks, “What meetup requests are available?” you shall retrieve and read out the list of current requests.
                            	•	If the user specifies criteria—such as filtering by location (e.g., “Show me all requests near Mac Hall”)—you shall apply the filter and present the matching requests.
                            	•	You shall provide the key details (time, location, topic, conversation starter) so that the user can decide which request they would like to approve.
                            	•	Approving Meetup Requests:
                            	•	If a user chooses a specific meetup request, you shall confirm that it meets their criteria and then approve it on their behalf.
                            	•	After approving, you shall inform the user that the request has been approved and advise them on the next steps (such as initiating a chat).

                            2.4. Chat and Meetup Coordination
                            	•	Initiating Chat Sessions:
                            	•	Once a user has matched with another, you shall open or join the corresponding chat session.
                            	•	You shall assist in sending introductory messages and confirm that both parties have the necessary information to begin a conversation.
                            	•	Organizing In-Person Meetups:
                            	•	You shall help finalize meetup logistics by confirming details such as the exact meeting time and location.
                            	•	If the user instructs you to share their real-time location (for example, “Share my location at 11:58 AM”), you shall set that up.
                            	•	You shall confirm with the user that all details have been arranged and advise them on what to expect when meeting in person.

                            2.5. Safety and Security Controls
                            	•	Blocking Users:
                            	•	When a user tells you they feel unsafe or uncomfortable with another user, you shall immediately block the offending user. This means preventing any future interactions between them.
                            	•	Reporting Users:
                            	•	If a user instructs you to report someone for inappropriate behavior, you shall file a report with the moderation team.
                            	•	You shall explain the reporting process to the user and confirm once the report has been submitted.
                            	•	Providing Reassurance:
                            	•	Throughout all safety-related actions, you shall provide immediate, clear feedback so the user feels secure and in control of their experience.

                            3. Interaction Workflow

                            When a user contacts you for assistance, follow these steps:
                            	1.	Receive the Request:
                            	•	Listen carefully to what the user needs. For example, if they say, “Show me all meetup requests near Mac Hall,” you shall acknowledge the request.
                            	2.	Clarify Details:
                            	•	Ask any follow-up questions necessary. For instance, “Do you want me to filter by any other criteria?” or “What time would you like to schedule the meetup?”
                            	3.	Execute the Action:
                            	•	Perform the requested task accurately. Whether it’s creating a meetup request, browsing available requests, or updating a profile, you shall follow the established procedures.
                            	4.	Provide Feedback:
                            	•	Once you complete the action, you shall confirm with the user. For example, “Your meetup request has been created,” or “I’ve approved the request for you.”
                            	5.	Offer Follow-Up Assistance:
                            	•	Ask if the user needs any further help or modifications to the action performed.

                            4. Privacy and Security Considerations
                            	•	Confidentiality:
                            	•	You shall treat all user information with strict confidentiality. Never disclose any personal information without explicit permission.
                            	•	Consent and Confirmation:
                            	•	You shall always confirm with the user before making any changes. Make sure you have their clear consent for each action.
                            	•	Auditability:
                            	•	Remember that all actions you perform are logged in the system. Act responsibly and in accordance with Orbit’s privacy policies.

                            5. Conclusion

                            You, as the Orbit Human Assistant, play a crucial role in making Orbit accessible and supportive for all users. By assisting with onboarding, profile management, meetup requests, chat coordination, and safety controls, you enable users to form meaningful connections without the stress of navigating the UI. Follow these guidelines diligently to ensure every interaction is smooth, secure, and user-centered.

                            Thank you for your commitment to making Orbit a welcoming and inclusive platform.


                            You can consider this to be the data that is currently available in the app:
                            ```swift
                                @Published var users: [User] = []
                                @Published var currentUser: User? = nil
                                @Published var meetupRequests: [MeetupRequest] = []
                                @Published var chatRooms: [ChatRoom] = []
                                // A mapping from a user id to a list of blocked user ids.
                                @Published var blockedUsers: [UUID: [UUID]] = [:]

                                init() {
                                    // Create users with UUIDs
                                    let mark = User(
                                        fullName: "Mark Prem", email: "mark@example.com",
                                        university: "University B",
                                        interests: ["Cooking", "Gaming"], universityID: "U67890",
                                        isVerified: true)

                                    let ken = User(
                                        fullName: "Ken Jin", email: "ken@example.com",
                                        university: "University A",
                                        interests: ["Reading", "Hiking"], universityID: "U12345",
                                        isVerified: true)

                                    self.users = [ken, mark]

                                    // Create meetup requests after users are initialized
                                    self.meetupRequests = [
                                        MeetupRequest(
                                            creatorID: mark.id,
                                            time: Date().addingTimeInterval(3600),  // 1 hour from now
                                            location: "Library",
                                            discussionTopic: "Swift Programming",
                                            conversationStarter: "What's your favorite Swift feature?"
                                        )
                                    ]
                                }
                            ```
                            """,
                        ]
                    ],
                ],
                "firstMessage": "Let me know if you have anything you need help with inside Orbit",
                "voice": "jennifer-playht",
            ] as [String: Any]
        do {
            try await vapi.start(assistant: assistant)
        } catch {
            print("Error starting call: \(error)")
            callState = .ended
        }
    }

    func endCall() {
        vapi.stop()
    }
}

extension CallManager {
    var callStateText: String {
        switch callState {
        case .started: return "Call in Progress"
        case .loading: return "Connecting..."
        case .ended: return "Call Off"
        }
    }

    var callStateColor: Color {
        switch callState {
        case .started: return .green.opacity(0.8)
        case .loading: return .orange.opacity(0.8)
        case .ended: return .gray.opacity(0.8)
        }
    }

    var buttonText: String {
        callState == .loading
            ? "Loading..." : (callState == .ended ? "Start Call" : "End Call")
    }

    var buttonColor: Color {
        callState == .loading ? .gray : (callState == .ended ? .green : .red)
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
                        ForEach(0..<orbitData.users.count, id: \.self) {
                            index in
                            Text(orbitData.users[index].fullName)
                        }
                    }
                }
            }
            .navigationTitle("Onboarding")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        orbitData.currentUser =
                            orbitData.users[selectedUserIndex]
                    }
                }
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
    @State private var selectedDate: Date = Date()
    @State private var location: String = ""
    @State private var discussionTopic: String = ""
    @State private var conversationStarter: String = ""

    var body: some View {
        Form {
            Section(header: Text("Schedule Your Meetup")) {
                DatePicker(
                    "Date and Time", selection: $selectedDate,
                    in: Date()...Calendar.current.date(
                        byAdding: .day, value: 1, to: Date())!,
                    displayedComponents: [.date, .hourAndMinute])
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
                    guard let currentUser = orbitData.currentUser,
                        !location.isEmpty,
                        !discussionTopic.isEmpty, !conversationStarter.isEmpty
                    else { return }
                    let newRequest = MeetupRequest(
                        creatorID: currentUser.id,
                        time: selectedDate,
                        location: location,
                        discussionTopic: discussionTopic,
                        conversationStarter: conversationStarter
                    )
                    print("\(newRequest) sent")
                    orbitData.addMeetupRequest(newRequest)
                    print(" Meetup Requests: \(orbitData.meetupRequests)")
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
                    if let currentUser = orbitData.currentUser,
                        request.creatorID != currentUser.id
                    {
                        VStack(alignment: .leading) {
                            Text("Topic: \(request.discussionTopic)")
                                .font(.headline)
                            Text("Location: \(request.location)")
                            Text(
                                "Time: \(request.time.formatted(date: .abbreviated, time: .shortened))"
                            )
                            Text("Starter: \(request.conversationStarter)")
                                .italic()
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing) {
                            Button("Approve") {
                                orbitData.approveMeetupRequest(
                                    request, by: currentUser.id)
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
                            let otherID = room.participantIDs.first(where: {
                                $0 != currentUser.id
                            }
                            ),
                            let otherUser = orbitData.users.first(where: {
                                $0.id == otherID
                            })
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
                                isCurrentUser
                                    ? Color.blue.opacity(0.3)
                                    : Color.gray.opacity(0.3)
                            )
                            .cornerRadius(8)
                            .frame(
                                maxWidth: .infinity,
                                alignment: isCurrentUser ? .trailing : .leading
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
                TextField(
                    "Enter meeting spot (e.g., beside Bake Chef)",
                    text: $sharedLocation
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                Button("Share My Location") {
                    // Simulate sharing location (in a real app, you'd use MapKit/location sharing)
                    showLocationSharedAlert = true
                }
                .alert("Location Shared", isPresented: $showLocationSharedAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(
                        "Your location (\(sharedLocation)) has been shared with your match."
                    )
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
                        message: Text(
                            "Select an action to protect your experience."),
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
        guard let currentUser = orbitData.currentUser, !messageText.isEmpty
        else { return }
        let newMessage = ChatMessage(
            senderID: currentUser.id, text: messageText)
        localChatRoom.messages.append(newMessage)
        // Update the global chatRooms array.
        if let index = orbitData.chatRooms.firstIndex(where: {
            $0.id == localChatRoom.id
        }) {
            orbitData.chatRooms[index] = localChatRoom
        }
        messageText = ""
    }

    private func blockUser() {
        // Block the other user from this chat.
        guard let currentUser = orbitData.currentUser else { return }
        if let otherID = localChatRoom.participantIDs.first(where: {
            $0 != currentUser.id
        }) {
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
    @StateObject private var callManager = CallManager()

    var body: some View {
        ZStack {
            TabView {
                NavigationStack {
                    VStack(spacing: 20) {
                        NavigationLink(
                            "Create Meetup Request",
                            destination: CreateMeetupRequestView(
                                orbitData: orbitData))
                        NavigationLink(
                            "Browse Requests",
                            destination: BrowseMeetupRequestsView(
                                orbitData: orbitData))
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

                NavigationStack {
                    ProfileView(orbitData: orbitData)
                }
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        Task {
                            await callManager.handleCallAction()
                        }
                    }) {
                        Image(systemName: "phone.fill")
                            .resizable()
                            .frame(width: 25, height: 25)
                            .padding()
                            .background(callManager.buttonColor)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .shadow(radius: 10)
                    }
                    .padding()
                    .onAppear {
                        callManager.setupVapi()
                    }
                }
                .padding(.bottom, 30)
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
