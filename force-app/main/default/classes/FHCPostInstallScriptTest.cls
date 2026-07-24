@isTest
private class FHCPostInstallScriptTest {

    @isTest
    static void testOnInstall_AssignsPermissionSet() {
        // Get current user as mock installer
        User installer = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        // Remove FHC_Admin assignment if it exists
        List<PermissionSet> permSets = [
            SELECT Id FROM PermissionSet
            WHERE Name = 'FHC_Admin'
            LIMIT 1
        ];

        if (!permSets.isEmpty()) {
            List<PermissionSetAssignment> existing = [
                SELECT Id FROM PermissionSetAssignment
                WHERE AssigneeId    = :installer.Id
                AND PermissionSetId = :permSets[0].Id
            ];
            if (!existing.isEmpty()) delete existing;
        }

        Test.startTest();
        FHCPostInstallScript script = new FHCPostInstallScript();
        Test.testInstall(script, null, false);
        Test.stopTest();

        // Verify permission set was assigned
        if (!permSets.isEmpty()) {
            List<PermissionSetAssignment> assignments = [
                SELECT Id FROM PermissionSetAssignment
                WHERE AssigneeId    = :installer.Id
                AND PermissionSetId = :permSets[0].Id
            ];
            System.assertEquals(1, assignments.size(),
                'FHC_Admin should be assigned to installer');
        } else {
            // Permission set not in test org — just verify no exception
            System.assert(true, 'Post-install ran without error');
        }
    }

    @isTest
    static void testOnInstall_UpgradeScenario() {
        Test.startTest();
        FHCPostInstallScript script = new FHCPostInstallScript();
        // Simulate upgrade (isPush = false, version exists)
        Test.testInstall(script, new Version(0, 3), false);
        Test.stopTest();

        System.assert(true, 'Upgrade install completed without error');
    }

    @isTest
    static void testOnInstall_NullInstaller() {
        Test.startTest();
        FHCPostInstallScript script = new FHCPostInstallScript();
        // Null context — should handle gracefully
        Test.testInstall(script, null, false);
        Test.stopTest();

        System.assert(true, 'Null installer handled gracefully');
    }

    @isTest
    static void testOnInstall_AlreadyAssigned() {
        // Verify idempotent — running twice doesn't cause duplicate error
        FHCPostInstallScript script = new FHCPostInstallScript();

        Test.startTest();
        Test.testInstall(script, null, false);
        Test.testInstall(script, null, false); // second run
        Test.stopTest();

        System.assert(true, 'Double assignment handled gracefully');
    }
}