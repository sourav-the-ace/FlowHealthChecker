public with sharing class FlowScannerService {

    private static final Map<String, Type> RULE_TYPE_MAP = new Map<String, Type>{
        'NoFaultPathRule'        => NoFaultPathRule.class,
        'DmlInLoopRule'          => DmlInLoopRule.class,
        'MissingDescriptionRule' => MissingDescriptionRule.class,
        'TooManyElementsRule'    => TooManyElementsRule.class,
        'HardcodedIdRule'        => HardcodedIdRule.class,
        'HardcodedUrlRule'       => HardcodedUrlRule.class,
        'SubflowFaultPathRule'   => SubflowFaultPathRule.class,
        'NoTriggerConfigRule'    => NoTriggerConfigRule.class,
        'UnusedVariableRule'     => UnusedVariableRule.class,
        'DuplicateDmlRule'       => DuplicateDmlRule.class,
        'UnconnectedElementRule' => UnconnectedElementRule.class,
        'TooManyScreenFieldsRule' => TooManyScreenFieldsRule.class,
        'RecursiveSubflowRule'    => RecursiveSubflowRule.class
    };

    @AuraEnabled
    public static Id initiateAsyncScan() {
        if (!Schema.sObjectType.Flow_Scan__c.isCreateable()) {
            throw new AuraHandledException(
                'You do not have permission to create Flow Scan records. '
                + 'Please ask your administrator to assign the '
                + 'Flow Health Checker Admin permission set.'
            );
        }

        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c = DateTime.now(),
            Status__c    = 'Pending'
        );
        insert scan;

        System.enqueueJob(new FlowScanQueueable(scan.Id));
        return scan.Id;
    }

    @AuraEnabled
    public static Map<String, Object> getScanStatus(Id scanId) {
        if (!Schema.sObjectType.Flow_Scan__c.isAccessible()) {
            throw new AuraHandledException(
                'You do not have permission to view Flow Scan records.'
            );
        }

        Flow_Scan__c scan = [
            SELECT Id, Status__c, Error_Message__c,
                   Total_Flows_Scanned__c, Total_Violations__c
            FROM Flow_Scan__c
            WHERE Id = :scanId
            LIMIT 1
        ];

        return new Map<String, Object>{
            'status'          => scan.Status__c,
            'errorMessage'    => scan.Error_Message__c,
            'totalFlows'      => scan.Total_Flows_Scanned__c,
            'totalViolations' => scan.Total_Violations__c
        };
    }

    public static List<IFlowRule> loadRules() {
        List<IFlowRule> rules = new List<IFlowRule>();
        for (Flow_Rule__mdt record : [
            SELECT Rule_Type__c, Active__c
            FROM Flow_Rule__mdt
            WHERE Active__c = true
        ]) {
            Type ruleType = RULE_TYPE_MAP.get(record.Rule_Type__c);
            if (ruleType != null) {
                rules.add((IFlowRule) ruleType.newInstance());
            }
        }
        return rules;
    }

    public static void persistScanResults(
    Id scanId,
    Integer totalFlows,
    List<RuleViolation> violations
) {
        Integer errorCount = 0;
        Integer warningCount = 0;
        Set<String> affectedFlowNames = new Set<String>();
        for (RuleViolation v : violations) {
            if (v.severity == 'Error') errorCount++;
            else if (v.severity == 'Warning') warningCount++;
            if (String.isNotBlank(v.flowApiName)) {
                affectedFlowNames.add(v.flowApiName);
            }
        }

        update new Flow_Scan__c(
            Id                     = scanId,
            Total_Flows_Scanned__c = totalFlows,
            Total_Violations__c    = violations.size(),
            Errors__c              = errorCount,
            Warnings__c            = warningCount,
            Affected_Flows__c      = affectedFlowNames.size()
        );

    if (!violations.isEmpty()) {
        List<Flow_Scan_Result__c> results = new List<Flow_Scan_Result__c>();
        for (RuleViolation v : violations) {
            results.add(new Flow_Scan_Result__c(
                Flow_Scan__c          = scanId,
                Flow_API_Name__c      = v.flowApiName,
                Rule_Name__c          = v.ruleName,
                Severity__c           = v.severity,
                Element_Name__c       = v.elementName,
                Description__c        = v.description,
                Flow_Definition_Id__c = v.flowDefinitionId
            ));
        }
        insert results;
    }
}
}