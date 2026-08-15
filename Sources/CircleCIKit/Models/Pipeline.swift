//
//  Pipeline.swift
//  cirqueduci
//
//  Response shape for GET /project/{slug}/pipeline, GET /pipeline?org-slug=…,
//  and GET /pipeline/{id}.
//

import Foundation

public struct Pipeline: Codable, Identifiable {
    public let id: String
    public let number: Int?
    public let projectSlug: String?
    public let state: PipelineState
    public let createdAt: Date?
    public let updatedAt: Date?
    public let errors: [PipelineError]
    public let trigger: Trigger?
    public let vcs: VCS?

    enum CodingKeys: String, CodingKey {
        case id
        case number
        case projectSlug = "project_slug"
        case state
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case errors
        case trigger
        case vcs
    }

    public init(id: String, number: Int?, projectSlug: String?, state: PipelineState,
                createdAt: Date?, updatedAt: Date?, errors: [PipelineError],
                trigger: Trigger?, vcs: VCS?) {
        self.id = id
        self.number = number
        self.projectSlug = projectSlug
        self.state = state
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.errors = errors
        self.trigger = trigger
        self.vcs = vcs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        number = try container.decodeIfPresent(Int.self, forKey: .number)
        projectSlug = try container.decodeIfPresent(String.self, forKey: .projectSlug)
        state = try container.decode(PipelineState.self, forKey: .state)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        errors = try container.decodeIfPresent([PipelineError].self, forKey: .errors) ?? []
        trigger = try container.decodeIfPresent(Trigger.self, forKey: .trigger)
        vcs = try container.decodeIfPresent(VCS.self, forKey: .vcs)
    }

    public struct PipelineError: Codable {
        public let type: String
        public let message: String
    }

    public struct Trigger: Codable {
        public let type: String
        public let receivedAt: Date?
        public let actor: Actor?

        enum CodingKeys: String, CodingKey {
            case type
            case receivedAt = "received_at"
            case actor
        }
    }

    public struct Actor: Codable {
        public let login: String?
        public let avatarURL: String?

        enum CodingKeys: String, CodingKey {
            case login
            case avatarURL = "avatar_url"
        }
    }

    public struct VCS: Codable {
        public let providerName: String?
        public let originRepositoryURL: String?
        public let targetRepositoryURL: String?
        public let revision: String?
        public let branch: String?
        public let tag: String?
        public let commit: Commit?

        enum CodingKeys: String, CodingKey {
            case providerName = "provider_name"
            case originRepositoryURL = "origin_repository_url"
            case targetRepositoryURL = "target_repository_url"
            case revision
            case branch
            case tag
            case commit
        }
    }

    public struct Commit: Codable {
        public let subject: String?
        public let body: String?
    }
}
