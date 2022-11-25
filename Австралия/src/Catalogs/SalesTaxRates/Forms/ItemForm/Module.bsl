#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetEnabledVisible();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	CalculateCombinedRate();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CombinedOnChange(Item)
	
	SetEnabledVisible();
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersTaxComponents

&AtClient
Procedure TaxComponentsComponentOnChange(Item)
	
	CurrentData = Items.TaxComponents.CurrentData;
	
	If CurrentData <> Undefined Then
		
		If ValueIsFilled(CurrentData.Component) Then
			
			FillPropertyValues(CurrentData, GetComponentAttributes(CurrentData.Component));
			
		Else
			
			CurrentData.Agency = Undefined;
			CurrentData.Rate = 0;
			
		EndIf;
		
		CalculateCombinedRate();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TaxComponentsRateOnChange(Item)
	
	CalculateCombinedRate();
	
EndProcedure

&AtClient
Procedure TaxComponentsAfterDeleteRow(Item)
	
	CalculateCombinedRate();
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function GetComponentAttributes(Component)
	
	Return Common.ObjectAttributesValues(Component, "Agency,Rate");
	
EndFunction

&AtClient
Procedure SetEnabledVisible()
	
	Items.Agency.Visible = Not Object.Combined;
	Items.GroupComponents.Visible = Object.Combined;
	
	Items.Rate.Enabled = Not Object.Combined;
	
EndProcedure

&AtClient
Procedure CalculateCombinedRate()
	
	If Object.Combined Then
		Object.Rate = Object.TaxComponents.Total("Rate");
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