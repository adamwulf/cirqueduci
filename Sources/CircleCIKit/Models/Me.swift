//
//  Me.swift
//  cirqueduci
//
//  GET /me and GET /me/collaborations — used to bootstrap the CLI (identify the
//  current user and their orgs).
//

import Foundation

public struct Me: Codable, Identifiable {
    public let id: String
    public let login: String?
    public let name: String?
}

public struct Collaboration: Codable {
    public let id: String?
    public let vcsType: String?
    public let name: String?
    public let avatarURL: String?
    public let slug: String?

    enum CodingKeys: String, CodingKey {
        case id
        case vcsType = "vcs-type"
        case name
        case avatarURL = "avatar_url"
        case slug
    }
}
