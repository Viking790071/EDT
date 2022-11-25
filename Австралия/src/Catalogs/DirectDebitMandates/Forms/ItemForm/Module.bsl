
#Region FormEventHandlers

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	ComposeDesctiptionOnServer();
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End of StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	If Object.Ref.IsEmpty() Then
		If Parameters.FillingValues <> Undefined Then
			If parameters.FillingValues.Property("Company") Then
				Object.Company = Parameters.FillingValues.Company;
				Items.Company.Type = FormFieldType.LabelField;
			EndIf;
			
			If Parameters.FillingValues.Property("Owner") Then
				Object.Owner = Parameters.FillingValues.Owner;
				Items.Owner.Type = FormFieldType.LabelField;
			EndIf;
		EndIf;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		Object.DirectDebitSequenceType = enums.DirectDebitSequenceTypes.OOFF;
		Object.SEPAPurposeCode = "OTHR";
	Else
		Items.SetInterval.Enabled = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
EndProcedure

// StandardSubsystems.AttachableCommands

&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Object);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Object, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure

// End StandardSubsystems.AttachableCommands

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure MandateDateOnChange(Item)
	ComposeDesctiptionOnServer();
EndProcedure

&AtClient
Procedure MandateStatusOnChange(Item)
	ComposeDesctiptionOnServer();
EndProcedure

&AtClient
Procedure RecurringOnChange(Item)
	RecurringOnChangeAtServer();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtServer
Procedure ComposeDesctiptionOnServer()
	StructureData = GetComposedDescription(Object);
	Object.Description = StructureData.Description;
EndProcedure

&AtServerNoContext
Function GetComposedDescription(Item)
	
	StructureData = New Structure();
	StructureData.Insert("Description", Catalogs.DirectDebitMandates.ComposeDesctiption(Item));
	
	Return StructureData;
EndFunction

&AtServer
Procedure RecurringOnChangeAtServer()
	If Object.Recurring Then 
		Object.DirectDebitSequenceType = Enums.DirectDebitSequenceTypes.RCUR
	Else
		Object.DirectDebitSequenceType = Enums.DirectDebitSequenceTypes.OOFF;
	EndIf;
EndProcedure

&AtClient
Procedure SetInterval(Command)
	
	Dialog = New StandardPeriodEditDialog();
	Dialog.Period.StartDate	= Object.MandatePeriodFrom;
	Dialog.Period.EndDate	= Object.MandatePeriodTo;
	
	NotifyDescription = New NotifyDescription("SetIntervalCompleted", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure SetIntervalCompleted(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		Object.MandatePeriodFrom	= Result.StartDate;
		Object.MandatePeriodTo		= Result.EndDate;
	EndIf;
	
EndProcedure

#EndRegion


#Region Private

#Region LibrariesHandlers

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
	Items.SetInterval.Enabled = True;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
EndProcedure

#EndRegion

#EndRegion
