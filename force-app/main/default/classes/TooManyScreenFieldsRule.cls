public class TooManyScreenFieldsRule implements IFlowRule {

    @TestVisible
    private static Integer FIELD_THRESHOLD = 10;

    public List<RuleViolation> evaluate(FlowWrapper flow) {
        List<RuleViolation> violations = new List<RuleViolation>();

        for (FlowWrapper.FlowElementWrapper el : flow.elements) {
            if (el.elementType != 'Screen') continue;
            if (el.fieldCount == null || el.fieldCount <= FIELD_THRESHOLD) continue;

            RuleViolation v = new RuleViolation(
                'Too Many Screen Fields',
                'Warning',
                el.name,
                'Screen "' + el.name + '" has ' + el.fieldCount
                    + ' fields (threshold: ' + FIELD_THRESHOLD
                    + '). Long screens hurt completion rates — '
                    + 'consider splitting into multiple screens.'
            );
            v.flowApiName = flow.flowApiName;
            violations.add(v);
        }
        return violations;
    }
}