//
//  Status.swift
//  cirqueduci
//
//  CircleCI status/state/type values, modeled as forward-compatible string
//  wrappers: any unrecognized value still decodes (as itself) instead of
//  throwing, while the documented values are available as typed constants and
//  the "is it finished?" logic lives in one place.
//

import Foundation

/// A `String`-backed value that decodes/encodes as a bare JSON string and keeps
/// any unrecognized value verbatim (forward-compatible with new CircleCI states).
public protocol StringWrapped: RawRepresentable, Codable, Hashable, CustomStringConvertible where RawValue == String {
    init(rawValue: String)
}

public extension StringWrapped {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self.init(rawValue: raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var description: String { rawValue }
}

/// Pipeline `.state` — describes creation, not pass/fail.
public struct PipelineState: StringWrapped {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let created = PipelineState(rawValue: "created")
    public static let errored = PipelineState(rawValue: "errored")
    public static let setupPending = PipelineState(rawValue: "setup-pending")
    public static let setup = PipelineState(rawValue: "setup")
    public static let pending = PipelineState(rawValue: "pending")

    /// A pipeline stops changing state once it is created or errored.
    public var isFinished: Bool {
        self == .created || self == .errored
    }
}

/// Workflow `.status`.
public struct WorkflowStatus: StringWrapped {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let success = WorkflowStatus(rawValue: "success")
    public static let running = WorkflowStatus(rawValue: "running")
    public static let notRun = WorkflowStatus(rawValue: "not_run")
    public static let failed = WorkflowStatus(rawValue: "failed")
    public static let error = WorkflowStatus(rawValue: "error")
    public static let failing = WorkflowStatus(rawValue: "failing")
    public static let onHold = WorkflowStatus(rawValue: "on_hold")
    public static let canceled = WorkflowStatus(rawValue: "canceled")
    public static let unauthorized = WorkflowStatus(rawValue: "unauthorized")

    private static let finished: Set<WorkflowStatus> = [
        .success, .failed, .error, .canceled, .notRun, .unauthorized
    ]

    /// True once the workflow has stopped running (terminal status).
    public var isFinished: Bool { Self.finished.contains(self) }

    /// True while the workflow is still progressing or waiting for approval.
    public var isRunning: Bool { !isFinished }
}

/// Job `.status`.
public struct JobStatus: StringWrapped {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let success = JobStatus(rawValue: "success")
    public static let running = JobStatus(rawValue: "running")
    public static let notRun = JobStatus(rawValue: "not_run")
    public static let failed = JobStatus(rawValue: "failed")
    public static let retried = JobStatus(rawValue: "retried")
    public static let queued = JobStatus(rawValue: "queued")
    public static let notRunning = JobStatus(rawValue: "not_running")
    public static let infrastructureFail = JobStatus(rawValue: "infrastructure_fail")
    public static let timedout = JobStatus(rawValue: "timedout")
    public static let onHold = JobStatus(rawValue: "on_hold")
    public static let terminatedUnknown = JobStatus(rawValue: "terminated-unknown")
    public static let blocked = JobStatus(rawValue: "blocked")
    public static let canceled = JobStatus(rawValue: "canceled")
    public static let unauthorized = JobStatus(rawValue: "unauthorized")

    private static let finished: Set<JobStatus> = [
        .success, .failed, .notRun, .retried, .infrastructureFail,
        .timedout, .terminatedUnknown, .canceled, .unauthorized
    ]

    /// True once the job has stopped running (terminal status).
    public var isFinished: Bool { Self.finished.contains(self) }

    /// The statuses that count as a genuine failure. `not_run` and `retried`
    /// are deliberately excluded: a skipped or superseded job is ignored, not
    /// a failure.
    private static let failures: Set<JobStatus> = [
        .failed, .infrastructureFail, .timedout, .terminatedUnknown, .canceled, .unauthorized
    ]

    /// True when the job ended in a genuine failure (so `watch` exits 1).
    public var isFailure: Bool { Self.failures.contains(self) }
}

/// Job `.type` — distinguishes a normal build job from a manual-approval gate.
public struct JobType: StringWrapped {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let build = JobType(rawValue: "build")
    public static let approval = JobType(rawValue: "approval")
}
