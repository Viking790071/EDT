
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "SelectionPick");
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	EndIf;
	
	If Parameters.Filter.Property("Owner") Then
		Property = Parameters.Filter.Owner;
		Parameters.Filter.Delete("Owner");
	EndIf;
	
	If NOT ValueIsFilled(Property) Then
		Items.Property.Visible = True;
		SetValuesOrderByProperties(List);
	EndIf;
	
	Items.List.ChoiceMode = Parameters.ChoiceMode;
	
	SetTitle();
	
	OnChangeProperty();
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		Items.Move(Items.BasicCommands, Items.CommandBarForm);
		Items.Move(Items.AdditionalCommands, Items.CommandBarForm);
		Items.Move(Items.FormHelp, Items.CommandBarForm);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_AdditionalAttributesAndInfo"
	   AND Source = Property Then
		
		AttachIdleHandler("IdleHandlerOnChangeProperty", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PropertyOnChange(Item)
	
	OnChangeProperty();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	If NOT Clone
	   AND Items.List.Representation = TableRepresentation.List Then
		
		Parent = Undefined;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetValuesOrderByProperties(List)
	
	Var Order;
	
	// Order.
	Order = List.SettingsComposer.Settings.Order;
	Order.UserSettingID = "DefaultOrder";
	
	Order.Items.Clear();
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("Owner");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("Description");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
EndProcedure

&AtServer
Procedure SetTitle()
	
	TitleLine = "";
	
	If ValueIsFilled(Property) Then
		TitleLine = Common.ObjectAttributeValue(
			Property, "ValueSelectionFormTitle");
	EndIf;
	
	If IsBlankString(TitleLine) Then
		
		If ValueIsFilled(Property) Then
			If NOT Parameters.ChoiceMode Then
				TitleLine = NStr("ru = '???????????????? ???????????????? %1'; en = '%1 property values'; pl = 'Znaczenie w??a??ciwo??ci %1';es_ES = 'Valores del atributo para %1';es_CO = 'Valores del atributo para %1';tr = '%1 i??in ??znitelik de??eri';it = '%1 valore propriet??';de = 'Attributwert f??r %1'");
			Else
				TitleLine = NStr("ru = '???????????????? ???????????????? ???????????????? %1'; en = 'Select a value of the %1 property'; pl = 'Wybierz warto???? w??a??ciwo??ci %1';es_ES = 'Seleccionar el valor del atributo para %1';es_CO = 'Seleccionar el valor del atributo para %1';tr = '%1 i??in ??znitelik de??erini se??in';it = 'Seleziona un valore della propriet?? %1';de = 'W??hlen Sie den Wert eines Attributes f??r %1'");
			EndIf;
			
			TitleLine = StringFunctionsClientServer.SubstituteParametersToString(TitleLine, String(Property));
		
		ElsIf Parameters.ChoiceMode Then
			TitleLine = NStr("ru = '???????????????? ???????????????? ????????????????'; en = 'Select a property value'; pl = 'Wybierz warto???? w??a??ciwo??ci';es_ES = 'Seleccionar el valor del atributo';es_CO = 'Seleccionar el valor del atributo';tr = '??znitelik de??erini se??in';it = 'Seleziona un valore propriet??';de = 'W??hlen Sie einen Attributwert'");
		EndIf;
	EndIf;
	
	If NOT IsBlankString(TitleLine) Then
		AutoTitle = False;
		Title = TitleLine;
	EndIf;
	
EndProcedure

&AtClient
Procedure IdleHandlerOnChangeProperty()
	
	OnChangeProperty();
	
EndProcedure

&AtServer
Procedure OnChangeProperty()
	
	If ValueIsFilled(Property) Then
		
		AdditionalValuesOwner = Common.ObjectAttributeValue(
			Property, "AdditionalValuesOwner");
		
		If ValueIsFilled(AdditionalValuesOwner) Then
			ReadOnly = True;
			
			ValueType = Common.ObjectAttributeValue(
				AdditionalValuesOwner, "ValueType");
			
			CommonClientServer.SetDynamicListFilterItem(
				List, "Owner", AdditionalValuesOwner);
			
			AdditionalValuesWithWeight = Common.ObjectAttributeValue(
				AdditionalValuesOwner, "AdditionalValuesWithWeight");
		Else
			ReadOnly = False;
			ValueType = Common.ObjectAttributeValue(Property, "ValueType");
			
			CommonClientServer.SetDynamicListFilterItem(
				List, "Owner", Property);
			
			AdditionalValuesWithWeight = Common.ObjectAttributeValue(
				Property, "AdditionalValuesWithWeight");
		EndIf;
		
		If TypeOf(ValueType) = Type("TypeDescription")
		   AND ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
			
			Items.List.ChangeRowSet = True;
		Else
			Items.List.ChangeRowSet = False;
		EndIf;
		
		Items.List.Representation = TableRepresentation.HierarchicalList;
		Items.Owner.Visible = False;
		Items.Weight.Visible = AdditionalValuesWithWeight;
	Else
		CommonClientServer.DeleteDynamicListFilterGroupItems(
			List, "Owner");
		
		Items.List.Representation = TableRepresentation.List;
		Items.List.ChangeRowSet = False;
		Items.Owner.Visible = True;
		Items.Weight.Visible = False;
	EndIf;
	
	Items.List.Header = Items.Owner.Visible Or Items.Weight.Visible;
	
EndProcedure

#EndRegion
