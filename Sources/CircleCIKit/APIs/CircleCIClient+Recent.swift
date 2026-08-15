//
//  CircleCIClient+Recent.swift
//  cirqueduci
//
//  "What has been happening lately?" — the CircleCI API has no single endpoint
//  for it, so the walk (recent pipelines → each one's workflows → a status
//  rollup) is real library logic. The CLI's `recent` command is a thin caller.
//

import Foundation

/// A pipeline paired with its current workflows — the unit the `recent`
/// overview lists. One row per pipeline, with a rollup of its workflow statuses.
public struct PipelineActivity: Encodable {
    public let pipeline: Pipeline
    public let workflows: [Workflow]

    public init(pipeline: Pipeline, workflows: [Workflow]) {
        self.pipeline = pipeline
        self.workflows = workflows
    }

    /// True while at least one workflow is still progressing or awaiting approval.
    public var isActive: Bool {
        workflows.contains { $0.status.isRunning }
    }

    /// A compact rollup of the workflow statuses, most-active first, e.g.
    /// `2 running, 1 on_hold, 1 success`. `no workflows` when the pipeline
    /// matched no workflow filter (e.g. a bare tag push).
    public var workflowSummary: String {
        guard !workflows.isEmpty else { return "no workflows" }
        var counts: [String: Int] = [:]
        for workflow in workflows {
            counts[workflow.status.rawValue, default: 0] += 1
        }
        // Surface in-progress states first so "what's running" is obvious.
        let priority = ["running", "failing", "on_hold", "failed", "error",
                        "canceled", "unauthorized", "success", "not_run"]
        let ranked = priority.compactMap { status -> String? in
            guard let count = counts[status] else { return nil }
            return "\(count) \(status)"
        }
        let extras = counts.keys
            .filter { !priority.contains($0) }
            .sorted()
            .map { "\(counts[$0]!) \($0)" }
        return (ranked + extras).joined(separator: ", ")
    }
}

extension CircleCIClient {

    /// Pipelines among the most recently created `maxPipelines` whose activity
    /// (`updated_at`, falling back to `created_at`) is at or after `since`, each
    /// paired with its current workflows, newest first.
    ///
    /// The list endpoint is ordered by pipeline creation, not by update, so a
    /// recently *re-run* old pipeline can sit far down the list. We therefore
    /// cannot stop at the first out-of-window entry — we scan up to
    /// `maxPipelines` and filter each independently. `maxPipelines` bounds how
    /// far back (in creation order) that scan reaches.
    public func recentActivity(projectSlug: String,
                               since: Date,
                               maxPipelines: Int = 50) async throws -> [PipelineActivity] {
        guard maxPipelines > 0 else { return [] }

        // 1. Scan the newest `maxPipelines` pipelines, keeping those active since
        //    `since`. Every inspected pipeline counts toward the scan cap.
        var recent: [Pipeline] = []
        var scanned = 0
        var pageToken: String?
        paging: repeat {
            let page = try (await api.pipelines(projectSlug: projectSlug,
                                                branch: nil,
                                                pageToken: pageToken)).get()
            for pipeline in page.items {
                let stamp = pipeline.updatedAt ?? pipeline.createdAt
                if let stamp = stamp, stamp >= since {
                    recent.append(pipeline)
                }
                scanned += 1
                if scanned >= maxPipelines { break paging }
            }
            pageToken = (page.nextPageToken?.isEmpty == false) ? page.nextPageToken : nil
        } while pageToken != nil

        // 2. Attach each kept pipeline's workflows.
        var activity: [PipelineActivity] = []
        for pipeline in recent {
            let workflows = try await self.workflows(pipelineId: pipeline.id)
            activity.append(PipelineActivity(pipeline: pipeline, workflows: workflows))
        }
        return activity
    }
}
