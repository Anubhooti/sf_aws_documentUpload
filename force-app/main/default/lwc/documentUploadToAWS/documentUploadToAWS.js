import { LightningElement } from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import uploadFileToAWS from '@salesforce/apex/AWSFileUploadController.uploadFileToAWS';
export default class DocumentUploadToAWS extends LightningElement {
    selectedFilesToUpload = [];
    fileName;
    fileType;
    fileBlob;
    fileReader;
    fileContentsBase64;
    showSpinner = false;
    handleSelectedFile(event){
        this.selectedFilesToUpload = event.target.files;
        this.fileName = this.selectedFilesToUpload[0].name;
        this.fileType = this.selectedFilesToUpload[0].type;
        this.fileBlob = this.selectedFilesToUpload[0];
        console.log('FILE name : ' , this.fileName);        
    }

    handleFileUpload(){
        console.log('button clicked');
        
        if(this.selectedFilesToUpload.length > 0){
            this.showSpinner = true;
            console.log('file selected');
            this.fileReader = new FileReader();
            this.fileReader.onload = (()=>{
                console.log('content');
                let fileContents = this.fileReader.result; 
                this.fileContentsBase64 = fileContents.substr(fileContents.indexOf(',')+1); 
                console.log('content : ', encodeURIComponent(this.fileContentsBase64));
                this.uploadFile();
            });
            this.fileReader.readAsDataURL(this.fileBlob);           
        }else{
            console.log('No files');            
            this.displayNotification('File Store Error', 'Please select a file first', 'error');
        }
    }

    uploadFile(){
        uploadFileToAWS({
            fileName : this.fileName,
            fileType : this.fileType,
            fileContent : encodeURIComponent(this.fileContentsBase64)
        }).then(result => {
            console.log('SUCCESSSSSSS : ', result);
            this.showSpinner = false;
            this.displayNotification('File Uploaded', 'File has been added to AWS', 'success');
        }).catch(error => {
            console.log('ERROR : ', error);
            this.showSpinner = false;
            this.displayNotification('Error', 'File upload failed', 'error');
        }               
        );
    }

    displayNotification(title, message, variant){
        this.dispatchEvent(new ShowToastEvent({
            title : title,
            message : message,
            variant : variant
        }));
    }
}