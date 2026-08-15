//
//  Project.swift
//  cirqueduci
//
//  GET /project/{slug} (v2) and GET /api/v1.1/projects (the followed-projects
//  list, which has no v2 equivalent).
//

import Foundation

/// A project as returned by the v2 GET /project/{slug} endpoint.
public struct Project: Codable, Identifiable {
    public let id: String
    public let slug: String
    public let name: String
    public let organizationName: String?
    public let organizationSlug: String?
    public let organizationId: String?
    public let vcsInfo: VCSInfo?

    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case name
        case organizationName = "organization_name"
        case organizationSlug = "organization_slug"
        case organizationId = "organization_id"
        case vcsInfo = "vcs_info"
    }

    public struct VCSInfo: Codable {
        public let vcsURL: String?
        public let provider: String?
        public let defaultBranch: String?

        enum CodingKeys: String, CodingKey {
            case vcsURL = "vcs_url"
            case provider
            case defaultBranch = "default_branch"
        }
    }
}

/// A project as returned by the v1.1 GET /projects endpoint (the only source of
/// "followed" projects). The `slug` is synthesized so the CLI can feed it to v2
/// endpoints.
public struct FollowedProject: Codable {
    public let vcsURL: String
    public let vcsType: String
    public let username: String
    public let reponame: String
    public let following: Bool?
    public let defaultBranch: String?

    enum CodingKeys: String, CodingKey {
        case vcsURL = "vcs_url"
        case vcsType = "vcs_type"
        case username
        case reponame
        case following
        case defaultBranch = "default_branch"
    }

    /// The v2 project slug (e.g. `gh/museapphq/Muse`) derived from the v1.1 vcs
    /// type + owner + repo. `github` maps to the `gh` short form v2 uses.
    public var slug: String {
        let prefix: String
        switch vcsType.lowercased() {
        case "github": prefix = "gh"
        case "bitbucket": prefix = "bb"
        default: prefix = vcsType.lowercased()
        }
        return "\(prefix)/\(username)/\(reponame)"
    }
}
