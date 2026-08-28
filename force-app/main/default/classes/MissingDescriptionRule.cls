public class MissingDescriptionRule implements IFlowRule {

    public List<RuleViolation> evaluate(FlowWrapper flow) {
        List<RuleViolation> violations = new List<RuleViolation>();

        if (String.isBlank(flow.description) || flow.description == 'null') {
            String flowDisplayName = String.isNotBlank(flow.flowLabel) && flow.flowLabel != 'null'
                ? flow.flowLabel
                : flow.flowApiName;

            RuleViolation v = new RuleViolation(
                'Missing Description',
                'Warning',
                flow.flowApiName,
                'Flow "' + flowDisplayName 
                + '" has no description. '
                + 'Add a description so admins understand the flow\'s purpose.'
            );
            v.flowApiName = flow.flowApiName;
            violations.add(v);
        }
        return violations;
    }
}