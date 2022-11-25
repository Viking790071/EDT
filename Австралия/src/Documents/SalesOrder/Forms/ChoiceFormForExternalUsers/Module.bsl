
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPropertyValues(ThisObject, ExternalUsers.ExternalUserAuthorizationData());
	CommonClientServer.SetDynamicListParameter(List, "Counterparty", AuthorizedCounterparty);
	CommonClientServer.SetDynamicListParameter(List, "UseContractRestrictionsTurnOff",
		Not GetFunctionalOption("UseContractRestrictionsForExternalUsers"));
	
	StatusesStructure = Documents.SalesOrder.GetSalesOrderStringStatuses();
	
	For Each Item In StatusesStructure Do
		CommonClientServer.SetDynamicListParameter(List, Item.Key, Item.Value);
	EndDo;
	
	SetConditionalAppearance();
	
	// Use sales order status.
	If Constants.UseSalesOrderStatuses.Get() Then
		Items.OrderStatus.Visible = False;
	Else
		Items.OrderState.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure ListValueChoice(Item, Value, StandardProcessing)
	NotifyChoice(Value);
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	FontClosed = New Font(StyleFonts.FontDialogAndMenu,,,False,,,True);
	
	ItemAppearance = List.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Closed");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Font", FontClosed);
	
EndProcedure

#EndRegion