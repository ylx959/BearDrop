import Testing
@testable import ParaBear

struct BearGreetingBubbleTests {
    @MainActor
    @Test func currentUserGreetingHasDisplayName() {
        #expect(!CurrentUserGreeting.displayName.isEmpty)
    }

    @MainActor
    @Test func speechBubbleSitsToTheSideOfTail() {
        #expect(BearGreetingBubble.bubbleOffset.x < BearGreetingBubble.tailOffset.x)
        #expect(BearGreetingBubble.canvasSize.width > 170)
    }
}
