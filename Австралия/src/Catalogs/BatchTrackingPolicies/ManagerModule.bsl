#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region LibrariesHandlers

#Region ObjectAttributesLock

// StandardSubsystems.ObjectAttributesLock

// See ObjectAttributesLockOverridable.OnDefineObjectsWithLockedAttributes.
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	
	AttributesToLock.Add("TrackingMethod");
	AttributesToLock.Add("UseTrackingArea_Inbound_FromSupplier");
	AttributesToLock.Add("UseTrackingArea_Inbound_SalesReturn");
	AttributesToLock.Add("UseTrackingArea_Inbound_Transfer");
	AttributesToLock.Add("UseTrackingArea_Outbound_SalesToCustomer");
	AttributesToLock.Add("UseTrackingArea_Outbound_PurchaseReturn");
	AttributesToLock.Add("UseTrackingArea_Outbound_Transfer");
	AttributesToLock.Add("UseTrackingArea_PhysicalInventory");
	AttributesToLock.Add("UseTrackingArea_InventoryIncrease");
	AttributesToLock.Add("UseTrackingArea_InventoryWriteOff");
	
	Return AttributesToLock;
	
EndFunction

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(ChoiceData,
		Parameters, StandardProcessing, Metadata.Catalogs.BatchTrackingPolicies);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region Internal

Function DefaultAreas(Method) Export
	
	Result = New Structure;
	
	Result.Insert("UseTrackingArea_Inbound_FromSupplier", False);
	Result.Insert("UseTrackingArea_Inbound_SalesReturn", False);
	Result.Insert("UseTrackingArea_Inbound_Transfer", False);
	Result.Insert("UseTrackingArea_Outbound_SalesToCustomer", False);
	Result.Insert("UseTrackingArea_Outbound_PurchaseReturn", False);
	Result.Insert("UseTrackingArea_Outbound_Transfer", False);
	Result.Insert("UseTrackingArea_PhysicalInventory", False);
	Result.Insert("UseTrackingArea_InventoryIncrease", False);
	Result.Insert("UseTrackingArea_InventoryWriteOff", False);
	
	If Method = Enums.BatchTrackingMethods.FEFO
		Or Method = Enums.BatchTrackingMethods.Manual Then
		
		Result.UseTrackingArea_Inbound_FromSupplier = True;
		Result.UseTrackingArea_Inbound_SalesReturn = True;
		Result.UseTrackingArea_Inbound_Transfer = True;
		Result.UseTrackingArea_Outbound_SalesToCustomer = True;
		Result.UseTrackingArea_Outbound_PurchaseReturn = True;
		Result.UseTrackingArea_Outbound_Transfer = True;
		Result.UseTrackingArea_PhysicalInventory = True;
		Result.UseTrackingArea_InventoryIncrease = True;
		Result.UseTrackingArea_InventoryWriteOff = True;
		
	ElsIf Method = Enums.BatchTrackingMethods.Referential Then
		
		Result.UseTrackingArea_Inbound_FromSupplier = True;
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf