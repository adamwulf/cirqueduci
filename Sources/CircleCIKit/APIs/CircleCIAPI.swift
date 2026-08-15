//
//  CircleCIAPI.swift
//  cirqueduci
//
//  The low-level CircleCI client (mirrors hunch's NotionAPI role): holds the
//  token and the injectable HTTP transport, builds each request with the
//  Circle-Token header, and returns ONE page as Result<Model, CircleCIError>.
//  Retry/backoff for 429/5xx lives here; pagination lives in the facade
//  (CircleCIClient). Unlike hunch's private-init singleton, the initializer is
//  public and takes the transport so tests can inject canned JSON offline.
//

import Foundation

public final class CircleCIAPI {

    /// Convenience singleton for the CLI target (real transport + resolved token).
    public static let shared = CircleCIAPI()

    /// Optional log hook: (level, message, context). Mirrors hunch's logHandler.
    public static var logHandler: ((_ level: String, _ message: String, _ context: [String: Any]?) -> Void)?

    public var token: String?
    private let transport: HTTPTransport

    private let baseV2: String
    private let baseV11: String

    private let maxRetries = 3
    private let minRetryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 60.0

    public init(transport: HTTPTransport = URLSessionTransport(),
                token: String? = TokenResolver.fromEnvironment(),
                baseV2: String = "https://circleci.com/api/v2",
                baseV11: String = "https://circleci.com/api/v1.1") {
        self.transport = transport
        self.token = token
        self.baseV2 = baseV2
        self.baseV11 = baseV11
    }

    // MARK: - URL building

    private func makeURL(base: String, path: String, query: [String: String]) -> URL? {
        var urlString = base
        if !path.isEmpty {
            urlString += "/" + path
        }
        guard var components = URLComponents(string: urlString) else { return nil }
        if !query.isEmpty {
            components.queryItems = query
                .sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.url
    }

    // MARK: - Request core

    /// Issues a request (with retry/backoff) and returns the raw response.
    /// A missing token short-circuits to `.missingToken` before any network,
    /// unless `authenticated` is false (used for pre-signed downloads).
    func send(method: String = "GET",
              url: URL,
              body: Data? = nil,
              authenticated: Bool = true,
              retryCount: Int = 0) async -> Result<HTTPResponse, CircleCIError> {
        var headers: [String: String] = [
            "Accept": "application/json"
        ]
        if authenticated {
            guard let token = token, !token.isEmpty else {
                return .failure(.missingToken)
            }
            headers["Circle-Token"] = token
        }
        if body != nil {
            headers["Content-Type"] = "application/json"
        }

        let request = HTTPRequest(method: method, url: url, headers: headers, body: body)

        let response: HTTPResponse
        do {
            response = try await transport.send(request)
        } catch {
            return .failure(.apiError(error))
        }

        if response.status == 429 || (500...599).contains(response.status) {
            if retryCount < maxRetries {
                let retryAfter = TimeInterval(response.headers["Retry-After"] ?? "") ?? 0
                let backoff = min(maxRetryDelay, minRetryDelay * pow(2.0, Double(retryCount)))
                let delay = max(retryAfter, backoff)
                Self.logHandler?("error", "\(response.status) error, retrying after \(delay)s",
                                 ["attempt": retryCount + 1, "status": response.status, "url": url.absoluteString])
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                return await send(method: method, url: url, body: body,
                                  authenticated: authenticated, retryCount: retryCount + 1)
            }
        }

        guard (200..<300).contains(response.status) else {
            let message = String(data: response.body, encoding: .utf8)
            Self.logHandler?("error", "CircleCI API error", ["status": response.status, "url": url.absoluteString])
            return .failure(.invalidResponseStatus(response.status, message: message))
        }

        Self.logHandler?("debug", "circleci_api", ["status": response.status, "url": url.absoluteString])
        return .success(response)
    }

    /// Issues a request and decodes the JSON body as `T`.
    func fetch<T: Decodable>(_ type: T.Type = T.self,
                             method: String = "GET",
                             url: URL,
                             body: Data? = nil,
                             authenticated: Bool = true) async -> Result<T, CircleCIError> {
        let result = await send(method: method, url: url, body: body, authenticated: authenticated)
        switch result {
        case .success(let response):
            if response.body.isEmpty {
                return .failure(.noData)
            }
            do {
                let value = try CircleCIJSON.decoder.decode(T.self, from: response.body)
                return .success(value)
            } catch {
                return .failure(.decodeError(error, context: url.path))
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    private func encode<T: Encodable>(_ value: T) -> Result<Data, CircleCIError> {
        do {
            return .success(try CircleCIJSON.encoder.encode(value))
        } catch {
            return .failure(.encodeError(error))
        }
    }

    // MARK: - Identity

    public func me() async -> Result<Me, CircleCIError> {
        guard let url = makeURL(base: baseV2, path: "me", query: [:]) else {
            return .failure(.invalidEndpoint)
        }
        return await fetch(url: url)
    }

    public func collaborations() async -> Result<[Collaboration], CircleCIError> {
        guard let url = makeURL(base: baseV2, path: "me/collaborations", query: [:]) else {
            return .failure(.invalidEndpoint)
        }
        return await fetch(url: url)
    }

    // MARK: - Projects

    /// Followed projects (v1.1; returns a bare array, not a paged envelope).
    public func followedProjects() async -> Result<[FollowedProject], CircleCIError> {
        guard let url = makeURL(base: baseV11, path: "projects", query: [:]) else {
            return .failure(.invalidEndpoint)
        }
        return await fetch(url: url)
    }

    public func project(slug: String) async -> Result<Project, CircleCIError> {
        guard let url = makeURL(base: baseV2, path: "project/\(slug)", query: [:]) else {
            return .failure(.invalidEndpoint)
        }
        return await fetch(url: url)
    }

    // MARK: - Pipelines

    public func pipelines(projectSlug: String, branch: String?, pageToken: String?) async -> Result<Paged<Pipeline>, CircleCIError> {
        var query: [String: String] = [:]
        if let branch = branch { query["branch"] = branch }
        if let pageToken = pageToken { query["page-token"] = pageToken }
        guard let url = makeURL(base: baseV2, path: "project/\(projectSlug)/pipeline", query: query) else {
            return .failure(.invalidEndpoint)
        }
        return await fetch(url: url)
    }

    public func pipelinesForOrg(orgSlug: String, mine: Bool, pageToken: String?) async -> Result<Paged<Pipeline>, CircleCIError> {
        var query: [String: String] = ["org-slug": orgSlug]
        if mine { query["mine"] = "true" }
        if let pageToken = pageToken { query["page-token"] = pageToken }
        guard let url = makeURL(base: baseV2, path: "pipeline", query: query) else {
            return .failure(.invalidEndpoint)
        }
        return await fetch(url: url)
    }

    public func pipeline(id: String) async -> Result<Pipeline, CircleCIError> {
        guard let url = makeURL(base: baseV2, path: "pipeline/\(id)", query: [:]) else {
            return .failure(.invalidEndpoint)
        }
        return await fetch(url: url)
    }

    public func triggerPipeline(projectSlug: String, request: TriggerPipelineRequest) async -> Result<TriggerPipelineResponse, CircleCIError> {
        guard let url = makeURL(base: baseV2, path: "project/\(projectSlug)/pipeline", query: [:]) else {
            return .failure(.invalidEndpoint)
        }
        switch encode(request) {
        case .success(let data):
            return await fetch(method: "POST", url: url, body: data)
        case .failure(let error):
            return .failure(error)
        }
    }

    // MARK: - Workflows

    public func workflows(pipelineId: String, pageToken: String?) async -> Result<Paged<Workflow>, CircleCIError> {
        var query: [String: String] = [:]
        if let pageToken = pageToken { query["page-token"] = pageToken }
        guard let url = makeURL(base: baseV2, path: "pipeline/\(pipelineId)/workflow", query: query) else {
            return .failure(.invalidEndpoint)
        }
        return await fetch(url: url)
    }

    public func workflow(id: String) async -> Result<Workflow, CircleCIError> {
        guard let url = makeURL(base: baseV2, path: "workflow/\(id)", query: [:]) else {
            return .failure(.invalidEndpoint)
        }
        return await fetch(url: url)
    }

    public func cancelWorkflow(id: String) async -> Result<MessageResponse, CircleCIError> {
        guard let url = makeURL(base: baseV2, path: "workflow/\(id)/cancel", query: [:]) else {
            return .failure(.invalidEndpoint)
        }
        return await fetch(method: "POST", url: url)
    }

    public func rerunWorkflow(id: String) async -> Result<MessageResponse, CircleCIError> {
        guard let url = makeURL(base: baseV2, path: "workflow/\(id)/rerun", query: [:]) else {
            return .failure(.invalidEndpoint)
        }
        return await fetch(method: "POST", url: url)
    }

    // MARK: - Jobs

    public func jobs(workflowId: String, pageToken: String?) async -> Result<Paged<Job>, CircleCIError> {
        var query: [String: String] = [:]
        if let pageToken = pageToken { query["page-token"] = pageToken }
        guard let url = makeURL(base: baseV2, path: "workflow/\(workflowId)/job", query: query) else {
            return .failure(.invalidEndpoint)
        }
        return await fetch(url: url)
    }

    public func approveJob(workflowId: String, approvalRequestId: String) async -> Result<MessageResponse, CircleCIError> {
        guard let url = makeURL(base: baseV2, path: "workflow/\(workflowId)/approve/\(approvalRequestId)", query: [:]) else {
            return .failure(.invalidEndpoint)
        }
        return await fetch(method: "POST", url: url)
    }

    public func jobDetail(projectSlug: String, jobNumber: Int) async -> Result<JobDetail, CircleCIError> {
        guard let url = makeURL(base: baseV2, path: "project/\(projectSlug)/job/\(jobNumber)", query: [:]) else {
            return .failure(.invalidEndpoint)
        }
        return await fetch(url: url)
    }

    /// Per-step breakdown (v1.1). `vcsSlug` uses the long form, e.g.
    /// `github/museapphq/Muse`.
    public func jobSteps(vcsSlug: String, jobNumber: Int) async -> Result<JobStepsResponse, CircleCIError> {
        guard let url = makeURL(base: baseV11, path: "project/\(vcsSlug)/\(jobNumber)", query: [:]) else {
            return .failure(.invalidEndpoint)
        }
        return await fetch(url: url)
    }

    // MARK: - Artifacts & Tests

    public func artifacts(projectSlug: String, jobNumber: Int, pageToken: String?) async -> Result<Paged<Artifact>, CircleCIError> {
        var query: [String: String] = [:]
        if let pageToken = pageToken { query["page-token"] = pageToken }
        guard let url = makeURL(base: baseV2, path: "project/\(projectSlug)/\(jobNumber)/artifacts", query: query) else {
            return .failure(.invalidEndpoint)
        }
        return await fetch(url: url)
    }

    public func tests(projectSlug: String, jobNumber: Int, pageToken: String?) async -> Result<Paged<TestResult>, CircleCIError> {
        var query: [String: String] = [:]
        if let pageToken = pageToken { query["page-token"] = pageToken }
        guard let url = makeURL(base: baseV2, path: "project/\(projectSlug)/\(jobNumber)/tests", query: query) else {
            return .failure(.invalidEndpoint)
        }
        return await fetch(url: url)
    }

    // MARK: - Raw downloads (step logs, artifacts)

    /// Fetches raw bytes from an arbitrary URL (e.g. a pre-signed step
    /// `output_url` or an artifact URL). Sends the Circle-Token only when the
    /// host is circleci.com; pre-signed S3/artifact URLs need no auth.
    public func downloadData(from url: URL) async -> Result<Data, CircleCIError> {
        let needsAuth = (url.host ?? "").hasSuffix("circleci.com")
        let result = await send(url: url, authenticated: needsAuth)
        return result.map { $0.body }
    }

    /// Fetches a step action's log lines from its pre-signed `output_url`.
    public func stepLog(outputURL: URL) async -> Result<[LogLine], CircleCIError> {
        let needsAuth = (outputURL.host ?? "").hasSuffix("circleci.com")
        return await fetch([LogLine].self, url: outputURL, authenticated: needsAuth)
    }
}
