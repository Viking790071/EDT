#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ThisInstance = FormAttributeToValue("Object");
	SpreadsheetDocument = ThisInstance.ReportResult.Get();
	If SpreadsheetDocument <> Undefined Then
		ReportResult = SpreadsheetDocument;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.ReportResult = New ValueStorage(ReportResult);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SendByEmail(Command)
	
	ReportTypeDescription = String(Object.ReportType);
	Attachment = New Structure;
	Attachment.Insert("AddressInTempStorage", PutToTempStorage(ReportResult, UUID));
	Attachment.Insert("Presentation", ReportTypeDescription);
	
	Attachments = CommonClientServer.ValueInArray(Attachment);
	
	If CommonClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsClient = CommonClient.CommonModule("EmailOperationsClient");
		SendOptions = ModuleEmailOperationsClient.EmailSendOptions();
		SendOptions.Subject = ReportTypeDescription;
		SendOptions.Attachments = Attachments;
		ModuleEmailOperationsClient.CreateNewEmailMessage(SendOptions);
	EndIf;
	
EndProcedure

#EndRegion
