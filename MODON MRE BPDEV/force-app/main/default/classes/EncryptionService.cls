public class EncryptionService {
    private static final String KEY = 'W1nt3rIsC0m1ng!0';
    private static final String IV = 'InitVector123456';
    
    // Encrypt a plain text string
    public static String encrypt(String plainText) {
        Blob keyBlob = Blob.valueOf(KEY);
        Blob ivBlob = Blob.valueOf(IV);
        Blob dataBlob = Blob.valueOf(plainText);
        
        Blob encrypted = Crypto.encrypt('AES128', keyBlob, ivBlob, dataBlob);
        return EncodingUtil.base64Encode(encrypted);
    }
    
    // Decrypt an encrypted Base64 string
    public static String decrypt(String encryptedText) {
        Blob keyBlob = Blob.valueOf(KEY);
        Blob ivBlob = Blob.valueOf(IV);
        Blob encryptedBlob = EncodingUtil.base64Decode(encryptedText);
        
        Blob decrypted = Crypto.decrypt('AES128', keyBlob, ivBlob, encryptedBlob);
        return decrypted.toString();
    }
}