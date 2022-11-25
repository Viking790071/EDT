
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ChartOfAccounts") Then
		
		Items.FilterChartOfAccounts.Visible = True;
		ChartOfAccounts = Parameters.ChartOfAccounts;
		
	EndIf;
	
	If Parameters.Filter.Property("Date") Then
		
		ListRef.LoadValues(MasterAccounting.GetAccountChoiceList(
			Parameters.Filter.Company,
			Parameters.Filter.ChartOfAccounts,
			Parameters.Filter.Date));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ListRef.Count() > 0 Then
		
		DriveClientServer.SetListFilterItem(List,
			"Ref",
			ListRef,
			True,
			DataCompositionComparisonType.InList);
		
	EndIf;
	
	If ValueIsFilled(ChartOfAccounts) Then
		
		DriveClientServer.SetListFilterItem(List,
			"ChartOfAccounts",
			ChartOfAccounts,
			True,
			DataCompositionComparisonType.Equal);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterStringClearing(Item, StandardProcessing)
	
	DriveClientServer.DeleteListFilterItem(List, "Description");
	
EndProcedure

&AtClient
Procedure FilterStringOnChange(Item)
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(
		List.Filter.Items,
		"SearchFilter",
		DataCompositionFilterItemsGroupType.OrGroup);
	
	CommonClientServer.AddCompositionItem(
		FilterGroup,
		"Description",
		DataCompositionComparisonType.Like,
		StrTemplate("%1%2%1", "%", FilterString),
		,
		True);
	
	CommonClientServer.AddCompositionItem(
		FilterGroup,
		"Code",
		DataCompositionComparisonType.Like,
		StrTemplate("%1%2%1", "%", FilterString),
		,
		True);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Cancel(Command)
	
	Close();
	
EndProcedure

#EndRegion