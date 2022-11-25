
#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	ReadOnly = Not AllowedEditDocumentPrices;
	
	If Parameters.Key = Undefined Or Parameters.Key.IsEmpty() Then
		
		If Object.SharedUsageVariant.IsEmpty() Then
			Object.SharedUsageVariant = Enums.DiscountsApplyingRules.Max;
		EndIf;
		Object.Description = String(Object.SharedUsageVariant);
		
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

// Procedure - event handler OnChange item DiscountsSharedUsageOption.
//
&AtClient
Procedure SharedUsageVariantOfDiscountChargeOnChange(Item)
	
	If IsBlankString(Object.Description) Then
		Object.Description = String(Object.SharedUsageVariant);
	Else
		For Each ItemOfList In Items.SharedUsageVariantOfDiscountCharge.ChoiceList Do
			If String(ItemOfList.Value) = Object.Description Then
				Object.Description = String(Object.SharedUsageVariant);
				Break;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion
