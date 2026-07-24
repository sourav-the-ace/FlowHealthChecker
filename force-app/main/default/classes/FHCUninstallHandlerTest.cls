@isTest
private class FHCUninstallHandlerTest {

    @isTest
    static void testOnUninstall_DeletesScanData() {
        // Create test scan data
        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c           = DateTime.now(),
            Status__c              = 'Complete',
            Total_Flows_Scanned__c = 1,
            Total_Violations__c    = 1
        );
        insert scan;

        Flow_Scan_Result__c result = new Flow_Scan_Result__c(
            Flow_Scan__c     = scan.Id,
            Flow_API_Name__c = 'Test_Flow',
            Rule_Name__c     = 'No Fault Path',
            Severity__c      = 'Error',
            Element_Name__c  = 'Create_Record',
            Description__c   = 'Test violation'
        );
        insert result;

        Test.startTest();
        FHCUninstallHandler handler = new FHCUninstallHandler();
        Test.testUninstall(handler);
        Test.stopTest();

        List<Flow_Scan__c> remainingScans = [
            SELECT Id FROM Flow_Scan__c WHERE Id = :scan.Id
        ];
        List<Flow_Scan_Result__c> remainingResults = [
            SELECT Id FROM Flow_Scan_Result__c WHERE Id = :result.Id
        ];

        System.assertEquals(0, remainingScans.size(),
            'All scan records should be deleted on uninstall');
        System.assertEquals(0, remainingResults.size(),
            'All scan result records should be deleted on uninstall');
    }

    @isTest
    static void testOnUninstall_EmptyOrg() {
        // No data — should run without error
        Test.startTest();
        FHCUninstallHandler handler = new FHCUninstallHandler();
        Test.testUninstall(handler);
        Test.stopTest();

        System.assert(true, 'Empty org uninstall handled gracefully');
    }
}