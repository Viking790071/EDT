#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("FilterValue") And ValueIsFilled(Parameters.FilterValue) Then 
		Dimensions = Metadata.InformationRegisters.NumberingSettings.Dimensions;
		For Each Dimension In Dimensions Do
			If Dimension.Type.ContainsType(TypeOf(Parameters.FilterValue)) Then
				ValuesArray = New Array;
				ValuesArray.Add(Parameters.FilterValue);
				ValuesArray.Add(Common.ObjectManagerByRef(Parameters.FilterValue).EmptyRef());
				CommonClientServer.SetFilterItem(List.Filter,
					Dimension.Name,
					ValuesArray);
				Break;
			EndIf;
		EndDo;
		Items.List.ChangeRowSet = False;
		Items.List.ReadOnly = True;
	EndIf;
	
	SetConditionalAppearance();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListOnActivateRow(Item)
	
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf; 
	
	AttachIdleHandler("UpdateDataHandler", 0.2, True);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	TextAll = TextAll();
	
	Fields = New Array;
	Fields.Add("OperationType");
	Fields.Add("Company");
	Fields.Add("BusinessUnit");
	Fields.Add("Counterparty");
	
	For Each Field In Fields Do
		
		Item = ConditionalAppearance.Items.Add();
		
		Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleDataColor);
		Item.Appearance.SetParameterValue("Text", TextAll);
		
		FilterItem = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("List." + Field);
		FilterItem.ComparisonType = DataCompositionComparisonType.NotFilled;
		
		FieldsItem = Item.Fields.Items.Add();
		FieldsItem.Field = New DataCompositionField(Field);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure UpdateDataHandler()
	
	CurrentData = Items.List.CurrentData;
	
	TextAll = TextAll();
	
	If ValueIsFilled(CurrentData.OperationType) Then 
		OperationType = CurrentData.OperationType;
	Else 
		OperationType = TextAll;
	EndIf;
	
	If ValueIsFilled(CurrentData.Company) Then 
		Company = CurrentData.Company;
	Else 
		Company = TextAll;
	EndIf;
	
	If ValueIsFilled(CurrentData.BusinessUnit) Then 
		BusinessUnit = CurrentData.BusinessUnit;
	Else 
		BusinessUnit = TextAll;
	EndIf;
	
	If ValueIsFilled(CurrentData.Counterparty) Then 
		Counterparty = CurrentData.Counterparty;
	Else 
		Counterparty = TextAll;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function TextAll()
	
	Return NStr("en = '<all>'; ru = '<все>';pl = '<wszystkie>';es_ES = '<todo>';es_CO = '<all>';tr = '<tümü>';it = '<tutto>';de = '<alle>'");
	
EndFunction

#EndRegion