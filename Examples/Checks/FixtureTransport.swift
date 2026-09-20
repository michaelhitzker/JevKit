import Foundation
import JevKit

/// Fixed, clearly labeled results still pass through the real SDK decoder and validation.
struct FixtureTransport: JevTransport {
    let example: Example

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await Task.sleep(for: .milliseconds(400))
        let fixtures: [String: String] = [
            "bug": #"{"type":"noul","noul":0.97}"#,
            "priority": #"{"type":"choice","choice":"critical","confidence":0.96,"probabilities":{"low":0.01,"medium":0.01,"high":0.03,"critical":0.95}}"#,
            "urgency": #"{"type":"score","score":1.9,"confidence":0.88,"probabilities":{"0":0.02,"1":0.06,"2":0.92},"legend":{"0":"Can wait for backlog grooming","1":"Needs attention today","2":"Requires immediate incident response"}}"#
        ]
        let answers = example.questions.compactMap { question -> String? in
            let id = question.id.rawValue
            return fixtures[id].map { "\"\(id)\":\($0)" }
        }.joined(separator: ",")
        let body = "{\"model\":\"offline-fixture\",\"answers\":{\(answers)},\"usage\":{}}"
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        else { throw URLError(.badServerResponse) }
        return (Data(body.utf8), response)
    }
}
