public class HardcodedIdRule implements IFlowRule {

    // Matches 15 or 18 char Salesforce Ids
    private static final Pattern SF_ID_PATTERN = 
        Pattern.compile('\\b[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?\\b');

    // Known false positives to skip
    private static final Set<String> SAFE_PREFIXES = new Set<String>{
        '000', '001', '006' // add more known object prefixes as needed
    };

    public List<RuleViolation> evaluate(FlowWrapper flow) {
        List<RuleViolation> violations = new List<RuleViolation>();

        for (FlowWrapper.FlowElementWrapper el : flow.elements) {
            if (String.isBlank(el.rawValue)) continue;

            Matcher m = SF_ID_PATTERN.matcher(el.rawValue);
            while (m.find()) {
                String candidate = m.group();
                if (looksLikeSalesforceId(candidate)) {
                    RuleViolation v = new RuleViolation(
                        'Hardcoded Id',
                        'Error',
                        el.name,
                        'Element "' + el.name + '" appears to contain a hardcoded '
                            + 'Salesforce Id: ' + candidate 
                            + '. Use a variable or Custom Label instead.'
                    );
                    v.flowApiName = flow.flowApiName;
                    violations.add(v);
                    break; // one violation per element is enough
                }
            }
        }
        return violations;
    }

    private Boolean looksLikeSalesforceId(String val) {
        if (val.length() != 15 && val.length() != 18) return false;
        // Must contain at least some digits (pure alpha strings are usually not IDs)
        Pattern digitCheck = Pattern.compile('.*\\d.*');
        return digitCheck.matcher(val).matches();
    }
}