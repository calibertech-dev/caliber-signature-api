@IsTest
private class EnvelopeTriggerHandlerTest {

    @IsTest
    static void test_beforeInsert_sets_parent_name() {
        // Arrange: create a parent Contract (Title is just for your own purposes)
        Contract__c c1 = new Contract__c(
            Contract_Title__c = 'Test Contract 1'
            // add any other required fields for Contract__c here
        );
        insert c1;

        // Re-query to get the auto-number Name field
        c1 = [
            SELECT Name
            FROM Contract__c
            WHERE Id = :c1.Id
        ];

        // Act: insert Envelope__c pointing at that Contract
        Envelope__c env = new Envelope__c(
            Parent_Record_Type__c = 'Contract__c',
            Parent_Record_Id__c   = c1.Id
            // add any other required fields for Envelope__c here
        );
        insert env;

        // Assert: trigger ran, handler called PolymorphicRecordNameService, name got populated from Name
        env = [
            SELECT Parent_Record_Name__c
            FROM Envelope__c
            WHERE Id = :env.Id
        ];

        System.assertEquals(
            c1.Name,
            env.Parent_Record_Name__c,
            'Parent_Record_Name__c should be populated from the Contract Name (auto-number) on insert.'
        );
    }

    @IsTest
    static void test_beforeUpdate_recalculates_and_clears_name() {
        // Arrange: two parent Contracts
        Contract__c c1 = new Contract__c(
            Contract_Title__c = 'Parent Contract 1'
        );
        Contract__c c2 = new Contract__c(
            Contract_Title__c = 'Parent Contract 2'
        );
        insert new List<Contract__c>{ c1, c2 };

        // Re-query to get the auto-number Names
        Map<Id, Contract__c> contractsById = new Map<Id, Contract__c>([
            SELECT Id, Name
            FROM Contract__c
            WHERE Id IN :new List<Id>{ c1.Id, c2.Id }
        ]);
        c1 = contractsById.get(c1.Id);
        c2 = contractsById.get(c2.Id);

        // Insert Envelope pointing to c1
        Envelope__c env = new Envelope__c(
            Parent_Record_Type__c = 'Contract__c',
            Parent_Record_Id__c   = c1.Id
            // add any other required fields for Envelope__c here
        );
        insert env;

        env = [
            SELECT Parent_Record_Name__c, Parent_Record_Id__c, Parent_Record_Type__c
            FROM Envelope__c
            WHERE Id = :env.Id
        ];
        System.assertEquals(
            c1.Name,
            env.Parent_Record_Name__c,
            'Sanity check: initial name should match first parent Name.'
        );

        // Act 1: change parent to c2 and update
        env.Parent_Record_Id__c = c2.Id;
        update env;

        env = [
            SELECT Parent_Record_Name__c
            FROM Envelope__c
            WHERE Id = :env.Id
        ];
        System.assertEquals(
            c2.Name,
            env.Parent_Record_Name__c,
            'Parent_Record_Name__c should update when Parent_Record_Id__c changes.'
        );

        // Act 2: clear parent type/id -> name should be nulled
        env.Parent_Record_Type__c = null;
        env.Parent_Record_Id__c   = null;
        update env;

        env = [
            SELECT Parent_Record_Name__c
            FROM Envelope__c
            WHERE Id = :env.Id
        ];
        System.assertEquals(
            null,
            env.Parent_Record_Name__c,
            'Parent_Record_Name__c should be cleared when parent type and id are blank.'
        );
    }
}
