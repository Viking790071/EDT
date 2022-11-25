
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	SaveDecrypted = 1;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureClientServer =
			Common.CommonModule("DigitalSignatureClientServer");
		
		EncryptedFilesExtension = 
			ModuleDigitalSignatureClientServer.PersonalSettings().EncryptedFilesExtension;
	Else
		EncryptedFilesExtension = "p7m";
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommonClientServer.SetFormItemProperty(Items, "SaveDecrypted", "RadioButtonType", RadioButtonType.RadioButton);
		CommonClientServer.SetFormItemProperty(Items, "FormSaveFile", "Representation", ButtonRepresentation.Picture);
		CommonClientServer.SetFormItemProperty(Items, "FormCancel", "Visible", False);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SaveFile(Command)
	
	ReturnStructure = New Structure;
	ReturnStructure.Insert("SaveDecrypted", SaveDecrypted);
	ReturnStructure.Insert("EncryptedFilesExtension", EncryptedFilesExtension);
	
	Close(ReturnStructure);
	
EndProcedure

#EndRegion
