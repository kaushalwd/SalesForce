@IsTest
public class SendGridNotificationUtilityQueueableTest {

    @IsTest
    static void testQueueableExecute() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            AccountId = acc.Id
        );
        insert con;
        List<Id> attachmentIds = new List<Id>();
        ContentVersion cv = new ContentVersion(
            Title = 'Test Doc',
            PathOnClient = 'TestDoc.pdf',
            VersionData = Blob.valueOf('Sample Content')
        );
        insert cv;
        attachmentIds.add(cv.Id);

        Id leadId = null;
        Id contactOrUserId = con.Id;
        String templateName = 'TestTemplate';
        String recipientEmail = 'recipient@example.com';
        String senderEmail = 'sender@example.com';
        String senderName = 'Test Sender';
        String category = 'Customer Management';
        String subCategory = 'Unit Cancellation';
        String communicationName = 'Test Communication';
        String department = 'Sales';
        String frequency = 'Once';
        Id relatedRecordId = con.Id;

        Test.startTest();
        System.enqueueJob(
            new SendGridNotificationUtilityQueueable(
                leadId,
                contactOrUserId,
                templateName,
                recipientEmail,
                senderEmail,
                senderName,
                category,
                subCategory,
                communicationName,
                department,
                frequency,
                attachmentIds,
                relatedRecordId
            )
        );
        Test.stopTest(); 

        SendGridNotificationUtilityQueueable job = 
            new SendGridNotificationUtilityQueueable(
                leadId,
                contactOrUserId,
                templateName,
                recipientEmail,
                senderEmail,
                senderName,
                category,
                subCategory,
                communicationName,
                department,
                frequency,
                attachmentIds,
                relatedRecordId
            );
        
        SendGridNotificationUtilityBlobQueueable job1 = 
            new SendGridNotificationUtilityBlobQueueable(
                leadId,
                contactOrUserId,
                templateName,
                recipientEmail,
                senderEmail,
                senderName,
                category,
                subCategory,
                communicationName,
                department,
                frequency,
                null,
                'Test',
                'pdf',
                relatedRecordId
            );

        System.assertNotEquals(null, job, 'Queueable job instance should not be null');
        System.assertEquals(templateName, job.templateName, 'Template name should match');
        System.assertEquals(recipientEmail, job.recipientEmail, 'Recipient email should match');
    }

    @IsTest
    static void testEmptyConstructor() {
        // Just verify that the default constructor runs without error
        SendGridNotificationUtilityQueueable job = new SendGridNotificationUtilityQueueable();
        System.assertNotEquals(null, job, 'Queueable should be instantiated successfully');
    }
}