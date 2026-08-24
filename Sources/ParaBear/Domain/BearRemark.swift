import Foundation

/// What the bear says when you poke it.
///
/// It used to say hello and use your account's name, which is a thing an app says once. These are
/// remarks rather than a greeting: the bear is the one being interrupted, and it has opinions about
/// your afternoon. That is also why the line is picked when the bubble is *opened* and then held —
/// the rig redraws sixty times a second under a `TimelineView`, so a line chosen where it is drawn
/// would be a different line every frame.
enum BearRemark {
    static let all = [
        "Are you actually working?",
        "Stop clicking me.",
        "I need a break.",
        "You look tired.",
        "Go drink some water.",
        "Can we go home now?",
        "I'm doing absolutely nothing.",
        "Another meeting? Seriously?",
        "Don't blame me for this.",
        "I'm watching you procrastinate.",
        "Get back to work.",
        "What are you looking at?",
        "You're about to get fired.",
        "I'm lazy. Leave me alone.",
        "Have you eaten yet?",
        "I don't want to fall again.",
        "Do we have a meeting today?"
    ]

    /// A line other than the one just shown.
    ///
    /// Drawing uniformly at random repeats about one tap in seventeen, and a repeat does not read
    /// as chance — it reads as the tap not having registered, because the only feedback a tap gives
    /// is that the words changed. Excluding the last one costs nothing and removes the whole class
    /// of "did that work?".
    static func next(after previous: String?) -> String {
        let choices = all.filter { $0 != previous }

        // `all` is a stated constant with more than one line in it, so `choices` is never empty —
        // but a `randomElement()` returning nil must not silently blank the bubble.
        return choices.randomElement() ?? all[0]
    }
}
