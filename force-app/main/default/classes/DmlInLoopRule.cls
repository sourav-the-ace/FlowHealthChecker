public class DmlInLoopRule implements IFlowRule {

    private static final Set<String> DML_TYPES = new Set<String>{
        'RecordCreate', 'RecordUpdate', 'RecordDelete', 'RecordLookup'
    };

    public List<RuleViolation> evaluate(FlowWrapper flow) {
        List<RuleViolation> violations = new List<RuleViolation>();

        for (FlowWrapper.FlowElementWrapper el : flow.elements) {
            if (DML_TYPES.contains(el.elementType) 
                && String.isNotBlank(el.parentLoopName)) {

                RuleViolation v = new RuleViolation(
                    'DML In Loop',
                    'Error',
                    el.name,
                    el.elementType + ' element "' + el.name 
                        + '" is inside loop "' + el.parentLoopName 
                        + '". This causes governor limit issues at scale.'
                );
                v.flowApiName = flow.flowApiName;
                violations.add(v);
            }
        }
        return violations;
    }
}