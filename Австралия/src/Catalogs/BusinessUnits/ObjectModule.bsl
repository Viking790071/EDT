#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "GLAccountInRetail");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "MarkupGLAccount")
	EndIf;
	
	If StructuralUnitType = Enums.BusinessUnitsTypes.Department
		Or StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RetailPriceKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "GLAccountInRetail");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "MarkupGLAccount");
	EndIf;
	
	If StructuralUnitType = Enums.BusinessUnitsTypes.Retail Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "GLAccountInRetail");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "MarkupGLAccount");
	EndIf;
	
	If PlanningInterval <> Enums.PlanningIntervals.Minute Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PlanningIntervalDuration");
	EndIf;
	
	If Not IsFolder And (Ref = Catalogs.BusinessUnits.GoodsInTransit
		Or Ref = Catalogs.BusinessUnits.DropShipping) Then
		
		CheckedAttributes.Clear();
		
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	GLAccountInRetail = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Inventory");
	MarkupGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("RetailMarkup");

EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	AdditionalProperties.Insert("IsNew", IsNew());
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.IsNew Then
		InformationRegisters.BatchTrackingPolicy.CreateDefaultTrackingPolicy(Undefined, Ref);
	EndIf;
	
EndProcedure
#EndRegion

#EndIf