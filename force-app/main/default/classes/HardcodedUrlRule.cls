public class HardcodedUrlRule implements IFlowRule {

    private static final Pattern URL_PATTERN =
        Pattern.compile('https?://[a-zA-Z0-9\\-\\.]+\\.[a-zA-Z]{2,}(/[^"\\s]*)?');

    // Safe domains to ignore — Salesforce system URLs
    private static final Set<String> SAFE_DOMAINS = new Set<String>{
        'salesforce.com', 'force.com', 'cloudfront.net',
        'schema.org', 'w3.org', 'xmlsoap.org'
    };

    public List<RuleViolation> evaluate(FlowWrapper flow) {
        List<RuleViolation> violations = new List<RuleViolation>();

        for (FlowWrapper.FlowElementWrapper el : flow.elements) {
            if (String.isBlank(el.rawValue)) continue;

            Matcher m = URL_PATTERN.matcher(el.rawValue);
            while (m.find()) {
                String url = m.group();
                if (!isSafeDomain(url)) {
                    RuleViolation v = new RuleViolation(
                        'Hardcoded URL',
                        'Warning',
                        el.name,
                        'Element "' + el.name + '" contains a hardcoded URL: '
                            + url + '. Use a Custom Label or Custom Setting instead.'
                    );
                    v.flowApiName = flow.flowApiName;
                    violations.add(v);
                    break; // one violation per element
                }
            }
        }
        return violations;
    }

    private Boolean isSafeDomain(String url) {
        for (String domain : SAFE_DOMAINS) {
            if (url.containsIgnoreCase(domain)) return true;
        }
        return false;
    }
}