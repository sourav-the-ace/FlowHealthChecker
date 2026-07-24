public interface IFlowRule {
    List<RuleViolation> evaluate(FlowWrapper flow);
}