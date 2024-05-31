import DJIMetadataFixer
import Testing

@Suite struct SnakeOilTests {
  @Test func trueIsTrue() {
    let _ = Exporter()  // Initialize the class just for kicks
    #expect(Bool(true))
  }
}
