public class FHCPostInstallScript implements InstallHandler {

    public void onInstall(InstallContext context) {
        // Run on both fresh install and upgrade
        try {
            assignAdminPermissionSet(context.installerID());
        } catch (Exception e) {
            // Log silently — post-install script failure
            // should not block package installation
            System.debug(LoggingLevel.ERROR,
                'FHC Post-install script failed: ' + e.getMessage()
            );
        }
    }

    private void assignAdminPermissionSet(Id installerId) {
        if (installerId == null) return;

        // Find the FHC_Admin permission set
        List<PermissionSet> permSets = [
            SELECT Id FROM PermissionSet
            WHERE Name = 'FHC_Admin'
            AND NamespacePrefix = 'svfhc'
            LIMIT 1
        ];

        if (permSets.isEmpty()) return;

        // Check if already assigned — avoid duplicate error
        List<PermissionSetAssignment> existing = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId     = :installerId
            AND PermissionSetId  = :permSets[0].Id
            LIMIT 1
        ];

        if (!existing.isEmpty()) return;

        // Assign FHC_Admin to the installer
        insert new PermissionSetAssignment(
            AssigneeId      = installerId,
            PermissionSetId = permSets[0].Id
        );
    }
}