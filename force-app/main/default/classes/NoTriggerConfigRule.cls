public class NoTriggerConfigRule implements IFlowRule {

    private static final Set<String> RECORD_TRIGGER_TYPES = new Set<String>{
        'RecordBeforeSave', 'RecordAfterSave', 'RecordBeforeDelete'
    };

    public List<RuleViolation> evaluate(FlowWrapper flow) {
        List<RuleViolation> violations = new List<RuleViolation>();

        String flowDisplayName = String.isNotBlank(flow.flowLabel) && flow.flowLabel != 'null'
            ? flow.flowLabel
            : flow.flowApiName;

        // Record-Triggered Flows must have a target SObject configured
        Boolean isRecordTriggered = flow.processType == 'RecordTriggeredFlow'
            || (flow.startConfig != null && RECORD_TRIGGER_TYPES.contains(flow.startConfig.triggerType));

        if (isRecordTriggered) {
            if (flow.startConfig == null || String.isBlank(flow.startConfig.objectApiName)) {
                RuleViolation v = new RuleViolation(
                    'No Trigger Configuration',
                    'Warning',
                    flow.flowApiName,
                    'Flow "' + flowDisplayName 
                        + '" is a Record-Triggered Flow but has no target SObject configured on the Start element.'
                );
                v.flowApiName = flow.flowApiName;
                violations.add(v);
            }
        }

        return violations;
    }
}