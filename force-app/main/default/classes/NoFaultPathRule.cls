public class NoFaultPathRule implements IFlowRule {

    private static final Set<String> DML_AND_CALLOUT_TYPES = new Set<String>{
        'RecordCreate', 'RecordUpdate', 'RecordDelete', 'ActionCall', 'ApexPluginCall'
    };

    public List<RuleViolation> evaluate(FlowWrapper flow) {
        List<RuleViolation> violations = new List<RuleViolation>();

        for (FlowWrapper.FlowElementWrapper el : flow.elements) {
            if (DML_AND_CALLOUT_TYPES.contains(el.elementType) 
                && !el.hasFaultConnector 
                && !el.isOnFaultPath) { 

                RuleViolation v = new RuleViolation(
                    'No Fault Path',
                    'Error',
                    el.name,
                    el.elementType + ' element "' + el.name 
                        + '" has no fault connector. Unhandled errors will surface to users.'
                );
                v.flowApiName = flow.flowApiName;
                violations.add(v);
            }
        }
        return violations;
    }
}