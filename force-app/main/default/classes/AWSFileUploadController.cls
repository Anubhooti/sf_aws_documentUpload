public with sharing class AWSFileUploadController {
    public static Integration_Credentials_Configuration__mdt credentials;
    public AWSFileUploadController() {
		
    }

    @AuraEnabled
    public static boolean uploadFileToAWS(String fileName, String fileType, String fileContent){

        credentials = [SELECT Id, MasterLabel,AWS_Bucket_Name__c,AWS_End_Point_Url__c,AWS_Host_Name__c,AWS_Key__c,AWS_Secret__c FROM Integration_Credentials_Configuration__mdt
                                                                 WHERE MasterLabel= 'AWS_DocumentUploadCenter' LIMIT 1];
        
              
        Datetime currentDatetime = Datetime.now();
        String request_formattedDateString = currentDatetime.formatGMT('EEE, dd MMM yyyy HH:mm:ss z');
        String formattedDateString = currentDatetime.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'');
        //String formattedDateString = currentDatetime.dateGMT().format('YYYYMMdd')+'T'+currentDatetime.timeGmt().format('HHmmss')+'Z';
        String scope =  currentDatetime.format('yyyyMMdd')+'/ap-south-1/s3/aws4_request' ;
        
        Blob fileContentBlob = EncodingUtil.base64Decode(EncodingUtil.urlDecode(fileContent, 'UTF-8'));
        String amz_content_sha256 = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', fileContentBlob));
        String method = 'PUT';
        String bucket = credentials.AWS_Bucket_Name__c;
        String fileIdentifier = formattedDateString + '_' + fileName;
        String endpoint=credentials.AWS_End_Point_Url__c+'/'+fileName;
        String CanonicalURI = '/'+fileName;
        String canonicalHeaders = 'content-length:'+String.valueOf(fileContentBlob.size())+'\n'+ 
                                    'content-type:'+fileType+'\n'+ 
                                    'date:' + request_formattedDateString+'\n'+
                                    'host:'+credentials.AWS_Host_Name__c +'\n'+                                    
                                    'x-amz-content-sha256:'+amz_content_sha256+'\n'+
                                    'x-amz-date:'+formattedDateString+'\n'+
                                    'x-amz-storage-class:'+'REDUCED_REDUNDANCY'+'\n';
        String signedHeaders = 'content-length;content-type;date;host;x-amz-content-sha256;x-amz-date;x-amz-storage-class';
        //String signedHeaders = 'date;host;x-amz-content-sha256;x-amz-date;x-amz-storage-class';
        /*<HTTPMethod>\n
        <CanonicalURI>\n
        <CanonicalQueryString>\n
        <CanonicalHeaders>\n
        <SignedHeaders>\n
        <HashedPayload>*/
        String canonicalRequest = 'PUT\n'+
                                    CanonicalURI+'\n\n'+
                                    canonicalHeaders+'\n'+
                                    signedHeaders+'\n'+
                                    amz_content_sha256;
        System.debug('canonicalRequest : ' + canonicalRequest);
        /* "AWS4-HMAC-SHA256" + "\n" +
        timeStampISO8601Format + "\n" +
        <Scope> + "\n" +
        Hex(SHA256Hash(<CanonicalRequest>)) */
        String stringToSign ='AWS4-HMAC-SHA256' + '\n' +
                                formattedDateString + '\n' +
                                scope + '\n' +
                                EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(canonicalRequest)));
        System.debug('stringToSign : ' + stringToSign);

        /*DateKey              = HMAC-SHA256("AWS4"+"<SecretAccessKey>", "<YYYYMMDD>")
        DateRegionKey        = HMAC-SHA256(<DateKey>, "<aws-region>")
        DateRegionServiceKey = HMAC-SHA256(<DateRegionKey>, "<aws-service>")
        SigningKey           = HMAC-SHA256(<DateRegionServiceKey>, "aws4_request") */
        String todayformat =  currentDatetime.format('yyyyMMdd');
        String key = 'AWS4'+credentials.AWS_Secret__c;
        Blob dateKey = Crypto.generateMac('hmacSHA256', Blob.valueOf(todayformat), Blob.valueOf(key));
        Blob dateRegionKey = Crypto.generateMac('hmacSHA256', Blob.valueOf('ap-south-1'), dateKey);
        Blob dateRegionServiceKey = Crypto.generateMac('hmacSHA256', Blob.valueOf('s3'), dateRegionKey);
        Blob signingKey = Crypto.generateMac('hmacSHA256', Blob.valueOf('aws4_request'), dateRegionServiceKey);

        Blob signature = Crypto.generateMac('hmacSHA256', Blob.valueOf(stringToSign), signingKey);
        /*AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request,SignedHeaders=date;host;x-amz-content-sha256;x-amz-date;x-amz-storage-class,Signature=98ad721746da40c64f1a55b78f14c238d841ea1380cd77a1b5971af0ece108bd */
        String auth = 'AWS4-HMAC-SHA256 Credential='+credentials.AWS_Key__c + '/' + todayformat + '/ap-south-1/s3/aws4_request,SignedHeaders='+signedHeaders+',Signature='+EncodingUtil.convertToHex(signature);
        System.debug('AUTH : '+ auth);
        HttpRequest request = new HttpRequest();
        request.setMethod(method);        
        request.setEndpoint(endpoint);
        request.setHeader('Host', credentials.AWS_Host_Name__c);
        request.setHeader('Authorization', auth);
        request.setHeader('Content-Type', fileType);
        request.setHeader('Content-Length', String.valueOf(fileContentBlob.size()));
        request.setHeader('Date', request_formattedDateString);
        request.setHeader('x-amz-content-sha256', amz_content_sha256);
        request.setHeader('x-amz-date', formattedDateString);
        request.setHeader('x-amz-storage-class', 'REDUCED_REDUNDANCY');

        request.setBodyAsBlob(fileContentBlob);

        try{
            System.debug('REQ endpoint : ' + request.getEndpoint());
            System.debug('REQ headers: ' + request.getHeader('Host'));
            System.debug('REQ headers: ' + request.getHeader('Content-Type'));
            System.debug('REQ headers: ' + request.getHeader('Content-Length'));
            System.debug('REQ headers: ' + request.getHeader('Date'));
            System.debug('REQ headers: ' + request.getHeader('x-amz-date'));
            System.debug('REQ headers: ' + request.getHeader('x-amz-content-sha256'));
            HttpResponse response = new Http().send(request);
            System.debug('STATUS:'+response.getStatus());
            System.debug('STATUS code:'+response.getStatusCode());
            System.debug('resp body :'+response.getBody());
            if(response.getStatusCode() == 200){
                return true;
            }
            return false;
        }catch(System.CalloutException exp){
            System.debug('erreur : '+exp);
            return false;
        }
        
    }
    
}