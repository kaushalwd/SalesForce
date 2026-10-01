global class APIResponse {
    public String status;
    public String requestId;
    public Object data;
    public String message;

    public APIResponse(String status, String requestId, Object data, String message) {
        this.status = status;
        this.requestId = requestId;
        this.data = data;
        this.message = message;
    }
}