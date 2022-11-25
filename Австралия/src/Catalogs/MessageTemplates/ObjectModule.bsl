///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	If FillingData <> Undefined Then
		
		If Common.SubsystemExists("StandardSubsystems.Interactions")
			AND TypeOf(FillingData) = Type("DocumentRef.OutgoingEmail") Then
				FillOnBasisOutgoingEmail(FillingData, FillingText, StandardProcessing);
		ElsIf TypeOf(FillingData) = Type("Structure") Then 
				FillBasedOnStructure(FillingData, FillingText, StandardProcessing);
		EndIf;
		
	EndIf;
EndProcedure

#EndRegion

#Region Private

Procedure FillOnBasisOutgoingEmail(FillingData, FillingText, StandardProcessing)
	
	EmailSubject                             = FillingData.Subject;
	HTMLMessageTemplateText                 = FillingData.HTMLText;
	MessageTemplateText                     = FillingData.Text;
	EmailSubject                             = FillingData.Subject;
	Description                           = FillingData.Subject;
	ForEmails        = True;
	ForSMSMessages                     = False;
	InputOnBasisParameterTypeFullName = NStr("ru = 'Общий'; en = 'Common'; pl = 'Wspólny';es_ES = 'Común';es_CO = 'Común';tr = 'Ortak';it = 'Comune';de = 'Allgemein'");
	MailTextType = Enums.EmailEditingMethods.NormalText;
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsInternal = Common.CommonModule("EmailOperationsInternal");
		HTMLEmailsTextTypes = ModuleEmailOperationsInternal.EmailTextTypes("HTML");
		HTMLEmailsWithPicturesTextsTypes = ModuleEmailOperationsInternal.EmailTextTypes("HTMLWithPictures");
		
		If FillingData.TextType = HTMLEmailsTextTypes
			OR FillingData.TextType = HTMLEmailsWithPicturesTextsTypes Then
			MailTextType = Enums.EmailEditingMethods.HTML;
		EndIf;
	
	EndIf;
	
EndProcedure

Procedure FillBasedOnStructure(FillingData, FillingText, StandardProcessing)
	
	TemplateParameters = MessageTemplates.TemplateParametersDetails();
	CommonClientServer.SupplementStructure(TemplateParameters, FillingData, True);
	
	FillPropertyValues(ThisObject, TemplateParameters);
	AttachmentFormat = New ValueStorage(TemplateParameters.AttachmentsFormats);
	
	If TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("ForSMSMessages")
		AND FillingData.ForSMSMessages Then
			TemplateParameters.TemplateType = "SMS";
	EndIf;
	
	If ValueIsFilled(TemplateParameters.ExternalDataProcessor) Then
		TemplateByExternalDataProcessor = True;
	EndIf;
	
	If ValueIsFilled(TemplateParameters.FullAssignmentTypeName) Then
		ObjectMetadata = Metadata.FindByFullName(TemplateParameters.FullAssignmentTypeName);
		InputOnBasisParameterTypeFullName = TemplateParameters.FullAssignmentTypeName;
		Purpose= ObjectMetadata.Presentation();
		ForInputOnBasis = True;
	EndIf;
	
	If TemplateParameters.TemplateType = "Email" Then
		
		ForSMSMessages              = False;
		ForEmails = True;
		EmailSubject                      = TemplateParameters.Subject;
		
		If TemplateParameters.EmailFormat = Enums.EmailEditingMethods.HTML Then
			HTMLMessageTemplateText = StrReplace(TemplateParameters.Text, Chars.LF, "<BR>");
			MailTextType        = Enums.EmailEditingMethods.HTML;
		Else
			MessageTemplateText = StrReplace(TemplateParameters.Text, "<BR>", Chars.LF);
			MailTextType    = Enums.EmailEditingMethods.NormalText;
		EndIf;
		
	ElsIf TemplateParameters.TemplateType = "SMS" Then
		
		ForSMSMessages              = True;
		ForEmails = False;
		SMSTemplateText                 = TemplateParameters.Text;
		SendInTransliteration            = False;
		
	ElsIf TemplateParameters.TemplateType = "Common" Then
		
		ForSMSMessages              = False;
		ForEmails = False;
		
	EndIf;
EndProcedure

#EndRegion

#Else
Raise NStr("ru = 'Недопустимый вызов объекта на клиенте.'; en = 'Invalid object call on the client.'; pl = 'Niepoprawne wywołanie obiektu na kliencie.';es_ES = 'Invalidar la llamada de objeto al cliente.';es_CO = 'Invalidar la llamada de objeto al cliente.';tr = 'İstemcide geçersiz nesne çağrısı.';it = 'Oggetto non valido per il client.';de = 'Ungültiger Objektaufruf auf dem Client.'");
#EndIf