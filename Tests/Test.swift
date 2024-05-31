import Testing

@Suite struct SnakeOilTests {
  @Test func trueIsTrue() {
    #expect(Bool(true))
  }
}
