public class FileExportUtility {

    @AuraEnabled
    public static String createExportFile(String base64Content, String fileName) {

        if (String.isBlank(base64Content) || String.isBlank(fileName)) {
            throw new AuraHandledException('Nothing to export.');
        }

        ContentVersion cv = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = EncodingUtil.base64Decode(base64Content)
        );

        insert cv;

        return '/sfc/servlet.shepherd/version/download/' + cv.Id;
    }
}