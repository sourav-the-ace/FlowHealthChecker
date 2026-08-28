public class TooManyElementsRule implements IFlowRule {

    @TestVisible
    private static Integer ELEMENT_THRESHOLD = 30;

    public List<RuleViolation> evaluate(FlowWrapper flow) {
        List<RuleViolation> violations = new List<RuleViolation>();

        Integer count = flow.elements != null ? flow.elements.size() : 0;
        if (count > ELEMENT_THRESHOLD) {
            String flowDisplayName = String.isNotBlank(flow.flowLabel) && flow.flowLabel != 'null'
                ? flow.flowLabel
                : flow.flowApiName;

            RuleViolation v = new RuleViolation(
                'Too Many Elements',
                'Warning',
                flow.flowApiName,
                'Flow "' + flowDisplayName + '" has ' + count 
                    + ' elements (threshold: ' + ELEMENT_THRESHOLD 
                    + '). Consider splitting into subflows.'
            );
            v.flowApiName = flow.flowApiName;
            violations.add(v);
        }
        return violations;
    }
}