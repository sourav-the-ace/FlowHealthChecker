public with sharing class FlowHealthCheckerController {

    @AuraEnabled
    public static Map<String, Object> getScanResults(Id scanId) {
        if (!Schema.sObjectType.Flow_Scan__c.isAccessible()) {
            throw new AuraHandledException(
                'You do not have permission to view Flow Scan records. '
                + 'Please contact your administrator.'
            );
        }
        if (!Schema.sObjectType.Flow_Scan_Result__c.isAccessible()) {
            throw new AuraHandledException(
                'You do not have permission to view Flow Scan Result records. '
                + 'Please contact your administrator.'
            );
        }

        Flow_Scan__c scan = [
            SELECT Id, Scan_Date__c, Total_Flows_Scanned__c,
                   Total_Violations__c, Status__c
            FROM Flow_Scan__c
            WHERE Id = :scanId
            LIMIT 1
        ];

        List<Flow_Scan_Result__c> results = [
            SELECT Id, Flow_API_Name__c, Rule_Name__c, Severity__c,
                   Element_Name__c, Description__c, Flow_Definition_Id__c
            FROM Flow_Scan_Result__c
            WHERE Flow_Scan__c = :scanId
            ORDER BY Severity__c ASC
        ];

        return new Map<String, Object>{
            'scan'    => scan,
            'results' => results
        };
    }

    @AuraEnabled(cacheable=true)
    public static List<Flow_Rule__mdt> getRules() {
        return [
            SELECT MasterLabel, svfhc__Severity__c, svfhc__Active__c,
                   svfhc__Description__c, svfhc__Rule_Type__c
            FROM svfhc__Flow_Rule__mdt
            ORDER BY svfhc__Severity__c ASC, MasterLabel ASC
        ];
    }
}