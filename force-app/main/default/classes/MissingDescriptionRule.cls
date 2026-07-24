public class MissingDescriptionRule implements IFlowRule {

    public List<RuleViolation> evaluate(FlowWrapper flow) {
        List<RuleViolation> violations = new List<RuleViolation>();

        if (String.isBlank(flow.description)) {
            RuleViolation v = new RuleViolation(
                'Missing Description',
                'Warning',
                flow.flowApiName,
                'Flow "' + (String.isNotBlank(flow.flowLabel) ? flow.flowLabel : flow.flowApiName) 
                + '" has no description. '
                + 'Add a description so admins understand the flow\'s purpose.'
            );
            v.flowApiName = flow.flowApiName;
            violations.add(v);
        }
        return violations;
    }
}