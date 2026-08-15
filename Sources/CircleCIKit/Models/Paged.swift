//
//  Paged.swift
//  cirqueduci
//
//  The shared pagination envelope every CircleCI v2 list endpoint returns:
//  `{ "items": [...], "next_page_token": string|null }`. Mirrors hunch's
//  per-list `PageList`/`BlockList` shape, generalized to one generic type.
//

import Foundation

public struct Paged<Item: Codable>: Codable {
    public let items: [Item]
    public let nextPageToken: String?

    public init(items: [Item], nextPageToken: String?) {
        self.items = items
        self.nextPageToken = nextPageToken
    }

    enum CodingKeys: String, CodingKey {
        case items
        case nextPageToken = "next_page_token"
    }
}
