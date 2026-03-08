import Foundation
import UIKit

// Best OpenAI vision model as of mid-2025. Update here if a newer model supersedes it.
private let kOpenAIModel = "gpt-4o"
private let kOpenAIEndpoint = "https://api.openai.com/v1/chat/completions"

struct OpenAIService {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func extractEvents(from image: UIImage, referenceDate: Date = Date()) async throws -> [CalendarEvent] {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw OpenAIError.imageEncodingFailed
        }
        let base64Image = imageData.base64EncodedString()

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let currentDateString = dateFormatter.string(from: referenceDate)

        let prompt = """
        Extract all calendar events visible in this paper calendar image.
        Return ONLY a valid JSON object with this exact structure — no markdown, no explanation:
        {
          "events": [
            {
              "title": "event title",
              "start_date": "YYYY-MM-DDTHH:mm:ss",
              "end_date": "YYYY-MM-DDTHH:mm:ss",
              "location": "location string or null",
              "notes": "any extra details or null"
            }
          ]
        }

        Rules:
        - Today's date is \(currentDateString). Use this to infer the correct year and month when they are not shown.
        - If no time is shown, default start to 12:00:00 and end to 13:00:00.
        - If only a start time is shown, make the event 1 hour long.
        - All dates must be in ISO 8601 format: YYYY-MM-DDTHH:mm:ss
        - If no events are visible, return { "events": [] }
        """

        let requestBody: [String: Any] = [
            "model": kOpenAIModel,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)",
                                "detail": "high"
                            ]
                        ],
                        [
                            "type": "text",
                            "text": prompt
                        ]
                    ]
                ]
            ],
            "max_tokens": 4096,
            "response_format": ["type": "json_object"]
        ]

        var request = URLRequest(url: URL(string: kOpenAIEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode, body: body)
        }

        let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw OpenAIError.noContent
        }
        guard let contentData = content.data(using: .utf8) else {
            throw OpenAIError.invalidContent
        }

        let eventsResponse = try JSONDecoder().decode(OpenAIEventsResponse.self, from: contentData)
        return try eventsResponse.events.map { try $0.toCalendarEvent() }
    }
}

// MARK: - Response Models

private struct OpenAIChatResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let message: Message
    }
    struct Message: Decodable {
        let content: String
    }
}

private struct OpenAIEventsResponse: Decodable {
    let events: [OpenAIEvent]
}

private struct OpenAIEvent: Decodable {
    let title: String
    let startDate: String
    let endDate: String
    let location: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case title
        case startDate = "start_date"
        case endDate = "end_date"
        case location, notes
    }

    func toCalendarEvent() throws -> CalendarEvent {
        let start = try parseDate(startDate)
        let end = try parseDate(endDate)
        return CalendarEvent(title: title, startDate: start, endDate: end, location: location, notes: notes)
    }

    private func parseDate(_ string: String) throws -> Date {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd"
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            df.dateFormat = format
            if let date = df.date(from: string) { return date }
        }
        throw OpenAIError.invalidDateFormat(string)
    }
}

// MARK: - Errors

enum OpenAIError: LocalizedError {
    case imageEncodingFailed
    case invalidResponse
    case apiError(statusCode: Int, body: String)
    case noContent
    case invalidContent
    case invalidDateFormat(String)

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:        return "Failed to encode image for upload."
        case .invalidResponse:            return "Invalid response from OpenAI."
        case .apiError(let code, let body): return "OpenAI API error \(code): \(body)"
        case .noContent:                  return "OpenAI returned no content."
        case .invalidContent:             return "Could not parse event data from response."
        case .invalidDateFormat(let s):   return "Unrecognized date format: \(s)"
        }
    }
}
