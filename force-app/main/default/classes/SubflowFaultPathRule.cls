public class SubflowFaultPathRule implements IFlowRule {

    public List<RuleViolation> evaluate(FlowWrapper flow) {
        List<RuleViolation> violations = new List<RuleViolation>();

        for (FlowWrapper.FlowElementWrapper sf : flow.subflows) {
            if (!sf.hasFaultConnector) {
                RuleViolation v = new RuleViolation(
                    'Subflow Missing Fault Path',
                    'Error',
                    sf.name,
                    'Subflow element "' + sf.name
                        + '" has no fault connector. Errors from the called flow '
                        + 'will surface directly to the user.'
                );
                v.flowApiName = flow.flowApiName;
                violations.add(v);
            }
        }
        return violations;
    }
}