
#Region EventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ReadValues();
	
	Items.Signature.Visible = (Not Interactions.EmailClientUsed());
	
EndProcedure

&AtClient
Procedure AtAttributeChange(Item)
	
	SaveAttributeValue(Item.Name);
	
EndProcedure

&AtClient
Procedure SaveSignature(Command)
	
	SaveAttributeValue("SignatureFormattedDocument");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure ReadValues()
	
	AddSignatureForNewMessages = Common.CommonSettingsStorageLoad("EmailSettings", "AddSignatureForNewMessages", False);
	
	HTMLSignature = Common.CommonSettingsStorageLoad("EmailSettings", "HTMLSignature", "");
	If IsBlankString(HTMLSignature) Then
		DefaultSignature = Chars.LF + Chars.LF + "---------------------------------" + Chars.LF;
		HTMLSignature = New FormattedString(DefaultSignature);
		SignatureFormattedDocument.SetFormattedString(HTMLSignature);
	Else
		SignatureFormattedDocument.SetHTML(HTMLSignature, New Structure);
	EndIf;
	
	DefaultEmailAccount = DriveReUse.GetValueOfSetting("DefaultEmailAccount");
	
EndProcedure

&AtServer
Procedure SaveAttributeValue(ItemName)
	
	AttributePathToData = Items[ItemName].DataPath;
	
	If AttributePathToData = "DefaultEmailAccount" Then
		
		DriveServer.SetUserSetting(DefaultEmailAccount, "DefaultEmailAccount");
		
	EndIf;
	
	If AttributePathToData = "AddSignatureForNewMessages" Then
		
		Common.CommonSettingsStorageSave("EmailSettings", "AddSignatureForNewMessages", AddSignatureForNewMessages, , , True);
		
	EndIf;
	
	If AttributePathToData = "SignatureFormattedDocument" Then
		
		HTMLSignature = "";
		Attachments = New Structure;
		SignatureFormattedDocument.GetHTML(HTMLSignature, Attachments);
		
		Common.CommonSettingsStorageSave("EmailSettings", "HTMLSignature", HTMLSignature, , , True);
		Common.CommonSettingsStorageSave("EmailSettings", "SignatureSimpleText", SignatureFormattedDocument.GetText(), , , True);
		
	EndIf;
	
EndProcedure

#EndRegion
