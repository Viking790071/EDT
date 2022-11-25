
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
		
	If Parameters.Filter.Property("Date") Then
		
		CommonClientServer.SetDynamicListFilterItem(
			List,
			"DateDay",
			BegOfDay(Parameters.Date),
			DataCompositionComparisonType.Equal,
			,
			True);
			
	EndIf;
	
	If Parameters.Filter.Property("ExcludeTaxInvoice") Then
		
		CommonClientServer.SetDynamicListFilterItem(
			List,
			"Ref",
			Parameters.Filter.ExcludeTaxInvoice,
			DataCompositionComparisonType.NotEqual,
			,
			True);
			
		Parameters.Filter.Delete("ExcludeTaxInvoice");
			
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure

#EndRegion