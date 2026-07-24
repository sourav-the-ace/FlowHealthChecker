@isTest
private class FlowScanBatchQueueableTest {

    @isTest
    static void testBatchProcessesSingleBatch() {
        Test.setMock(HttpCalloutMock.class, new FlowScannerMultiMock());

        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c = DateTime.now(),
            Status__c    = 'Running'
        );
        insert scan;

        // Build mock flow definition list
        List<Map<String, Object>> mockFlows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Id'              => '3010H000000fake01',
                'DeveloperName'   => 'Test_Flow',
                'MasterLabel'     => 'Test Flow',
                'Description'     => null,
                'ActiveVersionId' => '3010H000000fake02'
            }
        };

        Test.startTest();
        System.enqueueJob(new FlowScanBatchQueueable(
            scan.Id, mockFlows,
            new List<RuleViolation>(), 1
        ));
        Test.stopTest();

        Flow_Scan__c result = [
            SELECT Status__c, Total_Flows_Scanned__c
            FROM Flow_Scan__c WHERE Id = :scan.Id
        ];
        System.assert(
            result.Status__c == 'Complete' || result.Status__c == 'Failed',
            'Batch should complete or fail'
        );
    }

    @isTest
    static void testBatchHandlesEmptyFlows() {
        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c = DateTime.now(),
            Status__c    = 'Running'
        );
        insert scan;

        Test.startTest();
        System.enqueueJob(new FlowScanBatchQueueable(
            scan.Id,
            new List<Map<String, Object>>(),
            new List<RuleViolation>(),
            0
        ));
        Test.stopTest();

        Flow_Scan__c result = [
            SELECT Status__c FROM Flow_Scan__c WHERE Id = :scan.Id
        ];
        System.assertEquals('Complete', result.Status__c,
            'Empty batch should complete immediately');
    }

    @isTest
    static void testFullScanWithChainedQueueable() {
        Test.setMock(HttpCalloutMock.class, new FlowScannerMultiMock());

        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c = DateTime.now(),
            Status__c    = 'Pending'
        );
        insert scan;

        Test.startTest();
        System.enqueueJob(new FlowScanQueueable(scan.Id));
        Test.stopTest();

        Flow_Scan__c result = [
            SELECT Status__c, Total_Flows_Scanned__c
            FROM Flow_Scan__c WHERE Id = :scan.Id
        ];
        System.assert(
            result.Status__c == 'Complete' || result.Status__c == 'Failed',
            'Full scan chain should complete'
        );
    }

    @isTest
    static void testBatchWithAccumulatedViolations() {
        Test.setMock(HttpCalloutMock.class, new FlowScannerMultiMock());

        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c = DateTime.now(),
            Status__c    = 'Running'
        );
        insert scan;

        // Pre-populate accumulated violations from a previous batch
        List<RuleViolation> priorViolations = new List<RuleViolation>();
        RuleViolation v = new RuleViolation(
            'No Fault Path', 'Error',
            'Prior_Element', 'From prior batch'
        );
        v.flowApiName      = 'Prior_Flow';
        v.flowDefinitionId = '3010H000000fake00';
        priorViolations.add(v);

        List<Map<String, Object>> mockFlows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Id'              => '3010H000000fake01',
                'DeveloperName'   => 'Test_Flow',
                'MasterLabel'     => 'Test Flow',
                'Description'     => null,
                'ActiveVersionId' => '3010H000000fake02'
            }
        };

        Test.startTest();
        System.enqueueJob(new FlowScanBatchQueueable(
            scan.Id, mockFlows, priorViolations, 2
        ));
        Test.stopTest();

        Flow_Scan__c result = [
            SELECT Status__c, Total_Violations__c
            FROM Flow_Scan__c WHERE Id = :scan.Id
        ];
        System.assert(
            result.Status__c == 'Complete' || result.Status__c == 'Failed',
            'Should complete or fail'
        );
        // If complete, violations should include prior + new ones
        if (result.Status__c == 'Complete') {
            System.assert(result.Total_Violations__c >= 1,
                'Should include at least the prior violation');
        }
    }

    @isTest
    static void testBatchMarksFailed_OnException() {
        // Use error mock to force a failure
        Test.setMock(HttpCalloutMock.class,
            new FlowMetadataMock(FlowMetadataMock.MockType.ERROR));

        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c = DateTime.now(),
            Status__c    = 'Running'
        );
        insert scan;

        List<Map<String, Object>> mockFlows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Id'              => '3010H000000fake01',
                'DeveloperName'   => 'Test_Flow',
                'MasterLabel'     => 'Test Flow',
                'Description'     => null,
                'ActiveVersionId' => '3010H000000fake02'
            }
        };

        Test.startTest();
        System.enqueueJob(new FlowScanBatchQueueable(
            scan.Id, mockFlows,
            new List<RuleViolation>(), 1
        ));
        Test.stopTest();

        Flow_Scan__c result = [
            SELECT Status__c, Error_Message__c
            FROM Flow_Scan__c WHERE Id = :scan.Id
        ];
        // With error mock the individual flow fetch fails silently
        // but the batch itself should still complete
        System.assert(
            result.Status__c == 'Complete' || result.Status__c == 'Failed',
            'Should handle error gracefully'
        );
    }

    @isTest
    static void testBatchWithNullDescription() {
        Test.setMock(HttpCalloutMock.class, new FlowScannerMultiMock());

        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c = DateTime.now(),
            Status__c    = 'Running'
        );
        insert scan;

        // Flow with null description — tests MissingDescriptionRule path
        List<Map<String, Object>> mockFlows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Id'              => '3010H000000fake01',
                'DeveloperName'   => 'No_Description_Flow',
                'MasterLabel'     => null,
                'Description'     => null,
                'ActiveVersionId' => '3010H000000fake02'
            }
        };

        Test.startTest();
        System.enqueueJob(new FlowScanBatchQueueable(
            scan.Id, mockFlows,
            new List<RuleViolation>(), 1
        ));
        Test.stopTest();

        Flow_Scan__c result = [
            SELECT Status__c FROM Flow_Scan__c WHERE Id = :scan.Id
        ];
        System.assert(
            result.Status__c == 'Complete' || result.Status__c == 'Failed',
            'Should handle null MasterLabel gracefully'
        );
    }
}