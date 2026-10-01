public class TranslationWrapper{
    public TranslationData[] arabicNames;
    public String result;
    public String errorDescription;
    public String errorCode;
	public class TranslationData{
		public String english;
		public String arabic;
	}
	
	public static TranslationWrapper parse(String json){
	return (TranslationWrapper) System.JSON.deserialize(json, TranslationWrapper.class);
    }
}