//
//  Job.swift
//  cirqueduci
//
//  A job as listed by GET /workflow/{id}/job. Build jobs carry a `job_number`;
//  manual-approval gates carry `type == "approval"`, `status == "on_hold"`, and
//  an `approval_request_id` (the id you POST to approve the workflow).
//

import Foundation

public struct Job: Codable, Identifiable {
    public let id: String
    public let name: String
    public let type: JobType
    public let status: JobStatus
    public let jobNumber: Int?
    public let approvalRequestId: String?
    public let dependencies: [String]
    public let startedAt: Date?
    public let stoppedAt: Date?
    public let projectSlug: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case status
        case jobNumber = "job_number"
        case approvalRequestId = "approval_request_id"
        case dependencies
        case startedAt = "started_at"
        case stoppedAt = "stopped_at"
        case projectSlug = "project_slug"
    }

    public init(id: String, name: String, type: JobType, status: JobStatus,
                jobNumber: Int?, approvalRequestId: String?, dependencies: [String],
                startedAt: Date?, stoppedAt: Date?, projectSlug: String?) {
        self.id = id
        self.name = name
        self.type = type
        self.status = status
        self.jobNumber = jobNumber
        self.approvalRequestId = approvalRequestId
        self.dependencies = dependencies
        self.startedAt = startedAt
        self.stoppedAt = stoppedAt
        self.projectSlug = projectSlug
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(JobType.self, forKey: .type)
        status = try container.decode(JobStatus.self, forKey: .status)
        jobNumber = try container.decodeIfPresent(Int.self, forKey: .jobNumber)
        approvalRequestId = try container.decodeIfPresent(String.self, forKey: .approvalRequestId)
        dependencies = try container.decodeIfPresent([String].self, forKey: .dependencies) ?? []
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        stoppedAt = try container.decodeIfPresent(Date.self, forKey: .stoppedAt)
        projectSlug = try container.decodeIfPresent(String.self, forKey: .projectSlug)
    }

    /// True when this job is a manual-approval gate currently waiting for a
    /// human — i.e. an approvable job in the CLI's `approve` command.
    public var isApprovable: Bool {
        type == .approval && status == .onHold
    }

    /// The id to POST to the approve endpoint. Prefer the explicit
    /// `approval_request_id` field; fall back to the job id (historically equal)
    /// only when the field is absent.
    public var effectiveApprovalRequestId: String {
        approvalRequestId ?? id
    }
}
