//
//  CircleCIClient+Logs.swift
//  cirqueduci
//
//  Assembling a job's logs (fetch its steps, then each step action's pre-signed
//  output_url) is real logic, so it lives in the library — the CLI just prints
//  the result.
//

import Foundation

/// The log output of a single step action.
public struct StepLog {
    public let step: String
    public let actionName: String?
    public let actionIndex: Int
    public let type: String?
    public let lines: [LogLine]

    /// The concatenated plain-text log for this action.
    public var text: String {
        lines.map { $0.message }.joined()
    }
}

extension CircleCIClient {

    /// Fetches a build job's step logs. Pass `stepName` to limit to one step.
    /// Actions without an `output_url` (e.g. approval-only steps) are skipped.
    public func jobLogs(projectSlug: String, jobNumber: Int, stepName: String? = nil) async throws -> [StepLog] {
        let steps = try await jobSteps(projectSlug: projectSlug, jobNumber: jobNumber)
        var result: [StepLog] = []
        for step in steps {
            if let stepName = stepName, step.name != stepName { continue }
            for action in step.actions {
                guard let output = action.outputURL, let url = URL(string: output) else { continue }
                let lines = try await stepLog(outputURL: url)
                result.append(StepLog(step: step.name,
                                      actionName: action.name,
                                      actionIndex: action.index,
                                      type: action.type,
                                      lines: lines))
            }
        }
        return result
    }
}
