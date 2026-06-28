import Foundation

enum ExerciseStatus: String, Codable {
    case pending, done, skipped
}

struct Exercise: Identifiable, Codable, Hashable {
    var id: String
    var day: String
    var name: String
    var targetSets: Int
    var sets: Int
    var completedSets: Int
    var skippedSets: Int
    var reps: Int
    var weight: Double
    var rest: Int
    var note: String
    var status: ExerciseStatus

    var closedSets: Int { min(sets, completedSets + skippedSets) }
    var resolvedStatus: ExerciseStatus {
        if closedSets < sets { return .pending }
        return completedSets > 0 ? .done : .skipped
    }
}

struct Player: Codable {
    var xp: Int
    var streak: Int
    var focus: Int
    var hearts: Int
}

struct Profile: Codable {
    var sex: String
    var age: String
    var country: String
    var city: String
    var gym: String
    var region: String? = nil
    var birthdate: Date? = nil
}

struct HistoryEntry: Identifiable, Codable {
    var id: String
    var exerciseName: String
    var day: String
    var status: ExerciseStatus
    var sets: Int
    var reps: Int
    var weight: Double
    var volume: Double
    var xp: Int
    var completedAt: Date
    var sessionId: String?
}

enum WorkoutVisibility: String, Codable, CaseIterable {
    case all, followers, onlyMe
    var label: String {
        switch self { case .all: return "Todos"; case .followers: return "Seguidores"; case .onlyMe: return "Solo yo" }
    }
    var icon: String {
        switch self { case .all: return "globe"; case .followers: return "person.2.fill"; case .onlyMe: return "lock.fill" }
    }
}

struct WorkoutSession: Identifiable, Codable {
    var id: String
    var name: String
    var note: String
    var date: Date
    var elapsed: Int
    var exercises: Int
    var sets: Int
    var volume: Double
    var xp: Int
    var photoData: Data?
    var visibility: WorkoutVisibility
}

struct WorkoutTemplate: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var description: String
    var block: String
    var exercises: [Exercise]
}

// MARK: - Partner

struct TrainingPlan: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var when: String
    var place: String
    var spots: String
    var ownerId: String   // "me" or a person id
    var score: Int
}

// MARK: - Social

enum RelationshipStatus: String, Codable {
    case none, outgoing, incoming, friends
}

struct Account: Codable, Equatable {
    var name: String
    var handle: String
    var photoData: Data? = nil
    var photoScale: Double? = nil
    var photoOffsetX: Double? = nil
    var photoOffsetY: Double? = nil
}

struct SocialPerson: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var handle: String
    var avatar: String
    var gym: String
    var flag: String = "🇪🇸"
    var city: String = "Madrid"
    var country: String = "España"
}

struct ChatMessage: Identifiable, Codable, Hashable {
    var id: String
    var fromMe: Bool
    var text: String
    var at: Date
}

struct Conversation: Identifiable, Codable, Hashable {
    var id: String
    var personId: String
    var messages: [ChatMessage]
    var unread: Int
    var lastAt: Date
    var lastMessage: ChatMessage? { messages.last }
}

enum NotificationType: String, Codable {
    case friendRequest, friendAccepted, trainingAccepted
}

struct AppNotification: Identifiable, Codable, Hashable {
    var id: String
    var type: NotificationType
    var title: String
    var body: String
    var at: Date
    var read: Bool
    var personId: String?
    var conversationId: String?
}

// MARK: - Gym Score

struct GymScore {
    var total: Int
    var potential: Int
    var reliability: Int
    var reliable: Bool
    var daysUntilReliable: Int
    var tier: String
    var strength: Int
    var consistency: Int
    var volume: Int
    var progression: Int
    var variety: Int
    var quality: Int
    var sessions: Int
    var trainingDays: Int
}
