//
//  Workflow.swift
//  cirqueduci
//
//  Response shape for GET /pipeline/{id}/workflow (items) and GET /workflow/{id}.
//

import Foundation

public struct Workflow: Codable, Identifiable {
    public let id: String
    public let name: String
    public let status: WorkflowStatus
    public let pipelineId: String?
    public let pipelineNumber: Int?
    public let projectSlug: String?
    public let startedBy: String?
    public let createdAt: Date?
    public let stoppedAt: Date?
    public let canceledBy: String?
    public let erroredBy: String?
    public let tag: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case pipelineId = "pipeline_id"
        case pipelineNumber = "pipeline_number"
        case projectSlug = "project_slug"
        case startedBy = "started_by"
        case createdAt = "created_at"
        case stoppedAt = "stopped_at"
        case canceledBy = "canceled_by"
        case erroredBy = "errored_by"
        case tag
    }
}
