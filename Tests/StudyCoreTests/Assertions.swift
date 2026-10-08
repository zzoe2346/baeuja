import Testing
import Foundation

func expectEqual<T: Equatable>(_ a: T, _ b: T, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(a == b, sourceLocation: sourceLocation)
}
func expectTrue(_ value: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(value, sourceLocation: sourceLocation)
}
func expectFalse(_ value: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(!value, sourceLocation: sourceLocation)
}
func expectNil<T>(_ value: T?, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(value == nil, sourceLocation: sourceLocation)
}
func expectNotNil<T>(_ value: T?, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(value != nil, sourceLocation: sourceLocation)
}
func expectLess<T: Comparable>(_ a: T, _ b: T, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(a < b, sourceLocation: sourceLocation)
}
func expectGreater<T: Comparable>(_ a: T, _ b: T, sourceLocation: SourceLocation = #_sourceLocation)
{ #expect(a > b, sourceLocation: sourceLocation) }
func expectAtLeast<T: Comparable>(_ a: T, _ b: T, sourceLocation: SourceLocation = #_sourceLocation)
{ #expect(a >= b, sourceLocation: sourceLocation) }
func fail(
    _ message: String = "기대 조건이 충족되지 않았습니다", sourceLocation: SourceLocation = #_sourceLocation
) { Issue.record(Comment(rawValue: message), sourceLocation: sourceLocation) }
func expectThrows<T>(
    _ body: @autoclosure () throws -> T, sourceLocation: SourceLocation = #_sourceLocation
) {
    do { _ = try body(); Issue.record("실패해야 하는 입력이 채택되었습니다", sourceLocation: sourceLocation) } catch
    {}
}
func expectNoThrow<T>(
    _ body: @autoclosure () throws -> T, sourceLocation: SourceLocation = #_sourceLocation
) {
    do { _ = try body() } catch { Issue.record(error, sourceLocation: sourceLocation) }
}
func requireValue<T>(_ value: T?, sourceLocation: SourceLocation = #_sourceLocation) throws -> T {
    try #require(value, sourceLocation: sourceLocation)
}
