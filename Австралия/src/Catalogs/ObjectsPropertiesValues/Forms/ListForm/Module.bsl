
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
	
	If Parameters.ChoiceMode Then
		If Parameters.Property("ChoiceFoldersAndItems")
		   AND Parameters.ChoiceFoldersAndItems = FoldersAndItemsUse.Folders Then
			
			SelectFolders = True;
			CommonClientServer.SetDynamicListFilterItem(List, "IsFolder", True);
		Else
			Parameters.ChoiceFoldersAndItems = FoldersAndItemsUse.Items;
		EndIf;
	Else
		Items.List.ChoiceMode = False;
	EndIf;
	
	SetTitle();
	
	If SelectFolders Then
		If Items.Find("FormCreate") <> Undefined Then
			Items.FormCreate.Visible = False;
		EndIf;
	EndIf;
	
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
	   AND (    Source = Property
	      OR Source = AdditionalValuesOwner) Then
		
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
	
	If SelectFolders
	   AND NOT IsFolder Then
		
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeChangeRow(Item, Cancel)
	
	Cancel = True;
	
	If Items.List.CurrentRow <> Undefined Then
		// Opening a value form or a value set.
		FormParameters = New Structure;
		FormParameters.Insert("HideOwner", True);
		FormParameters.Insert("ShowWeight", AdditionalValuesWithWeight);
		FormParameters.Insert("Key", Items.List.CurrentRow);
		
		OpenForm("Catalog.ObjectsPropertiesValues.ObjectForm", FormParameters, Items.List);
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
	OrderItem.Field = New DataCompositionField("IsFolder");
	OrderItem.OrderType = DataCompositionSortDirection.Desc;
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
				TitleLine = NStr("ru = 'Значения свойства %1'; en = '%1 property values'; pl = 'Znaczenie właściwości %1';es_ES = 'Valores del atributo para %1';es_CO = 'Valores del atributo para %1';tr = '%1 için öznitelik değeri';it = '%1 valore proprietà';de = 'Attributwert für %1'");
			ElsIf SelectFolders Then
				TitleLine = NStr("ru = 'Выберите группу значений свойства %1'; en = 'Select a group of the %1 property values'; pl = 'Wybierz grupę wartości właściwości %1';es_ES = 'Seleccionar un grupo de valores para %1';es_CO = 'Seleccionar un grupo de valores para %1';tr = '%1 için değer grubunu seçin';it = 'Seleziona un gruppo dei valori proprietà %1';de = 'Wählen Sie eine Gruppe von Werten für %1'");
			Else
				TitleLine = NStr("ru = 'Выберите значение свойства %1'; en = 'Select a value of the %1 property'; pl = 'Wybierz wartość właściwości %1';es_ES = 'Seleccionar el valor del atributo para %1';es_CO = 'Seleccionar el valor del atributo para %1';tr = '%1 için öznitelik değerini seçin';it = 'Seleziona un valore della proprietà %1';de = 'Wählen Sie den Wert eines Attributes für %1'");
			EndIf;
			
			TitleLine = StringFunctionsClientServer.SubstituteParametersToString(TitleLine,
				String(Common.ObjectAttributeValue(
					Property, "Title")));
		
		ElsIf Parameters.ChoiceMode Then
			
			If SelectFolders Then
				TitleLine = NStr("ru = 'Выберите группу значений свойства'; en = 'Select a property value group'; pl = 'Wybierz grupę wartości właściwości';es_ES = 'Seleccionar un grupo de valores';es_CO = 'Seleccionar un grupo de valores';tr = 'Değerler grubunu seçin';it = 'Seleziona un gruppo valore proprietà';de = 'Wählen Sie eine Gruppe von Werten aus'");
			Else
				TitleLine = NStr("ru = 'Выберите значение свойства'; en = 'Select a property value'; pl = 'Wybierz wartość właściwości';es_ES = 'Seleccionar el valor del atributo';es_CO = 'Seleccionar el valor del atributo';tr = 'Öznitelik değerini seçin';it = 'Seleziona un valore proprietà';de = 'Wählen Sie einen Attributwert'");
			EndIf;
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
