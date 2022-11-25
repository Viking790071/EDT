
#Region FormEventHandlers

&AtClient
Procedure OnOpen(Cancel)
	SetValueVisibility();
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "GLAccountsChanged" Then
		Object.GLAccount		= Parameter.GLAccount;
		Object.GLExpenseAccount	= Parameter.GLExpenseAccount;
		Modified				= True;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure


#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ChargeTypeOnChange(Item)
	SetValueVisibility();
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetValueVisibility()
	
	If Object.ChargeType = Enums.ChargeMethod.SpecialExchangeRate Then 
		Value = 0;
		Items.Value.Enabled = False;
	Else
		Items.Value.Enabled = True;
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion
