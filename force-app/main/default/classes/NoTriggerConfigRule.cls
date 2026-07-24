public class NoTriggerConfigRule implements IFlowRule {

    // These process types should always have a trigger configured
    private static final Set<String> TRIGGER_REQUIRED_TYPES = new Set<String>{
        'AutoLaunchedFlow', 'RecordTriggeredFlow', 'ScheduledFlow'
    };

    public List<RuleViolation> evaluate(FlowWrapper flow) {
        List<RuleViolation> violations = new List<RuleViolation>();

        if (!TRIGGER_REQUIRED_TYPES.contains(flow.processType)) {
            return violations; // Screen flows etc. don't need triggers
        }

        Boolean missingConfig =
            flow.startConfig == null
            || (String.isBlank(flow.startConfig.triggerType)
                && String.isBlank(flow.startConfig.objectApiName));

        if (missingConfig) {
            RuleViolation v = new RuleViolation(
                'No Trigger Configuration',
                'Warning',
                flow.flowApiName,
                'Flow "' + (String.isNotBlank(flow.flowLabel) ? flow.flowLabel : flow.flowApiName) 
                    + '" is type ' + flow.processType                    
                    + ' but has no trigger or object configured on the Start element. '
                    + 'It cannot be automatically invoked.'
            );
            v.flowApiName = flow.flowApiName;
            violations.add(v);
        }
        return violations;
    }
}