//
//  TokenResolver.swift
//  cirqueduci
//
//  Resolves the CircleCI personal API token from the environment or a `.env`
//  file. The primary key is `CIRCLECI_API_KEY`; `CIRCLECI_TOKEN` is accepted as
//  a fallback. Environment variables take precedence over `.env` files.
//

import Foundation

public enum TokenResolver {

    /// The preferred environment variable / `.env` key for the CircleCI token.
    public static let primaryKey = "CIRCLECI_API_KEY"

    /// A fallback key accepted for compatibility.
    public static let fallbackKey = "CIRCLECI_TOKEN"

    /// Reads the token from the process environment, preferring `CIRCLECI_API_KEY`
    /// and falling back to `CIRCLECI_TOKEN`.
    public static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        if let value = environment[primaryKey], !value.isEmpty {
            return value
        }
        if let value = environment[fallbackKey], !value.isEmpty {
            return value
        }
        return nil
    }

    /// Reads the token from a `.env` file, searching upward from `directory`,
    /// preferring `CIRCLECI_API_KEY` and falling back to `CIRCLECI_TOKEN`.
    public static func fromDotEnv(startingIn directory: URL? = nil) -> String? {
        DotEnv.loadValue(forKey: primaryKey, startingIn: directory)
            ?? DotEnv.loadValue(forKey: fallbackKey, startingIn: directory)
    }

    /// Resolves the token, preferring the process environment and then a `.env`
    /// file discovered by walking up from `directory`.
    public static func resolve(environment: [String: String] = ProcessInfo.processInfo.environment,
                               startingIn directory: URL? = nil) -> String? {
        fromEnvironment(environment) ?? fromDotEnv(startingIn: directory)
    }
}
