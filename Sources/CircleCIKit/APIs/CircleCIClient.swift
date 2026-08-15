//
//  CircleCIClient.swift
//  cirqueduci
//
//  The high-level facade (mirrors hunch's HunchAPI role): wraps CircleCIAPI,
//  owns pagination, and `throws` typed errors. This is the primary entry point
//  the CLI and higher-level code use. Pagination lives ONLY here; the low-level
//  client returns one page.
//

import Foundation

public final class CircleCIClient {

    /// Convenience singleton for the CLI target.
    public static let shared = CircleCIClient(api: .shared)

    public let api: CircleCIAPI

    public init(api: CircleCIAPI) {
        self.api = api
    }

    /// Convenience: build a client over a fresh low-level API with the given
    /// transport/token (used by tests).
    public convenience init(transport: HTTPTransport, token: String? = "test-token") {
        self.init(api: CircleCIAPI(transport: transport, token: token))
    }

    // MARK: - Result helpers

    private func unwrap<T>(_ result: Result<T, CircleCIError>) throws -> T {
        switch result {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    /// Walks a paginated endpoint, following `next_page_token` until it is
    /// absent/empty or `limit` items have been collected.
    private func collect<T>(limit: Int,
                            _ fetchPage: (_ pageToken: String?) async -> Result<Paged<T>, CircleCIError>) async throws -> [T] {
        var items: [T] = []
        var pageToken: String?
        repeat {
            let page = try unwrap(await fetchPage(pageToken))
            for item in page.items {
                items.append(item)
                if items.count >= limit { return items }
            }
            if let next = page.nextPageToken, !next.isEmpty {
                pageToken = next
            } else {
                pageToken = nil
            }
        } while pageToken != nil
        return items
    }

    // MARK: - Identity

    public func me() async throws -> Me {
        try unwrap(await api.me())
    }

    public func collaborations() async throws -> [Collaboration] {
        try unwrap(await api.collaborations())
    }

    // MARK: - Projects

    public func followedProjects() async throws -> [FollowedProject] {
        try unwrap(await api.followedProjects())
    }

    public func project(slug: String) async throws -> Project {
        try unwrap(await api.project(slug: slug))
    }

    // MARK: - Pipelines

    public func pipelines(projectSlug: String, branch: String? = nil, limit: Int = .max) async throws -> [Pipeline] {
        try await collect(limit: limit) { pageToken in
            await api.pipelines(projectSlug: projectSlug, branch: branch, pageToken: pageToken)
        }
    }

    public func pipelines(orgSlug: String, mine: Bool = false, limit: Int = .max) async throws -> [Pipeline] {
        try await collect(limit: limit) { pageToken in
            await api.pipelinesForOrg(orgSlug: orgSlug, mine: mine, pageToken: pageToken)
        }
    }

    public func pipeline(id: String) async throws -> Pipeline {
        try unwrap(await api.pipeline(id: id))
    }

    public func triggerPipeline(projectSlug: String,
                                branch: String? = nil,
                                tag: String? = nil,
                                parameters: [String: ParameterValue]? = nil) async throws -> TriggerPipelineResponse {
        let request = TriggerPipelineRequest(branch: branch, tag: tag, parameters: parameters)
        return try unwrap(await api.triggerPipeline(projectSlug: projectSlug, request: request))
    }

    // MARK: - Workflows

    public func workflows(pipelineId: String, limit: Int = .max) async throws -> [Workflow] {
        try await collect(limit: limit) { pageToken in
            await api.workflows(pipelineId: pipelineId, pageToken: pageToken)
        }
    }

    public func workflow(id: String) async throws -> Workflow {
        try unwrap(await api.workflow(id: id))
    }

    @discardableResult
    public func cancelWorkflow(id: String) async throws -> MessageResponse {
        try unwrap(await api.cancelWorkflow(id: id))
    }

    @discardableResult
    public func rerunWorkflow(id: String) async throws -> MessageResponse {
        try unwrap(await api.rerunWorkflow(id: id))
    }

    // MARK: - Jobs

    public func jobs(workflowId: String, limit: Int = .max) async throws -> [Job] {
        try await collect(limit: limit) { pageToken in
            await api.jobs(workflowId: workflowId, pageToken: pageToken)
        }
    }

    /// The manual-approval gates in a workflow currently awaiting a human.
    public func approvableJobs(workflowId: String) async throws -> [Job] {
        try await jobs(workflowId: workflowId).filter { $0.isApprovable }
    }

    @discardableResult
    public func approveJob(workflowId: String, approvalRequestId: String) async throws -> MessageResponse {
        try unwrap(await api.approveJob(workflowId: workflowId, approvalRequestId: approvalRequestId))
    }

    /// Finds an approvable job in a workflow by name (or the sole gate when
    /// `name` is nil) and approves it. Returns the job that was approved.
    @discardableResult
    public func approveJob(workflowId: String, named name: String?) async throws -> Job {
        let gates = try await approvableJobs(workflowId: workflowId)
        let target: Job
        if let name = name {
            guard let match = gates.first(where: { $0.name == name }) else {
                throw CircleCIError.invalidResponseStatus(404, message: "no approvable job named \"\(name)\" in workflow \(workflowId)")
            }
            target = match
        } else {
            guard gates.count == 1, let only = gates.first else {
                let names = gates.map { $0.name }.joined(separator: ", ")
                throw CircleCIError.invalidResponseStatus(400, message: "expected exactly one approvable job; found: [\(names)] — pass a job name")
            }
            target = only
        }
        _ = try await approveJob(workflowId: workflowId, approvalRequestId: target.effectiveApprovalRequestId)
        return target
    }

    public func jobDetail(projectSlug: String, jobNumber: Int) async throws -> JobDetail {
        try unwrap(await api.jobDetail(projectSlug: projectSlug, jobNumber: jobNumber))
    }

    /// The per-step breakdown of a job. `projectSlug` is the v2 form
    /// (`gh/org/repo`); it is converted to the v1.1 form (`github/org/repo`).
    public func jobSteps(projectSlug: String, jobNumber: Int) async throws -> [Step] {
        let vcsSlug = ProjectSlug.toV11(projectSlug)
        return try unwrap(await api.jobSteps(vcsSlug: vcsSlug, jobNumber: jobNumber)).steps
    }

    // MARK: - Artifacts & Tests

    public func artifacts(projectSlug: String, jobNumber: Int, limit: Int = .max) async throws -> [Artifact] {
        try await collect(limit: limit) { pageToken in
            await api.artifacts(projectSlug: projectSlug, jobNumber: jobNumber, pageToken: pageToken)
        }
    }

    public func tests(projectSlug: String, jobNumber: Int, limit: Int = .max) async throws -> [TestResult] {
        try await collect(limit: limit) { pageToken in
            await api.tests(projectSlug: projectSlug, jobNumber: jobNumber, pageToken: pageToken)
        }
    }

    // MARK: - Logs & downloads

    /// Fetches and concatenates a job's step logs into plain text.
    public func stepLog(outputURL: URL) async throws -> [LogLine] {
        try unwrap(await api.stepLog(outputURL: outputURL))
    }

    public func downloadData(from url: URL) async throws -> Data {
        try unwrap(await api.downloadData(from: url))
    }
}

/// Helpers for converting between the v2 project slug (`gh/org/repo`) and the
/// v1.1 vcs slug (`github/org/repo`).
public enum ProjectSlug {
    /// Converts a v2 slug (`gh/org/repo` or `bb/org/repo`) to the v1.1 long form
    /// (`github/org/repo`, `bitbucket/org/repo`). Already-long forms pass through.
    public static func toV11(_ slug: String) -> String {
        let parts = slug.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return slug }
        let vcs: String
        switch parts[0].lowercased() {
        case "gh": vcs = "github"
        case "bb": vcs = "bitbucket"
        default: vcs = parts[0]
        }
        return "\(vcs)/\(parts[1])"
    }
}
