public class DuplicateDmlRule implements IFlowRule {

    private static final Set<String> DML_TYPES = new Set<String>{
        'RecordCreate', 'RecordUpdate', 'RecordDelete'
    };

    public List<RuleViolation> evaluate(FlowWrapper flow) {
        List<RuleViolation> violations = new List<RuleViolation>();

        // Count DML operations per object, excluding those inside loops
        // (DmlInLoopRule already covers those)
        Map<String, List<String>> objectToDmlElements =
            new Map<String, List<String>>();

        for (FlowWrapper.FlowElementWrapper el : flow.elements) {
            if (!DML_TYPES.contains(el.elementType)) continue;
            if (String.isNotBlank(el.parentLoopName)) continue; // skip loop DML
            if (String.isBlank(el.objectName)) continue;

            String key = el.elementType + ':' + el.objectName;
            if (!objectToDmlElements.containsKey(key)) {
                objectToDmlElements.put(key, new List<String>());
            }
            objectToDmlElements.get(key).add(el.name);
        }

        for (String key : objectToDmlElements.keySet()) {
            List<String> elementNames = objectToDmlElements.get(key);
            if (elementNames.size() > 1) {
                String[] parts      = key.split(':');
                String   dmlType    = parts[0];
                String   objectName = parts[1];

                RuleViolation v = new RuleViolation(
                    'Duplicate DML on Same Object',
                    'Warning',
                    String.join(elementNames, ', '),
                    dmlType + ' is performed ' + elementNames.size()
                        + ' times on "' + objectName + '" ('
                        + String.join(elementNames, ', ') + '). '
                        + 'Consider combining into a single operation using a collection.'
                );
                v.flowApiName = flow.flowApiName;
                violations.add(v);
            }
        }
        return violations;
    }
}