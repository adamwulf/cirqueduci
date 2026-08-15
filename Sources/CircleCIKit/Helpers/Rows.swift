//
//  Rows.swift
//  cirqueduci
//
//  CircleCIRow conformances — table columns / id for each listable model. Kept
//  separate so the model files stay focused on decoding.
//

import Foundation

private func short(_ date: Date?) -> String {
    guard let date = date else { return "-" }
    return CircleCIDate.string(from: date)
}

private func nonEmpty(_ value: String?) -> String {
    guard let value = value, !value.isEmpty else { return "-" }
    return value
}

extension FollowedProject: CircleCIRow {
    public static var tableColumns: [String] { ["SLUG", "REPO", "FOLLOWING", "DEFAULT_BRANCH"] }
    public var tableValues: [String] {
        [slug, "\(username)/\(reponame)", (following ?? false) ? "yes" : "no", nonEmpty(defaultBranch)]
    }
    public var idValue: String { slug }
}

extension Project: CircleCIRow {
    public static var tableColumns: [String] { ["SLUG", "NAME", "ORG", "DEFAULT_BRANCH"] }
    public var tableValues: [String] {
        [slug, name, nonEmpty(organizationName), nonEmpty(vcsInfo?.defaultBranch)]
    }
    public var idValue: String { id }
}

extension Pipeline: CircleCIRow {
    public static var tableColumns: [String] { ["NUMBER", "STATE", "BRANCH", "REVISION", "CREATED", "ID"] }
    public var tableValues: [String] {
        [
            number.map(String.init) ?? "-",
            state.rawValue,
            nonEmpty(vcs?.branch ?? vcs?.tag),
            String((vcs?.revision ?? "").prefix(8)),
            short(createdAt),
            id
        ]
    }
    public var idValue: String { id }
}

extension Workflow: CircleCIRow {
    public static var tableColumns: [String] { ["NAME", "STATUS", "CREATED", "ID"] }
    public var tableValues: [String] {
        [name, status.rawValue, short(createdAt), id]
    }
    public var idValue: String { id }
}

extension Job: CircleCIRow {
    public static var tableColumns: [String] { ["NAME", "TYPE", "STATUS", "JOB_NUMBER", "ID"] }
    public var tableValues: [String] {
        [name, type.rawValue, status.rawValue, jobNumber.map(String.init) ?? "-", id]
    }
    public var idValue: String { id }
}

extension JobDetail: CircleCIRow {
    public static var tableColumns: [String] { ["NUMBER", "NAME", "STATUS", "DURATION_MS", "WEB_URL"] }
    public var tableValues: [String] {
        [String(number), nonEmpty(name), status.rawValue, duration.map(String.init) ?? "-", nonEmpty(webURL)]
    }
    public var idValue: String { String(number) }
}

extension Step: CircleCIRow {
    public static var tableColumns: [String] { ["STEP", "NAME", "STATUS", "EXIT", "TYPE"] }
    public var tableValues: [String] {
        let action = actions.first
        return [
            action?.step.map(String.init) ?? "-",
            name,
            action?.status?.rawValue ?? "-",
            action?.exitCode.map(String.init) ?? "-",
            nonEmpty(action?.type)
        ]
    }
    public var idValue: String { name }
}

extension Artifact: CircleCIRow {
    public static var tableColumns: [String] { ["PATH", "NODE", "URL"] }
    public var tableValues: [String] {
        [path, nodeIndex.map(String.init) ?? "-", url]
    }
    public var idValue: String { path }
}

extension TestResult: CircleCIRow {
    public static var tableColumns: [String] { ["RESULT", "CLASSNAME", "NAME", "TIME"] }
    public var tableValues: [String] {
        [nonEmpty(result), nonEmpty(classname), nonEmpty(name), runTime.map { String(format: "%.3f", $0) } ?? "-"]
    }
    public var idValue: String { [classname, name].compactMap { $0 }.joined(separator: ".") }
}

extension Collaboration: CircleCIRow {
    public static var tableColumns: [String] { ["SLUG", "NAME", "VCS_TYPE"] }
    public var tableValues: [String] {
        [nonEmpty(slug), nonEmpty(name), nonEmpty(vcsType)]
    }
    public var idValue: String { slug ?? name ?? (id ?? "-") }
}

extension Me: CircleCIRow {
    public static var tableColumns: [String] { ["ID", "LOGIN", "NAME"] }
    public var tableValues: [String] {
        [id, nonEmpty(login), nonEmpty(name)]
    }
    public var idValue: String { id }
}

extension TriggerPipelineResponse: CircleCIRow {
    public static var tableColumns: [String] { ["NUMBER", "STATE", "CREATED", "ID"] }
    public var tableValues: [String] {
        [number.map(String.init) ?? "-", state?.rawValue ?? "-", short(createdAt), id]
    }
    public var idValue: String { id }
}
