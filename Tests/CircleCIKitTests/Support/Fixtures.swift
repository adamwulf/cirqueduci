//
//  Fixtures.swift
//  cirqueduci
//
//  Canned CircleCI JSON, kept inline (like hunch's ModelTests). Values are the
//  real ids/names/slug captured read-only from the Muse pipeline by the
//  circle-ci-smoke-test agent; job numbers / page tokens / artifact URLs are
//  illustrative but shape-accurate.
//

enum Fixtures {

    static let me = """
    { "id": "98209bd9-c440-45b0-b1d7-749a15860f58", "login": "adamwulf", "name": "Adam Wulf" }
    """

    static let collaborations = """
    [
      { "id": "0000-org-uuid", "vcs-type": "github", "name": "museapphq",
        "avatar_url": "https://avatars.githubusercontent.com/u/1?v=4", "slug": "gh/museapphq" }
    ]
    """

    static let followedProjects = """
    [
      {
        "vcs_url": "https://github.com/museapphq/Muse",
        "vcs_type": "github",
        "username": "museapphq",
        "reponame": "Muse",
        "following": true,
        "default_branch": "main",
        "branches": { "main": {}, "agent/web-snapshot-selection": {} }
      }
    ]
    """

    static let project = """
    {
      "id": "06a9bd5a-be08-4b9d-86cb-edbb17e5c1c7",
      "slug": "gh/museapphq/Muse",
      "name": "Muse",
      "organization_name": "museapphq",
      "organization_slug": "gh/museapphq",
      "organization_id": "0000-org-uuid",
      "vcs_info": {
        "vcs_url": "https://github.com/museapphq/Muse",
        "provider": "GitHub",
        "default_branch": "main"
      }
    }
    """

    /// A pipeline list page. Its `next_page_token` is null (last page).
    static let pipelinesPage = """
    {
      "items": [
        {
          "id": "1cfafffe-3869-47c9-8941-b972e5dea8bf",
          "errors": [],
          "project_slug": "gh/museapphq/Muse",
          "updated_at": "2026-08-14T23:40:50.978Z",
          "number": 12345,
          "state": "created",
          "created_at": "2026-08-14T23:40:50.978Z",
          "trigger": {
            "type": "webhook",
            "received_at": "2026-08-14T23:40:50.900Z",
            "actor": { "login": "adamwulf", "avatar_url": "https://avatars.githubusercontent.com/u/1?v=4" }
          },
          "trigger_parameters": {},
          "vcs": {
            "provider_name": "GitHub",
            "origin_repository_url": "https://github.com/museapphq/Muse",
            "target_repository_url": "https://github.com/museapphq/Muse",
            "revision": "af2f988dc87429afc22f7bcae107610ac82ae97e",
            "branch": "agent/web-snapshot-selection",
            "commit": { "subject": "Fix Phase 1 build: missing Locks/SwiftToolbox imports", "body": "" }
          }
        }
      ],
      "next_page_token": null
    }
    """

    /// First of a two-page listing (page token "PAGE2").
    static let pipelinesPage1 = """
    {
      "items": [
        { "id": "pipeline-1", "errors": [], "project_slug": "gh/museapphq/Muse",
          "number": 1, "state": "created", "created_at": "2026-08-14T23:40:50.978Z",
          "vcs": { "branch": "main", "revision": "aaaaaaaaaaaa" } }
      ],
      "next_page_token": "PAGE2"
    }
    """

    static let pipelinesPage2 = """
    {
      "items": [
        { "id": "pipeline-2", "errors": [], "project_slug": "gh/museapphq/Muse",
          "number": 2, "state": "created", "created_at": "2026-08-14T23:41:50.978Z",
          "vcs": { "branch": "main", "revision": "bbbbbbbbbbbb" } }
      ],
      "next_page_token": null
    }
    """

    static let pipeline = """
    {
      "id": "1cfafffe-3869-47c9-8941-b972e5dea8bf",
      "errors": [],
      "project_slug": "gh/museapphq/Muse",
      "number": 12345,
      "state": "created",
      "created_at": "2026-08-14T23:40:50.978Z",
      "updated_at": "2026-08-14T23:40:50.978Z",
      "vcs": { "branch": "agent/web-snapshot-selection", "revision": "af2f988dc87429afc22f7bcae107610ac82ae97e" }
    }
    """

    static let workflowsPage = """
    {
      "items": [
        {
          "pipeline_id": "1cfafffe-3869-47c9-8941-b972e5dea8bf",
          "id": "d6e3cf7a-5419-4f7a-bb71-91e8370a3f4b",
          "name": "release-deploy",
          "project_slug": "gh/museapphq/Muse",
          "status": "on_hold",
          "started_by": "98209bd9-c440-45b0-b1d7-749a15860f58",
          "pipeline_number": 12345,
          "created_at": "2026-08-14T23:40:51.361Z",
          "stopped_at": null
        }
      ],
      "next_page_token": null
    }
    """

    static let workflow = """
    {
      "id": "d6e3cf7a-5419-4f7a-bb71-91e8370a3f4b",
      "name": "release-deploy",
      "status": "on_hold",
      "pipeline_id": "1cfafffe-3869-47c9-8941-b972e5dea8bf",
      "pipeline_number": 12345,
      "project_slug": "gh/museapphq/Muse",
      "started_by": "98209bd9-c440-45b0-b1d7-749a15860f58",
      "created_at": "2026-08-14T23:40:51.361Z",
      "stopped_at": null,
      "canceled_by": null,
      "errored_by": null,
      "tag": null
    }
    """

    static let workflowFinished = """
    {
      "id": "d6e3cf7a-5419-4f7a-bb71-91e8370a3f4b",
      "name": "release-deploy",
      "status": "success",
      "pipeline_id": "1cfafffe-3869-47c9-8941-b972e5dea8bf",
      "created_at": "2026-08-14T23:40:51.361Z",
      "stopped_at": "2026-08-14T23:55:00.000Z"
    }
    """

    /// The release-deploy jobs: an approval gate (on_hold), a finished build job,
    /// and a build job blocked behind the gate.
    static let jobsPage = """
    {
      "items": [
        {
          "id": "58ae7914-6179-4a77-8b30-d324afaf048f",
          "name": "approve-mac-release",
          "type": "approval",
          "status": "on_hold",
          "approval_request_id": "58ae7914-6179-4a77-8b30-d324afaf048f",
          "dependencies": [],
          "started_at": null,
          "stopped_at": null
        },
        {
          "id": "9ae3058a-78b7-492a-a3f9-579fa466df15",
          "name": "slack/approval-notification-1",
          "type": "build",
          "status": "success",
          "job_number": 40796,
          "dependencies": [],
          "started_at": "2026-08-14T23:40:54.397Z",
          "stopped_at": "2026-08-14T23:41:03.267Z",
          "project_slug": "gh/museapphq/Muse"
        },
        {
          "id": "bc4fa18b-bcad-4c6f-936a-01938e16583e",
          "name": "mac-release",
          "type": "build",
          "status": "blocked",
          "dependencies": ["58ae7914-6179-4a77-8b30-d324afaf048f"],
          "job_number": null
        }
      ],
      "next_page_token": null
    }
    """

    static let approveAccepted = """
    { "message": "Accepted." }
    """

    static let jobDetail = """
    {
      "number": 40796,
      "status": "success",
      "name": "slack/approval-notification-1",
      "web_url": "https://circleci.com/gh/museapphq/Muse/40796",
      "project": { "id": "06a9bd5a-be08-4b9d-86cb-edbb17e5c1c7", "slug": "gh/museapphq/Muse", "name": "Muse" },
      "pipeline": { "id": "1cfafffe-3869-47c9-8941-b972e5dea8bf" },
      "latest_workflow": { "id": "d6e3cf7a-5419-4f7a-bb71-91e8370a3f4b", "name": "release-deploy" },
      "executor": { "type": "docker", "resource_class": "medium" },
      "parallelism": 1,
      "parallel_runs": [ { "index": 0, "status": "success" } ],
      "started_at": "2026-08-14T23:40:54.397Z",
      "queued_at": "2026-08-14T23:40:53.000Z",
      "stopped_at": "2026-08-14T23:41:03.267Z",
      "duration": 8000,
      "messages": [],
      "contexts": [],
      "organization": { "name": "museapphq" }
    }
    """

    static let jobSteps = """
    {
      "steps": [
        { "name": "Spin up environment",
          "actions": [ { "index": 0, "step": 0, "name": "Spin up environment", "type": "spinup_environment",
                         "status": "success", "exit_code": null, "has_output": true,
                         "start_time": "2026-08-14T23:40:53.738Z", "end_time": "2026-08-14T23:41:01.773Z",
                         "run_time_millis": 8035,
                         "output_url": "https://circle-production.s3.amazonaws.com/step-0?sig=abc" } ] },
        { "name": "Slack - Sending Approval Notification",
          "actions": [ { "index": 0, "step": 102, "name": "Slack - Sending Approval Notification", "type": "run",
                         "status": "success", "exit_code": 0, "background": false, "has_output": true,
                         "output_url": "https://circle-production.s3.amazonaws.com/step-102?sig=def" } ] }
      ]
    }
    """

    static let stepLog = """
    [
      { "message": "Starting slack notification\\n", "time": "2026-08-14T23:41:02.5Z", "type": "out" },
      { "message": "Done.\\n", "time": "2026-08-14T23:41:03.0Z", "type": "out" }
    ]
    """

    static let artifactsPage = """
    {
      "items": [
        { "path": "test-results/results.xml", "node_index": 0,
          "url": "https://output.circle-artifacts.com/abc/test-results/results.xml" },
        { "path": "build/app.zip", "node_index": 0,
          "url": "https://output.circle-artifacts.com/abc/build/app.zip" }
      ],
      "next_page_token": null
    }
    """

    static let testsPage = """
    {
      "items": [
        { "message": "", "source": "unit", "run_time": 0.12, "file": "Tests/AppTests/FooTests.swift",
          "result": "success", "name": "testFoo", "classname": "FooTests" }
      ],
      "next_page_token": null
    }
    """

    static let triggerResponse = """
    { "id": "new-pipeline-uuid", "number": 12346, "state": "created", "created_at": "2026-08-14T23:59:00.000Z" }
    """
}
