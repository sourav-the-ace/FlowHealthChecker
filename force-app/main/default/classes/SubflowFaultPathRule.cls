public class SubflowFaultPathRule implements IFlowRule {
  public List<RuleViolation> evaluate(FlowWrapper flow) {
    // Deactivated: Salesforce Flow Builder does not support fault connectors on Subflow elements.
    // Error handling for subflows must be implemented inside the child flow.
    return new List<RuleViolation>();
  }
}
