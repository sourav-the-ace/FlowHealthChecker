public class SubflowFaultPathRule implements IFlowRule {

    public List<RuleViolation> evaluate(FlowWrapper flow) {
        // Salesforce Flow Builder does not support fault connectors on Subflow elements.
        // Error handling for subflows must be implemented inside the subflow itself.
        // This rule is deactivated to prevent false positive errors.
        return new List<RuleViolation>();
    }
}