public class RecursiveSubflowRule implements IFlowRule {

    public List<RuleViolation> evaluate(FlowWrapper flow) {
        List<RuleViolation> violations = new List<RuleViolation>();

        for (FlowWrapper.FlowElementWrapper sf : flow.subflows) {
            if (String.isBlank(sf.calledFlowApiName)) continue;
            if (sf.calledFlowApiName == flow.flowApiName) {
                RuleViolation v = new RuleViolation(
                    'Recursive Subflow',
                    'Error',
                    sf.name,
                    'Subflow element "' + sf.name + '" calls its own parent flow ("'
                        + flow.flowApiName + '"). This is a direct recursive '
                        + 'loop with no exit condition visible to the scanner — '
                        + 'it will run until a governor limit or CPU timeout is hit.'
                );
                v.flowApiName = flow.flowApiName;
                violations.add(v);
            }
        }
        return violations;
    }
}