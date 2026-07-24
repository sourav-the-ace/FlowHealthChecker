public class UnusedVariableRule implements IFlowRule {

    public List<RuleViolation> evaluate(FlowWrapper flow) {
        List<RuleViolation> violations = new List<RuleViolation>();

        if (flow.variables == null || flow.variables.isEmpty()) {
            return violations;
        }

        // Build one big string of all element rawValues to search against
        String allElementsJson = '';
        for (FlowWrapper.FlowElementWrapper el : flow.elements) {
            if (String.isNotBlank(el.rawValue)) {
                allElementsJson += el.rawValue;
            }
        }
        // Also include subflows
        for (FlowWrapper.FlowElementWrapper sf : flow.subflows) {
            if (String.isNotBlank(sf.rawValue)) {
                allElementsJson += sf.rawValue;
            }
        }

        for (FlowWrapper.FlowVariableWrapper variable : flow.variables) {
            // Skip input/output variables — they are used by the caller
            if (variable.isInput || variable.isOutput) continue;

            // Check if variable name appears anywhere in element definitions
            if (!allElementsJson.contains(variable.name)) {
                RuleViolation v = new RuleViolation(
                    'Unused Variable',
                    'Warning',
                    variable.name,
                    'Variable "' + variable.name + '" (' + variable.dataType + ') '
                        + 'is declared but never referenced in any flow element. '
                        + 'Remove it to keep the flow clean.'
                );
                v.flowApiName = flow.flowApiName;
                violations.add(v);
            }
        }
        return violations;
    }
}