#Region FormEventHandlers

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Key.IsEmpty() And ValueIsFilled(Object.TrackingMethod) Then
		TrackingMethodOnChangeAtServer();
		Object.Description = Object.TrackingMethod;
	EndIf;
	
	SetTrackingAreasEditable();
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	If Not Parameters.Key.IsEmpty() Then
		Items.UseTrackingArea_Inbound.ReadOnly = True;
		Items.UseTrackingArea_Outbound.ReadOnly = True;
	EndIf;
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	Items.UseTrackingArea_Inbound.ReadOnly = True;
	Items.UseTrackingArea_Outbound.ReadOnly = True;
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	CalculateUseTrackingArea_Inbound();
	CalculateUseTrackingArea_Outbound();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure TrackingMethodOnChange(Item)
	
	TrackingMethodOnChangeAtServer();
	CalculateUseTrackingArea_Inbound();
	CalculateUseTrackingArea_Outbound();
	
	Object.Description = Object.TrackingMethod;
	
EndProcedure

&AtClient
Procedure UseTrackingArea_InboundOnChange(Item)
	
	If UseTrackingArea_Inbound = 2 Then
		UseTrackingArea_Inbound = 0;
	EndIf;
	
	Object.UseTrackingArea_Inbound_FromSupplier = UseTrackingArea_Inbound;
	Object.UseTrackingArea_Inbound_SalesReturn = UseTrackingArea_Inbound;
	Object.UseTrackingArea_Inbound_Transfer = UseTrackingArea_Inbound;
	
	CalculateUseTrackingArea_Inbound();
	
EndProcedure

&AtClient
Procedure UseTrackingArea_Inbound_FromSupplierOnChange(Item)
	
	CalculateUseTrackingArea_Inbound();
	
EndProcedure

&AtClient
Procedure UseTrackingArea_Inbound_SalesReturnOnChange(Item)
	
	CalculateUseTrackingArea_Inbound();
	
EndProcedure

&AtClient
Procedure UseTrackingArea_Inbound_TransferOnChange(Item)
	
	CalculateUseTrackingArea_Inbound();
	
EndProcedure

&AtClient
Procedure UseTrackingArea_OutboundOnChange(Item)
	
	If UseTrackingArea_Outbound = 2 Then
		UseTrackingArea_Outbound = 0;
	EndIf;
	
	Object.UseTrackingArea_Outbound_SalesToCustomer = UseTrackingArea_Outbound;
	Object.UseTrackingArea_Outbound_PurchaseReturn = UseTrackingArea_Outbound;
	Object.UseTrackingArea_Outbound_Transfer = UseTrackingArea_Outbound;
	
	CalculateUseTrackingArea_Outbound();
	
EndProcedure

&AtClient
Procedure UseTrackingArea_Outbound_SalesToCustomerOnChange(Item)
	
	CalculateUseTrackingArea_Outbound();
	
EndProcedure

&AtClient
Procedure UseTrackingArea_Outbound_PurchaseReturnOnChange(Item)
	
	CalculateUseTrackingArea_Outbound();
	
EndProcedure

&AtClient
Procedure UseTrackingArea_Outbound_TransferOnChange(Item)
	
	CalculateUseTrackingArea_Outbound();
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetTrackingAreasEditable()
	
	If Object.TrackingMethod = Enums.BatchTrackingMethods.Referential
		Or Object.TrackingMethod = Enums.BatchTrackingMethods.EmptyRef() Then
		Items.GroupTrackingAreas.ToolTipRepresentation = ToolTipRepresentation.None;
	Else
		Items.GroupTrackingAreas.ReadOnly = True;
		Items.GroupTrackingAreas.ToolTipRepresentation = ToolTipRepresentation.ShowTop;
	EndIf;
	Items.GroupTrackingAreas.ReadOnly = (Object.TrackingMethod <> Enums.BatchTrackingMethods.Referential);
	
EndProcedure

&AtServer
Procedure TrackingMethodOnChangeAtServer()
	
	SetTrackingAreasEditable();
	
	DefaultAreas = Catalogs.BatchTrackingPolicies.DefaultAreas(Object.TrackingMethod);
	FillPropertyValues(Object, DefaultAreas);
	
EndProcedure

&AtClient
Procedure CalculateUseTrackingArea_Inbound()
	
	InboundNumber = Number(Object.UseTrackingArea_Inbound_FromSupplier)
		+ Number(Object.UseTrackingArea_Inbound_SalesReturn)
		+ Number(Object.UseTrackingArea_Inbound_Transfer);
	
	If InboundNumber = 0 Then
		UseTrackingArea_Inbound = 0;
	ElsIf InboundNumber = 3 Then
		UseTrackingArea_Inbound = 1;
	Else
		UseTrackingArea_Inbound = 2;
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateUseTrackingArea_Outbound()
	
	OutboundNumber = Number(Object.UseTrackingArea_Outbound_SalesToCustomer)
		+ Number(Object.UseTrackingArea_Outbound_PurchaseReturn)
		+ Number(Object.UseTrackingArea_Outbound_Transfer);
	
	If OutboundNumber = 0 Then
		UseTrackingArea_Outbound = 0;
	ElsIf OutboundNumber = 3 Then
		UseTrackingArea_Outbound = 1;
	Else
		UseTrackingArea_Outbound = 2;
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	
	AfterProcessingHandler = New NotifyDescription(
		"Attachable_AfterAllowObjectAttributesEditingProcessing", ThisObject);
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject, AfterProcessingHandler);
	
EndProcedure

&AtClient
Procedure Attachable_AfterAllowObjectAttributesEditingProcessing(Result, AdditionalParameters) Export
	
	If Result = True Then
		Items.UseTrackingArea_Inbound.ReadOnly = False;
		Items.UseTrackingArea_Outbound.ReadOnly = False;
	EndIf;
	
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion