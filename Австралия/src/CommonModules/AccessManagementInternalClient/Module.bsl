#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Management of AccessKinds and AccessValues tables in edit forms.

////////////////////////////////////////////////////////////////////////////////
// Table event handlers of the AccessValues form.

// For internal use only.
Procedure AccessValuesOnChange(Form, Item) Export
	
	Items = Form.Items;
	Parameters = AllowedValuesEditFormParameters(Form);
	
	If Item.CurrentData <> Undefined
	   AND Item.CurrentData.AccessKind = Undefined Then
		
		Filter = AccessManagementInternalClientServer.FilterInAllowedValuesEditFormTables(
			Form, Form.CurrentAccessKind);
		
		FillPropertyValues(Item.CurrentData, Filter);
		
		Item.CurrentData.RowNumberByKind = Parameters.AccessValues.FindRows(Filter).Count();
	EndIf;
	
	AccessManagementInternalClientServer.FillNumbersOfAccessValuesRowsByKind(
		Form, Items.AccessKinds.CurrentData);
	
	AccessManagementInternalClientServer.FillAllAllowedPresentation(
		Form, Items.AccessKinds.CurrentData);
	
EndProcedure

// For internal use only.
Procedure AccessValuesOnStartEdit(Form, Item, NewRow, Clone) Export
	
	Items = Form.Items;
	
	If Item.CurrentData.AccessValue = Undefined Then
		If Form.CurrentTypesOfValuesToSelect.Count() > 1
		   AND Form.CurrentAccessKind <> Form.AccessKindExternalUsers
		   AND Form.CurrentAccessKind <> Form.AccessKindUsers Then
			
			Items.AccessValuesAccessValue.ChoiceButton = True;
		Else
			Items.AccessValuesAccessValue.ChoiceButton = Undefined;
			Items.AccessValues.CurrentData.AccessValue = Form.CurrentTypesOfValuesToSelect[0].Value;
			Form.CurrentTypeOfValuesToSelect = Form.CurrentTypesOfValuesToSelect[0].Value
		EndIf;
	EndIf;
	
	Items.AccessValuesAccessValue.ClearButton
		= Form.CurrentTypeOfValuesToSelect <> Undefined
		AND Form.CurrentTypesOfValuesToSelect.Count() > 1;
	
EndProcedure

// For internal use only.
Procedure AccessValueStartChoice(Form, Item, ChoiceData, StandardProcessing) Export
	
	StandardProcessing = False;
	
	If Form.CurrentTypesOfValuesToSelect.Count() = 1 Then
		
		Form.CurrentTypeOfValuesToSelect = Form.CurrentTypesOfValuesToSelect[0].Value;
		
		AccessValueStartChoiceCompletion(Form);
		Return;
		
	ElsIf Form.CurrentTypesOfValuesToSelect.Count() > 0 Then
		
		If Form.CurrentTypesOfValuesToSelect.Count() = 2 Then
		
			If Form.CurrentAccessKind = Form.AccessKindUsers Then
				Form.CurrentTypeOfValuesToSelect = PredefinedValue(
					"Catalog.Users.EmptyRef");
				
				AccessValueStartChoiceCompletion(Form);
				Return;
			EndIf;
			
			If Form.CurrentAccessKind = Form.AccessKindExternalUsers Then
				Form.CurrentTypeOfValuesToSelect = PredefinedValue(
					"Catalog.ExternalUsers.EmptyRef");
				
				AccessValueStartChoiceCompletion(Form);
				Return;
			EndIf;
		EndIf;
		
		Form.CurrentTypesOfValuesToSelect.ShowChooseItem(
			New NotifyDescription("AccessValueStartChoiceFollowUp", ThisObject, Form),
			NStr("ru = 'Выбор типа данных'; en = 'Select data type'; pl = 'Wybierz typ danych';es_ES = 'Seleccionar el tipo de datos';es_CO = 'Seleccionar el tipo de datos';tr = 'Veri türünü seçin';it = 'Selezione del tipo di dati';de = 'Wählen Sie den Datentyp aus'"),
			Form.CurrentTypesOfValuesToSelect[0]);
	EndIf;
	
EndProcedure

// For internal use only.
Procedure AccessValueChoiceProcessing(Form, Item, SelectedValue, StandardProcessing) Export
	
	CurrentData = Form.Items.AccessValues.CurrentData;
	
	If SelectedValue = Type("CatalogRef.Users")
	 Or SelectedValue = Type("CatalogRef.UserGroups") Then
	
		StandardProcessing = False;
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		FormParameters.Insert("CurrentRow", CurrentData.AccessValue);
		FormParameters.Insert("UsersGroupsSelection", True);
		
		OpenForm("Catalog.Users.ChoiceForm", FormParameters, Item);
		
	ElsIf SelectedValue = Type("CatalogRef.ExternalUsers")
	      Or SelectedValue = Type("CatalogRef.ExternalUsersGroups") Then
	
		StandardProcessing = False;
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		FormParameters.Insert("CurrentRow", CurrentData.AccessValue);
		FormParameters.Insert("SelectExternalUsersGroups", True);
		
		OpenForm("Catalog.ExternalUsers.ChoiceForm", FormParameters, Item);
	EndIf;
	
EndProcedure

// For internal use only.
Procedure AccessValuesOnEndEdit(Form, Item, NewRow, CancelEdit) Export
	
	If Form.CurrentAccessKind = Undefined Then
		Parameters = AllowedValuesEditFormParameters(Form);
		
		Filter = New Structure("AccessKind", Undefined);
		
		FoundRows = Parameters.AccessValues.FindRows(Filter);
		
		For each Row In FoundRows Do
			Parameters.AccessValues.Delete(Row);
		EndDo;
		
		CancelEdit = True;
	EndIf;
	
	If CancelEdit Then
		AccessManagementInternalClientServer.OnChangeCurrentAccessKind(Form);
	EndIf;
	
EndProcedure

// For internal use only.
Procedure AccessValueClearing(Form, Item, StandardProcessing) Export
	
	Items = Form.Items;
	
	StandardProcessing = False;
	Form.CurrentTypeOfValuesToSelect = Undefined;
	Items.AccessValuesAccessValue.ClearButton = False;
	
	If Form.CurrentTypesOfValuesToSelect.Count() > 1
	   AND Form.CurrentAccessKind <> Form.AccessKindExternalUsers
	   AND Form.CurrentAccessKind <> Form.AccessKindUsers Then
		
		Items.AccessValuesAccessValue.ChoiceButton = True;
		Items.AccessValues.CurrentData.AccessValue = Undefined;
	Else
		Items.AccessValuesAccessValue.ChoiceButton = Undefined;
		Items.AccessValues.CurrentData.AccessValue = Form.CurrentTypesOfValuesToSelect[0].Value;
	EndIf;
	
EndProcedure

// For internal use only.
Procedure AccessValueAutoComplete(Form, Item, Text, ChoiceData, Wait, StandardProcessing) Export
	
	GenerateAccessValuesChoiceData(Form, Text, ChoiceData, StandardProcessing);
	
EndProcedure

// For internal use only.
Procedure AccessValueTextInputCompletion(Form, Item, Text, ChoiceData, StandardProcessing) Export
	
	GenerateAccessValuesChoiceData(Form, Text, ChoiceData, StandardProcessing);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Table event handlers of the AccessKinds form.

// For internal use only.
Procedure AccessKindsOnActivateRow(Form, Item) Export
	
	AccessManagementInternalClientServer.OnChangeCurrentAccessKind(Form);
	
EndProcedure

// For internal use only.
Procedure AccessKindsOnActivateCell(Form, Item) Export
	
	If Form.IsAccessGroupProfile Then
		Return;
	EndIf;
	
	Items = Form.Items;
	
	If Items.AccessKinds.CurrentItem <> Items.AccessKindsAllAllowedPresentation Then
		Items.AccessKinds.CurrentItem = Items.AccessKindsAllAllowedPresentation;
	EndIf;
	
EndProcedure

// For internal use only.
Procedure AccessKindsBeforeAddRow(Form, Item, Cancel, Clone, Parent, Folder) Export
	
	If Clone Then
		Cancel = True;
	EndIf;
	
EndProcedure

// For internal use only.
Procedure AccessKindsBeforeDeleteRow(Form, Item, Cancel) Export
	
	Form.CurrentAccessKind = Undefined;
	
EndProcedure

// For internal use only.
Procedure AccessKindsOnStartEdit(Form, Item, NewRow, Clone) Export
	
	CurrentData = Form.Items.AccessKinds.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If NewRow Then
		CurrentData.Used = True;
	EndIf;
	
	AccessManagementInternalClientServer.FillAllAllowedPresentation(Form, CurrentData, False);
	
EndProcedure

// For internal use only.
Procedure AccessKindsOnEndEdit(Form, Item, NewRow, CancelEdit) Export
	
	AccessManagementInternalClientServer.OnChangeCurrentAccessKind(Form);
	
EndProcedure

// For internal use only.
Procedure AccessKindsAccessKindPresentationOnChange(Form, Item) Export
	
	CurrentData = Form.Items.AccessKinds.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.AccessTypePresentation = "" Then
		CurrentData.AccessKind   = Undefined;
		CurrentData.Used = True;
	EndIf;
	
	AccessManagementInternalClientServer.FillAccessKindsPropertiesInForm(Form);
	AccessManagementInternalClientServer.OnChangeCurrentAccessKind(Form);
	
EndProcedure

// For internal use only.
Procedure AccessKindsAccessKindPresentationChoiceProcessing(Form, Item, SelectedValue, StandardProcessing) Export
	
	CurrentData = Form.Items.AccessKinds.CurrentData;
	If CurrentData = Undefined Then
		StandardProcessing = False;
		Return;
	EndIf;
	
	Parameters = AllowedValuesEditFormParameters(Form);
	
	Filter = New Structure("AccessTypePresentation", SelectedValue);
	Rows = Parameters.AccessKinds.FindRows(Filter);
	
	If Rows.Count() > 0
	   AND Rows[0].GetID() <> Form.Items.AccessKinds.CurrentRow Then
		
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Вид доступа ""%1"" уже выбран.
			           |Выберите другой.'; 
			           |en = 'Access kind ""%1"" is already selected.
			           |Select another one.'; 
			           |pl = 'Rodzaj dostępu ""%1"" jest już wybrany.
			           |Wybierz inny.';
			           |es_ES = 'Tipo de acceso ""%1"" ya se ha seleccionado.
			           |Eligir otro.';
			           |es_CO = 'Tipo de acceso ""%1"" ya se ha seleccionado.
			           |Eligir otro.';
			           |tr = 'Erişim türü ""%1"" zaten seçilidir. 
			           |Başka birini seçin.';
			           |it = 'Il tipo di accesso ""%1"" è già selezionato.
			           |Selezionarne un altro.';
			           |de = 'Zugriffsart ""%1"" ist bereits ausgewählt.
			           |Wählen Sie eine andere aus.'"),
			SelectedValue));
		
		StandardProcessing = False;
		Return;
	EndIf;
	
	Filter = New Structure("Presentation", SelectedValue);
	CurrentData.AccessKind = Form.AllAccessKinds.FindRows(Filter)[0].Ref;
	
EndProcedure

// For internal use only.
Procedure AccessKindsAllAllowedPresentationOnChange(Form, Item) Export
	
	CurrentData = Form.Items.AccessKinds.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.AllAllowedPresentation = "" Then
		CurrentData.AllAllowed = False;
		If Form.IsAccessGroupProfile Then
			CurrentData.PresetAccessKind = False;
		EndIf;
	EndIf;
	
	If Form.IsAccessGroupProfile Then
		AccessManagementInternalClientServer.OnChangeCurrentAccessKind(Form);
		AccessManagementInternalClientServer.FillAllAllowedPresentation(Form, CurrentData, False);
	Else
		Form.Items.AccessKinds.EndEditRow(False);
		AccessManagementInternalClientServer.FillAllAllowedPresentation(Form, CurrentData);
	EndIf;
	
EndProcedure

// For internal use only.
Procedure AccessKindsAllAllowedPresentationChoiceProcessing(Form, Item, SelectedValue, StandardProcessing) Export
	
	CurrentData = Form.Items.AccessKinds.CurrentData;
	If CurrentData = Undefined Then
		StandardProcessing = False;
		Return;
	EndIf;
	
	Filter = New Structure("Presentation", SelectedValue);
	Name = Form.PresentationsAllAllowed.FindRows(Filter)[0].Name;
	
	If Form.IsAccessGroupProfile Then
		CurrentData.PresetAccessKind = (Name = "AllAllowed" OR Name = "AllDenied");
	EndIf;
	
	CurrentData.AllAllowed = (Name = "AllAllowedByDefault" OR Name = "AllAllowed");
	
EndProcedure

#EndRegion

#Region Private

// Continue running the AccessValueStartChoice event handler.
Procedure AccessValueStartChoiceFollowUp(SelectedItem, Form) Export
	
	If SelectedItem <> Undefined Then
		Form.CurrentTypeOfValuesToSelect = SelectedItem.Value;
		AccessValueStartChoiceCompletion(Form);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// Completes the AccessValueStartChoice event handler.
Procedure AccessValueStartChoiceCompletion(Form)
	
	Items = Form.Items;
	Item  = Items.AccessValuesAccessValue;
	CurrentData = Items.AccessValues.CurrentData;
	
	If NOT ValueIsFilled(CurrentData.AccessValue)
	   AND CurrentData.AccessValue <> Form.CurrentTypeOfValuesToSelect Then
		
		CurrentData.AccessValue = Form.CurrentTypeOfValuesToSelect;
	EndIf;
	
	Items.AccessValuesAccessValue.ChoiceButton = Undefined;
	Items.AccessValuesAccessValue.ClearButton
		= Form.CurrentTypeOfValuesToSelect <> Undefined
		AND Form.CurrentTypesOfValuesToSelect.Count() > 1;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow", CurrentData.AccessValue);
	FormParameters.Insert("IsAccessValueSelection");
	
	If Form.CurrentAccessKind = Form.AccessKindUsers Then
		FormParameters.Insert("UsersGroupsSelection", True);
		OpenForm("Catalog.Users.ChoiceForm", FormParameters, Item);
		Return;
		
	ElsIf Form.CurrentAccessKind = Form.AccessKindExternalUsers Then
		FormParameters.Insert("SelectExternalUsersGroups", True);
		OpenForm("Catalog.ExternalUsers.ChoiceForm", FormParameters, Item);
		Return;
	EndIf;
	
	Filter = New Structure("ValuesType", Form.CurrentTypeOfValuesToSelect);
	FoundRows = Form.AllTypesOfValuesToSelect.FindRows(Filter);
	
	If FoundRows.Count() = 0 Then
		Return;
	EndIf;
	
	OpenForm(FoundRows[0].TableName + ".ChoiceForm", FormParameters, Item);
	
EndProcedure

// Management of AccessKinds and AccessValues tables in edit forms.

Function AllowedValuesEditFormParameters(Form, CurrentObject = Undefined)
	
	Return AccessManagementInternalClientServer.AllowedValuesEditFormParameters(
		Form, CurrentObject);
	
EndFunction

Procedure GenerateAccessValuesChoiceData(Form, Text, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Text) Then
		Return;
	EndIf;
		
	If Form.CurrentAccessKind <> Form.AccessKindExternalUsers
	   AND Form.CurrentAccessKind <> Form.AccessKindUsers Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	ChoiceData = AccessManagementInternalServerCall.GenerateUserSelectionData(Text,
		False,
		Form.CurrentAccessKind = Form.AccessKindExternalUsers,
		Form.CurrentAccessKind <> Form.AccessKindUsers);
	
EndProcedure

#EndRegion
