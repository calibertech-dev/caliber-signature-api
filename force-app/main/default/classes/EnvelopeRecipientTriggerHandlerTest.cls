@IsTest
private class EnvelopeRecipientTriggerHandlerTest {

    @IsTest
    static void test_beforeInsert_sets_parent_name() {
        // Arrange: create a Contact to act as the parent record
        Contact con = new Contact(
            LastName = 'Signer'
        );
        insert con;

        // Re-query to get Name (e.g., "Signer")
        con = [
            SELECT Name
            FROM Contact
            WHERE Id = :con.Id
        ];

        // Minimal Envelope__c; fill any required fields if you have them
        Envelope__c env = new Envelope__c(
            // If Name is required and text, set it here:
            // Name = 'Test Envelope'
        );
        insert env;

        // Act: insert Envelope_Recipient__c pointing at the Contact
        Envelope_Recipient__c rec = new Envelope_Recipient__c(
            Envelope__c           = env.Id,
            Parent_Record_Type__c = 'Contact', // standard object API name
            Parent_Record_Id__c   = con.Id
            // set any other required fields for Envelope_Recipient__c
        );
        insert rec;

        // Assert: name should be set to the Contact's Name
        rec = [
            SELECT Parent_Record_Name__c
            FROM Envelope_Recipient__c
            WHERE Id = :rec.Id
        ];

        System.assertEquals(
            con.Name,
            rec.Parent_Record_Name__c,
            'Parent_Record_Name__c should be populated from the Contact Name on insert.'
        );
    }
}
