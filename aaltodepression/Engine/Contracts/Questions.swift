import Foundation

// Contract: questions and answers in one generic shape, so a screen can render any question
// (check-in, the shop question, safety questions, follow-ups) with one component per answer kind.
// Engine/Planner/QuestionCatalog.swift lists the questions and turns answers into planner state.

/// How a question is answered.
nonisolated enum AnswerKind: Sendable, Equatable {
    /// Likert scale, e.g. mood 1–5. `labels` has one entry per step (emoji or words).
    case likert(ClosedRange<Int>, labels: [String])
    /// Ordered steps, e.g. energy: Not much · Some · Plenty.
    case scale([String])
    /// Pick any number, e.g. feeling words.
    case multiSelect([String])
    /// Pick exactly one, e.g. food at home.
    case singleChoice([String])
    case yesNo
    /// A number in steps, e.g. minutes of screen time read from iOS Settings. Answered as `.number`.
    case numeric(ClosedRange<Int>, step: Int, unit: String)
}

nonisolated struct Question: Sendable, Equatable, Identifiable {
    let id: String
    let prompt: String
    let kind: AnswerKind
    /// Can be skipped without blocking the rest.
    var optional = false
    /// Shown under the prompt, e.g. "In the past month:".
    var hint: String? = nil
}

/// One answer. Option answers are indexes into the question's options.
nonisolated enum Answer: Codable, Sendable, Equatable {
    case number(Int)
    case option(Int)
    case options(Set<Int>)
    case yes(Bool)
}

/// An answer as it was given, for the demo log and for learning. Safety answers are never logged.
nonisolated struct AnswerRecord: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let questionID: String
    let answer: Answer
    let day: Day
    let at: Date

    init(questionID: String, answer: Answer, day: Day, at: Date) {
        self.id = UUID().uuidString
        self.questionID = questionID; self.answer = answer; self.day = day; self.at = at
    }

    enum CodingKeys: String, CodingKey { case id, questionID, answer, day, at }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        questionID = try c.decode(String.self, forKey: .questionID)
        answer = try c.decode(Answer.self, forKey: .answer)
        day = try c.decode(Day.self, forKey: .day)
        at = try c.decode(Date.self, forKey: .at)
    }
}
