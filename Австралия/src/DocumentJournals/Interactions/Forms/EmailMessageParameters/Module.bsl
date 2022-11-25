///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillFormAttributesFromParameters(Parameters);
	AvailabilityControl();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("SelectAndClose", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OkCommand(Command)
	
	SelectAndClose();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SelectAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	If Folder <> CurrentFolder Then
		SetEmailFolder();
	EndIf;
	
	If EmailType = "OutgoingEmail" AND SentReceived = Date(1,1,1) AND Modified Then
		
		SelectionResult = New Structure;
		SelectionResult.Insert("RequestDeliveryReceipt", RequestDeliveryReceipt);
		SelectionResult.Insert("RequestReadReceipt", RequestReadReceipt);
		SelectionResult.Insert("IncludeOriginalEmailBody", IncludeOriginalEmailBody);
		SelectionResult.Insert("Folder", Undefined);
		
	Else
		
		SelectionResult = Undefined;
		
	EndIf;
	
	Modified = False;
	NotifyChoice(SelectionResult);
	
EndProcedure

&AtServer
Procedure SetEmailFolder()
	
	Interactions.SetEmailFolder(Email, Folder);
	
EndProcedure

&AtServer
Procedure FillFormAttributeFromParameter(PassedParameters,ParameterName,AttributeName = "")

	If PassedParameters.Property(ParameterName) Then
		
		ThisObject[?(IsBlankString(AttributeName),ParameterName,AttributeName)] = PassedParameters[ParameterName];
		
	EndIf;

EndProcedure

&AtServer
Procedure FillFormAttributesFromParameters(PassedParameters)

	FillFormAttributeFromParameter(PassedParameters,"InternalNumber");
	FillFormAttributeFromParameter(PassedParameters,"Created");
	FillFormAttributeFromParameter(PassedParameters,"ReceivedEmails","SentReceived");
	FillFormAttributeFromParameter(PassedParameters,"Sent","SentReceived");
	FillFormAttributeFromParameter(PassedParameters,"RequestDeliveryReceipt");
	FillFormAttributeFromParameter(PassedParameters,"RequestReadReceipt");
	FillFormAttributeFromParameter(PassedParameters,"Email");
	FillFormAttributeFromParameter(PassedParameters,"EmailType");
	FillFormAttributeFromParameter(PassedParameters,"IncludeOriginalEmailBody");
	FillFormAttributeFromParameter(PassedParameters,"Account");
	
	InternetTitles.AddLine(PassedParameters.InternetTitles);
	
	Folder = Interactions.GetEmailFolder(Email);
	CurrentFolder = Folder;

EndProcedure

&AtServer
Procedure AvailabilityControl()

	If EmailType = "OutgoingEmail" Then
		Items.Headers.Title = NStr("ru = 'Идентификаторы'; en = 'IDs'; pl = 'Identyfikatory';es_ES = 'identificadores';es_CO = 'identificadores';tr = 'Kodlar';it = 'ID';de = 'IDs'");
		If SentReceived = Date(1,1,1) Then
			Items.RequestDeliveryReceipt.ReadOnly          = False;
			Items.RequestReadReceipt.ReadOnly         = False;
			Items.IncludeOriginalEmailBody.ReadOnly = False;
		EndIf;
	Else
		Items.SentReceived.Title = NStr("ru = 'Получено'; en = 'ReceivedEmails'; pl = 'Otrzymane wiadomości e-mail';es_ES = 'Correos electrónicos recibidos';es_CO = 'Correos electrónicos recibidos';tr = 'Alınanlar';it = 'Email ricevute';de = 'Empfangene E-Mails'");
		Items.IncludeOriginalEmailBody.Visible =False;
	EndIf;
	
	Items.Folder.Enabled = ValueIsFilled(Account);
	
EndProcedure

#EndRegion
