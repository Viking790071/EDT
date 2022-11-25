#Region Internal

Procedure SetPrintOptions(PrintParameters, ObjectsArray) Export
	
	PrintParameters.AdditionalParameters.Insert("Result", Undefined);
	
	If Not PrintManagementServerCallDrive.CheckPrintFormSettings(PrintParameters.ID) Then
		Return;
	EndIf;
	
	If GetFunctionalOption("DisplayPrintOptionsBeforePrinting") Then
		PrintOptions = PrintManagementServerCallDrive.GetPrintOptionsByUsers(ObjectsArray[0], PrintParameters.ID);
		If PrintOptions.PrintCommandID <> PrintParameters.ID Then
			PrintOptions = PrintManagementServerCallDrive.ProgramPrintingPrintOptionsStructure(True);
		EndIf;
		PrintParameters.AdditionalParameters.Result = PrintOptions;
	EndIf;
	
EndProcedure

Procedure OnFillRecipientsEmailsInMessage(EmailRecipients, ObjectRef) Export
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		
		ContactInformationType = ModuleContactsManager.ContactInformationTypeByDescription("EmailAddress");
		
		If EmailRecipients.Count() = 0 Then
			
			ObjectsWithContactInformation = DriveContactInformationServer.GetContactsRefs(ObjectRef);
			
			If ObjectsWithContactInformation.Count() > 0 Then
				
				ObjectsContactInformation = ModuleContactsManager.ObjectsContactInformation(ObjectsWithContactInformation,
					ContactInformationType,
					,
					CurrentSessionDate());
				
				If ObjectsContactInformation.Count() > 0 Then
					
					For Each ObjectContactInformation In ObjectsContactInformation Do
						
						NewRow = EmailRecipients.Add();
						NewRow.Address = ObjectContactInformation.Presentation;
						NewRow.Presentation = StrReplace(String(ObjectContactInformation.Object), ",", "");
						NewRow.Contact = ObjectContactInformation.Object;
						
					EndDo;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure OnFillRecipientsPhonesInMessage(SMSMessageRecipients, ObjectRef) Export
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		
		ContactInformationType = ModuleContactsManager.ContactInformationTypeByDescription("Phone");
		
		If SMSMessageRecipients.Count() = 0 Then
			
			ObjectsWithContactInformation = DriveContactInformationServer.GetContactsRefs(ObjectRef);
			
			If ObjectsWithContactInformation.Count() > 0 Then
				
				ObjectsContactInformation = ModuleContactsManager.ObjectsContactInformation(ObjectsWithContactInformation,
					ContactInformationType,
					,
					CurrentSessionDate());
				
				If ObjectsContactInformation.Count() > 0 Then
					
					For Each ObjectContactInformation In ObjectsContactInformation Do
						
						NewRow = SMSMessageRecipients.Add();
						NewRow.PhoneNumber = ObjectContactInformation.Presentation;
						NewRow.Presentation = StrReplace(String(ObjectContactInformation.Object), ",", "");
						NewRow.Contact = ObjectContactInformation.Object;
						
					EndDo;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion