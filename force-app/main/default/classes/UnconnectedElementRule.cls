public class UnconnectedElementRule implements IFlowRule {

    public List<RuleViolation> evaluate(FlowWrapper flow) {
        List<RuleViolation> violations = new List<RuleViolation>();

        if (flow.connectedElements == null) return violations;

        // Every element that exists in the flow should appear
        // in the connectedElements set (reachable from Start)
        for (FlowWrapper.FlowElementWrapper el : flow.elements) {
            // Skip Loop type — loops are connectors themselves
            if (el.elementType == 'Loop') continue;

            if (!flow.connectedElements.contains(el.name)) {
                RuleViolation v = new RuleViolation(
                    'Unconnected Element',
                    'Warning',
                    el.name,
                    el.elementType + ' element "' + el.name
                        + '" is never reached from the flow\'s Start element. '
                        + 'It is dead code — connect it or delete it.'
                );
                v.flowApiName = flow.flowApiName;
                violations.add(v);
            }
        }

        // Also check subflows
        for (FlowWrapper.FlowElementWrapper sf : flow.subflows) {
            if (!flow.connectedElements.contains(sf.name)) {
                RuleViolation v = new RuleViolation(
                    'Unconnected Element',
                    'Warning',
                    sf.name,
                    'Subflow element "' + sf.name
                        + '" is never reached from the flow\'s Start element.'
                );
                v.flowApiName = flow.flowApiName;
                violations.add(v);
            }
        }
        return violations;
    }
}