// APIService.swift
// Fetches Claude usage data from claude.ai internal API.
//
// ─── Auth hierarchy (tries in order) ────────────────────────────────
//  1. Claude Code CLI credentials  ~/.claude/.credentials.json
//     → OAuth accessToken (auto-refreshed by Claude Code itself)
//     → Header: Authorization: Bearer {token}
//
//  2. sessionKey cookie only  (from .env or UserDefaults)
//     → Header: Cookie: sessionKey={sk-ant-sid02-...}
//     → cf_clearance is NOT needed from a native Mac app
//
// ─── Why NOT the full cookie string? ─────────────────────────────────
//  cf_clearance is Cloudflare's *browser* challenge token.
//  Native macOS apps making clean HTTPS requests are NOT challenged by
//  Cloudflare — only suspicious browser traffic is. Sending just the
//  sessionKey cookie is the correct approach and avoids the ~24h expiry
//  issue of cf_clearance entirely.
//
// ─── Endpoints ────────────────────────────────────────────────────────
//  GET https://claude.ai/api/bootstrap                    → resolve orgId
//  GET https://claude.ai/api/organizations/{orgId}/usage  → usage windows

import Foundation
import Combine

@MainActor
final class APIService: ObservableObject {

    // MARK: - Published state

    @Published var usageData: UsageData?
    @Published var isLoading   = false
    @Published var errorMessage: String?
    @Published var lastFetched: Date?
    @Published var authMode: AuthMode = .none

    enum AuthMode: Equatable {
        case none
        case cliOAuth(expiresAt: Date?)
        case sessionKey
    }

    // MARK: - Internal credentials

    private var sessionKey = ""     // sk-ant-sid02-... or sk-ant-sid01-...
    private var oauthToken = ""     // Bearer token from CLI credentials
    private var orgId      = ""

    // MARK: - Init

    init() {
        loadCredentials()
    }

    // MARK: - Credential loading

    func loadCredentials() {
        // 1. Try Claude Code CLI credentials (best option — auto-refreshed)
        if loadCLICredentials() { return }

        // 2. Try .env file — extract sessionKey only
        loadSessionKeyFromEnv()

        // 3. Fall back to UserDefaults
        if sessionKey.isEmpty {
            sessionKey = UserDefaults.standard.string(forKey: "claude_session_key") ?? ""
        }
        if !sessionKey.isEmpty { authMode = .sessionKey }
    }

    // MARK: - CLI credentials loader

    @discardableResult
    private func loadCLICredentials() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".claude/.credentials.json"),
            home.appendingPathComponent(".claude/credentials.json"),
        ]

        for url in candidates {
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            // Structure: { "claudeAiOauth": { "accessToken": "...", "expiresAt": 12345678 } }
            if let oauth = json["claudeAiOauth"] as? [String: Any],
               let token = oauth["accessToken"] as? String, !token.isEmpty {
                oauthToken = token
                var expires: Date?
                if let ms = oauth["expiresAt"] as? Double {
                    expires = Date(timeIntervalSince1970: ms / 1000)
                }
                authMode = .cliOAuth(expiresAt: expires)
                return true
            }

            // Flat structure fallback
            if let token = json["accessToken"] as? String, !token.isEmpty {
                oauthToken = token
                authMode   = .cliOAuth(expiresAt: nil)
                return true
            }
        }
        return false
    }

    // MARK: - Session key loader from .env

    private func loadSessionKeyFromEnv() {
        let envURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude-usage/.env")

        guard let raw = try? String(contentsOf: envURL, encoding: .utf8) else { return }

        // env file me se sirf sessionKey=sk-ant-... nikaalna hai
        let lines = raw.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("sessionKey=") {
                sessionKey = String(trimmed.dropFirst("sessionKey=".count))
                    .trimmingCharacters(in: .init(charactersIn: ";, \t"))
            }
            // Extract orgId from lastActiveOrg=
            if trimmed.hasPrefix("lastActiveOrg=") {
                let candidate = String(trimmed.dropFirst("lastActiveOrg=".count))
                    .trimmingCharacters(in: .init(charactersIn: ";, \t"))
                if candidate.count == 36 { orgId = candidate }
            }
        }

        // sessionKey might also be embedded in a long line: ...; sessionKey=sk-ant-...
        if sessionKey.isEmpty {
            for line in lines {
                if let range = line.range(of: "sessionKey=") {
                    let tail = String(line[range.upperBound...])
                    sessionKey = tail
                        .components(separatedBy: [";", " ", "\n"])
                        .first ?? ""
                }
            }
        }

        if !sessionKey.isEmpty { authMode = .sessionKey }
    }

    func saveSessionKey(_ key: String) {
        sessionKey = key.trimmingCharacters(in: .whitespaces)
        UserDefaults.standard.set(sessionKey, forKey: "claude_session_key")
        authMode = .sessionKey
    }

    // MARK: - Public

    func refresh() {
        Task { await fetchUsage() }
    }

    // MARK: - Fetch pipeline

    private func fetchUsage() async {
        guard authMode != .none else {
            errorMessage = "No credentials found. Paste your sessionKey or log in with Claude Code."
            return
        }

        isLoading    = true
        errorMessage = nil

        if orgId.isEmpty { await fetchBootstrap() }

        guard !orgId.isEmpty else {
            errorMessage = "Could not resolve org ID"
            isLoading    = false
            return
        }

        let urlString = "https://claude.ai/api/organizations/\(orgId)/usage"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading    = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: buildRequest(url))

            if let http = response as? HTTPURLResponse {
                guard http.statusCode == 200 else {
                    errorMessage = http.statusCode == 401 || http.statusCode == 403
                        ? "Session expired — refresh your credentials"
                        : "HTTP \(http.statusCode)"
                    isLoading = false
                    return
                }
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                usageData   = parseUsage(json)
                lastFetched = Date()
            } else {
                errorMessage = "Could not parse response"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func fetchBootstrap() async {
        guard let url = URL(string: "https://claude.ai/api/bootstrap") else { return }
        guard let (data, _) = try? await URLSession.shared.data(for: buildRequest(url)),
              let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let account = json["account"] as? [String: Any],
              let id      = account["lastActiveOrgId"] as? String else { return }
        orgId = id
    }

    // MARK: - Request builder

    private func buildRequest(_ url: URL) -> URLRequest {
        var r = URLRequest(url: url)
        r.timeoutInterval = 15

        switch authMode {
        case .cliOAuth:
            // CLI OAuth: Bearer token + anthropic headers
            r.setValue("Bearer \(oauthToken)",         forHTTPHeaderField: "Authorization")
            r.setValue("claude-code/2.1.5",            forHTTPHeaderField: "User-Agent")
            r.setValue("oauth-2025-04-20",             forHTTPHeaderField: "anthropic-beta")
            r.setValue("application/json",             forHTTPHeaderField: "Accept")

        case .sessionKey, .none:
            // sessionKey cookie ONLY — no cf_clearance needed from native app
            r.setValue("sessionKey=\(sessionKey)",     forHTTPHeaderField: "Cookie")
            r.setValue("application/json",             forHTTPHeaderField: "Accept")
            r.setValue("application/json",             forHTTPHeaderField: "Content-Type")
            r.setValue("https://claude.ai",            forHTTPHeaderField: "Origin")
            r.setValue("https://claude.ai/",           forHTTPHeaderField: "Referer")
            r.setValue(Self.safariUA,                  forHTTPHeaderField: "User-Agent")
        }

        return r
    }

    private static let safariUA =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
        "AppleWebKit/605.1.15 (KHTML, like Gecko) " +
        "Version/17.0 Safari/605.1.15"

    // MARK: - JSON parsing

    private func parseUsage(_ json: [String: Any]) -> UsageData {
        func window(_ key: String) -> UsageWindow? {
            guard let obj  = json[key] as? [String: Any],
                  let util = obj["utilization"] as? Double,
                  let str  = obj["resets_at"]   as? String else { return nil }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let date = iso.date(from: str) ?? ISO8601DateFormatter().date(from: str) ?? Date()
            return UsageWindow(utilization: util, resetsAt: date)
        }

        return UsageData(
            fiveHour:       window("five_hour")        ?? UsageWindow(utilization: 0, resetsAt: Date()),
            sevenDay:       window("seven_day")        ?? UsageWindow(utilization: 0, resetsAt: Date()),
            sevenDaySonnet: window("seven_day_sonnet"),
            fetchedAt:      Date()
        )
    }
}
