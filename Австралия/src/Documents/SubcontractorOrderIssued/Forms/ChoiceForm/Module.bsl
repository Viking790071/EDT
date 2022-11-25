#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PaintList();
	
	If Constants.UseSubcontractorOrderIssuedStatuses.Get() Then
		Items.OrderStatus.Visible = False;
	Else
		Items.OrderState.Visible = False;
	EndIf;
	
	StatusesStructure = Documents.SubcontractorOrderIssued.GetSubcontractorOrderStringStatuses();
	
	For Each Item In StatusesStructure Do
		CommonClientServer.SetDynamicListParameter(List, Item.Key, Item.Value);
	EndDo;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_SubcontractorOrderStates" Then
		PaintList();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure PaintList()
	
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	
	For Each Item In ListOfItemsForDeletion Do
		List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	PaintByState = Constants.UseSubcontractorOrderIssuedStatuses.Get();
	
	If Not PaintByState Then
		
		BackColorInProcess = Undefined;
		InProcessStatus = Constants.SubcontractorOrderIssuedInProgressStatus.Get();
		If ValueIsFilled(InProcessStatus) Then
			ColorAttribute = Common.ObjectAttributeValue(InProcessStatus, "Color");
			If ValueIsFilled(ColorAttribute) Then
				BackColorInProcess = ColorAttribute.Get();
			EndIf;
		EndIf;
		
		BackColorCompleted = Undefined;
		CompletedStatus = Constants.SubcontractorOrderIssuedCompletionStatus.Get();
		If ValueIsFilled(CompletedStatus) Then
			ColorAttribute = Common.ObjectAttributeValue(CompletedStatus, "Color");
			If ValueIsFilled(ColorAttribute) Then
				BackColorCompleted = ColorAttribute.Get();
			EndIf;
		EndIf;
		
		StatusesStructure = Documents.SubcontractorOrderIssued.GetSubcontractorOrderStringStatuses();
		
	EndIf;
	
	SelectionOrderStatuses = Catalogs.SubcontractorOrderIssuedStatuses.Select();
	While SelectionOrderStatuses.Next() Do
		
		If PaintByState Then
			BackColor = SelectionOrderStatuses.Color.Get();
			If TypeOf(BackColor) <> Type("Color") Then
				Continue;
			EndIf;
		Else
			If SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.InProcess Then
				If TypeOf(BackColorInProcess) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorInProcess;
			ElsIf SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.Completed Then
				If TypeOf(BackColorCompleted) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorCompleted;
			Else
				Continue;
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		If PaintByState Then
			FilterItem.LeftValue = New DataCompositionField("OrderState");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.RightValue = SelectionOrderStatuses.Ref;
		Else
			FilterItem.LeftValue = New DataCompositionField("OrderStatus");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			If SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.InProcess Then
				FilterItem.RightValue = StatusesStructure.StatusInProcess;
			Else
				FilterItem.RightValue = StatusesStructure.StatusCompleted;
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColor);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		
	EndDo;
	
	If PaintByState Then
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Closed");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = True;
		
		TextFontRows = New Font(,,,,,True);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", TextFontRows);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		
	Else
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("OrderStatus");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = StatusesStructure.StatusCanceled;
		
		TextFontRows = New Font(,,,,,True);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", TextFontRows);
		If TypeOf(BackColorCompleted) = Type("Color") Then
			ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColorCompleted);
		EndIf;
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		
	EndIf;
	
EndProcedure

#EndRegion
