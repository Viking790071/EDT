#Region Public

// Starts a report generation process in the report form.
//  When the generation is completed, CompletionHandler is called.
//
// Parameters:
//   ReportForm - ClientApplicationForm - a report form.
//   CompletionHandler - NotificationHandler - a handler to be called once the report is generated.
//     To the first parameter of the procedure, specified in CompletionHandler, a parameter is 
//     passed: ReportGenerated (Boolean) - indicates that a report was generated successfully.
//
Procedure GenerateReport(ReportForm, CompletionHandler = Undefined) Export
	If TypeOf(CompletionHandler) = Type("NotifyDescription") Then
		ReportForm.HandlerAfterGenerateAtClient = CompletionHandler;
	EndIf;
	ReportForm.AttachIdleHandler("Generate", 0.1, True);
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Method of working with DCS from the report option.

Function FilterSelectionParameters(Form, Item) Export
	ItemID = Right(Item.Name, 32);
	
	DCItem = Form.FindUserSettingOfItem(ItemID);
	If DCItem = Undefined Then
		Return Undefined;
	EndIf;
	AdditionalSettings = Form.FindAdditionalItemSettings(ItemID);
	If AdditionalSettings = Undefined Then
		Return Undefined;
	EndIf;
	
	Result = New Structure("Presentation, ValuesForSelection, ValuesForSelectionFilled, QuickChoice,
	|RestrictSelectionBySpecifiedValues, TypeDescription, ListInput");
	FillPropertyValues(Result, AdditionalSettings);
	
	If TypeOf(DCItem) = Type("DataCompositionFilterItem") Then
		Value = DCItem.RightValue;
		Condition  = DCItem.ComparisonType;
	Else
		Value = DCItem.Value;
		Condition  = ?(Result.ListInput, DataCompositionComparisonType.InList, DataCompositionComparisonType.Equal);
	EndIf;
	
	ChoiceOfGroupsAndItems = ReportsClientServer.CastValueToGroupsAndItemsUsageType(Condition, AdditionalSettings.ChoiceFoldersAndItems);
	
	// Standard parameters of the form.
	Result.Insert("CloseOnChoice",            True);
	Result.Insert("CloseOnOwnerClose", True);
	Result.Insert("Filter",                         New Structure);
	// Standard parameters of the choice form (see Managed form extension for dynamic list).
	Result.Insert("ChoiceFoldersAndItems",          ChoiceOfGroupsAndItems);
	Result.Insert("MultipleChoice",            False);
	Result.Insert("ChoiceMode",                   True);
	// Supposed attributes.
	Result.Insert("WindowOpeningMode",             FormWindowOpeningMode.LockOwnerWindow);
	Result.Insert("EnableStartDrag", False);
	
	Result.Insert("FormPath", AdditionalSettings.ChoiceForm);
	
	Result.Insert("Value",   Value);
	Result.Insert("Marked", ReportsClientServer.ValuesByList(Value));
	Result.Insert("ChoiceParameters", New Array);
	Result.Insert("UniqueKey", ItemID);
	
	// Fixed choice parameters and links from hidden master objects (predefined in the current context).
	For Each ChoiceParameter In AdditionalSettings.ChoiceParameters Do
		If IsBlankString(ChoiceParameter.Name) Then
			Continue;
		EndIf;
		If Result.ListInput Then
			Result.ChoiceParameters.Add(ChoiceParameter);
		Else
			If Upper(Left(ChoiceParameter.Name, 6)) = Upper("Filter.") Then
				Result.Filter.Insert(Mid(ChoiceParameter.Name, 7), ChoiceParameter.Value);
			Else
				Result.Insert(ChoiceParameter.Name, ChoiceParameter.Value);
			EndIf;
		EndIf;
	EndDo;
	
	// Dynamic links from master objects.
	Links = Form.LinksThatCanBeDisabled.FindRows(New Structure("SubordinateIDInForm", ItemID));
	For Each Link In Links Do
		If Not ValueIsFilled(Link.MainIDInForm) Then
			Continue;
		EndIf;
		MasterDCSetting = Form.FindUserSettingOfItem(Link.MainIDInForm);
		If Not MasterDCSetting.Use Then
			Continue;
		EndIf;
		If TypeOf(MasterDCSetting) = Type("DataCompositionFilterItem") Then
			ValueOfMaster = MasterDCSetting.RightValue;
			ConditionOfMaster  = MasterDCSetting.ComparisonType;
		Else
			ValueOfMaster = MasterDCSetting.Value;
			AdditionalSettingsOfMaster = Form.FindAdditionalItemSettings(Link.MainIDInForm);
			If AdditionalSettingsOfMaster.ListInput Then
				ConditionOfMaster = DataCompositionComparisonType.InList;
			Else
				ConditionOfMaster = DataCompositionComparisonType.Equal;
			EndIf;
		EndIf;
		If Not ValueIsFilled(ValueOfMaster) Then
			Continue;
		EndIf;
		ValueTypeOfMaster = TypeOf(ValueOfMaster);
		
		If Link.LinkType = "ByType" Then
			If ConditionOfMaster <> DataCompositionComparisonType.Equal
				AND ConditionOfMaster <> DataCompositionComparisonType.InHierarchy Then
				Continue;
			EndIf;
			If TypeOf(Link.SubordinateParameterName) = Type("Number") AND Link.SubordinateParameterName > 0 Then
				ExtDimensionType = ReportsOptionsServerCall.ExtDimensionType(ValueOfMaster, Link.SubordinateParameterName);
				If TypeOf(ExtDimensionType) = Type("TypeDescription") Then
					FilterByTypes = ExtDimensionType.Types();
				Else
					Continue;
				EndIf;
			Else
				FilterByTypes = New Array;
				FilterByTypes.Add(ValueTypeOfMaster);
			EndIf;
			RemovedTypes = Result.TypeDescription.Types();
			DescriptionTypesOverlap = False;
			For Each TypeToKeep In FilterByTypes Do
				Index = RemovedTypes.Find(TypeToKeep);
				If Index <> Undefined Then
					RemovedTypes.Delete(Index);
					DescriptionTypesOverlap = True;
				EndIf;
			EndDo;
			If DescriptionTypesOverlap Then
				Result.TypeDescription = New TypeDescription(Result.TypeDescription, , RemovedTypes);
			EndIf;
		ElsIf Link.LinkType = "ByMetadata" Or Link.LinkType = "SelectionParameters" Then
			If Not ValueIsFilled(Link.SubordinateParameterName) Then
				Continue;
			EndIf;
			If Link.LinkType = "ByMetadata" AND Not Link.MainType.ContainsType(ValueTypeOfMaster) Then
				Continue;
			EndIf;
			If Result.ListInput Then
				Result.ChoiceParameters.Add(New ChoiceParameter(Link.SubordinateParameterName, ValueOfMaster));
			Else
				If Upper(Left(Link.SubordinateParameterName, 7)) = Upper("Filter.") Then
					Result.Filter.Insert(Mid(Link.SubordinateParameterName, 8), ValueOfMaster);
				Else
					Result.Insert(Link.SubordinateParameterName, ValueOfMaster);
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

Procedure ComposerListStartChoice(Form, Item, ChoiceData, StandardProcessing) Export
	StandardProcessing = False;
	
	ChoiceParameters = FilterSelectionParameters(Form, Item);
	If ChoiceParameters = Undefined Then
		Return;
	EndIf;
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("Form", Form);
	HandlerParameters.Insert("ItemID", Right(Item.Name, 32));
	Handler = New NotifyDescription("ComposerListCompleteChoice", ThisObject, HandlerParameters);
	
	Block = FormWindowOpeningMode.LockOwnerWindow;
	
	OpenForm("CommonForm.InputValuesInListWithCheckBoxes", ChoiceParameters, ThisObject, , , , Handler, Block);
EndProcedure

Procedure ComposerListCompleteChoice(SelectionResult, HandlerParameters) Export
	If TypeOf(SelectionResult) <> Type("ValueList") Then
		Return;
	EndIf;
	Form = HandlerParameters.Form;
	
	ItemID = HandlerParameters.ItemID;
	
	DCUserSetting = Form.FindUserSettingOfItem(ItemID);
	AdditionalSettings = Form.FindAdditionalItemSettings(ItemID);
	
	// Load selected values in 2 lists.
	ValueListInDCS = New ValueList;
	FillValuesForSelection = Not AdditionalSettings.RestrictSelectionBySpecifiedValues
		Or Not AdditionalSettings.ValuesForSelectionFilled;
	If FillValuesForSelection Then
		ValuesForSelection = New ValueList;
	EndIf;
	For Each ListItemInForm In SelectionResult Do
		ValueInForm = ListItemInForm.Value;
		If FillValuesForSelection AND ValuesForSelection.FindByValue(ValueInForm) = Undefined Then
			FillPropertyValues(ValuesForSelection.Add(), ListItemInForm, "Value, Presentation");
		EndIf;
		If ListItemInForm.Check Then
			ReportsClientServer.AddUniqueValueToList(ValueListInDCS, ValueInForm, ListItemInForm.Presentation, True);
		EndIf;
	EndDo;
	If FillValuesForSelection Then
		AdditionalSettings.ValuesForSelection = ValuesForSelection;
		AdditionalSettings.ValuesForSelectionFilled = True;
	EndIf;
	If TypeOf(DCUserSetting) = Type("DataCompositionFilterItem") Then
		DCUserSetting.RightValue = ValueListInDCS;
	Else
		DCUserSetting.Value = ValueListInDCS;
	EndIf;
	
	// Enable the Usage check box.
	DCUserSetting.Use = True;
	
	Form.UserSettingsModified = True;
EndProcedure

Procedure ChangeComparisonType(Form, ItemID, ResultHandler) Export
	DCUserSetting = Form.FindUserSettingOfItem(ItemID);
	If DCUserSetting = Undefined Then
		Return;
	EndIf;
	AdditionalSettings = Form.FindAdditionalItemSettings(ItemID);
	If AdditionalSettings = Undefined Then
		Return;
	EndIf;
	
	TypesInformation = ReportsClientServer.TypesAnalysis(AdditionalSettings.TypeDescription, False);
	
	List = New ValueList;
	
	If TypesInformation.ReducedLengthItem Then
		
		List.Add(DataCompositionComparisonType.Equal);
		List.Add(DataCompositionComparisonType.NotEqual);
		
		List.Add(DataCompositionComparisonType.InList);
		List.Add(DataCompositionComparisonType.NotInList);
		
		If TypesInformation.ContainsObjectTypes Then
			
			List.Add(DataCompositionComparisonType.InListByHierarchy); // NStr("en = 'In a list including subordinate objects'")
			List.Add(DataCompositionComparisonType.NotInListByHierarchy); // NStr("en = 'Not in a list including subordinate objects").
			
			List.Add(DataCompositionComparisonType.InHierarchy); // NStr("en = 'In a group'")
			List.Add(DataCompositionComparisonType.NotInHierarchy); // NStr("en = 'Not in a group'")
			
		EndIf;
		
		If TypesInformation.PrimitiveTypesNumber > 0 Then
			
			List.Add(DataCompositionComparisonType.Less);
			List.Add(DataCompositionComparisonType.LessOrEqual);
			
			List.Add(DataCompositionComparisonType.Greater);
			List.Add(DataCompositionComparisonType.GreaterOrEqual);
			
		EndIf;
		
	EndIf;
	
	If TypesInformation.ContainsStringType Then
		
		List.Add(DataCompositionComparisonType.Contains);
		List.Add(DataCompositionComparisonType.NotContains);
		
		List.Add(DataCompositionComparisonType.Like);
		List.Add(DataCompositionComparisonType.NotLike);
		
		List.Add(DataCompositionComparisonType.BeginsWith);
		List.Add(DataCompositionComparisonType.NotBeginsWith);
		
	EndIf;
	
	If TypesInformation.ReducedLengthItem Then
		
		List.Add(DataCompositionComparisonType.Filled);
		List.Add(DataCompositionComparisonType.NotFilled);
		
	EndIf;
	
	CurrentItem = List.FindByValue(DCUserSetting.ComparisonType);
	
	Context = New Structure;
	Context.Insert("Form", Form);
	Context.Insert("ItemID", ItemID);
	Context.Insert("ResultHandler", ResultHandler);
	
	Handler = New NotifyDescription("ChangeComparisonTypeCompletion", ThisObject, Context);
	FormTitle = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Условие отбора поля ""%1""'; en = 'Filter condition of the ""%1"" field'; pl = 'Warunek selekcji pola ""%1""';es_ES = 'Condición de la selección del campo ""%1""';es_CO = 'Condición de la selección del campo ""%1""';tr = '""%1"" alanın seçim şartları';it = 'Condizione filtro del campo ""%1""';de = 'Feldauswahlbedingung ""%1""'"), AdditionalSettings.Presentation);
	
	List.ShowChooseItem(Handler, FormTitle, CurrentItem);
EndProcedure

Procedure ChangeComparisonTypeCompletion(ListItem, Context) Export
	If ListItem = Undefined Then
		Result = Undefined;
	Else
		Result = ListItem.Value;
		DCUserSetting = Context.Form.FindUserSettingOfItem(Context.ItemID);
		DCUserSetting.ComparisonType = Result;
	EndIf;
	
	If Context.ResultHandler <> Undefined Then
		ExecuteNotifyProcessing(Context.ResultHandler, Result);
	EndIf;
EndProcedure

Procedure ComposerValueStartChoice(Form, Item, ValuesForSelection, StandardProcessing) Export
	StandardProcessing = False;
	
	ChoiceParameters = FilterSelectionParameters(Form, Item);
	If ChoiceParameters = Undefined Then
		Return;
	EndIf;
	
	ChoiceParameters.Insert("MultipleChoice", False);
	
	Context = New Structure;
	Context.Insert("Item",         Item);
	Context.Insert("Form",           Form);
	Context.Insert("ID",   Right(Item.Name, 32));
	Context.Insert("ChoiceParameters", ChoiceParameters);
	
	// Full name of the choice form.
	// The "ChoiceForm" property is unavailable on the client even in the read-only mode. Therefore, to 
	//   store predefined choice form names, use the QuickSearchForMetadataObjectsNames collection.
	If ValueIsFilled(ChoiceParameters.FormPath) Then
		Handler = New NotifyDescription("ComposerValueCompleteChoice", ThisObject, Context);
		OpenForm(
			ChoiceParameters.FormPath,
			ChoiceParameters,
			Context.Form,
			,
			,
			,
			Handler,
			FormWindowOpeningMode.LockOwnerWindow);
	Else
		// Select type from the list.
		Handler = New NotifyDescription("ComposerValueShowRefSelectionAfterTypeChoice", ThisObject, Context);
		ChoiceList = New ValueList;
		ChoiceList.LoadValues(ChoiceParameters.TypeDescription.Types());
		If ChoiceList.Count() = 1 Then // There is only one type, no need to select.
			ExecuteNotifyProcessing(Handler, ChoiceList[0]);
		Else
			Form.ShowChooseFromMenu(Handler, ChoiceList);
		EndIf;
	EndIf;
EndProcedure

Procedure ComposerValueShowRefSelectionAfterTypeChoice(PathToFormOrListItem, Context) Export
	If TypeOf(PathToFormOrListItem) <> Type("ValueListItem") Then
		Return;
	EndIf;
	
	Handler = New NotifyDescription("ComposerValueCompleteChoice", ThisObject, Context);
	ChoiceParameters = Context.ChoiceParameters;
	
	Type = PathToFormOrListItem.Value;
	TypeChoiceParameters = ReportsOptionsServerCall.TypeChoiceParameters(Type, ChoiceParameters);
	If TypeChoiceParameters = Undefined Then
		SelectPrimitiveTypeValue(
			Context.Form,
			Type,
			ChoiceParameters.TypeDescription,
			ChoiceParameters.Value,
			ChoiceParameters.Presentation,
			Handler);
	ElsIf TypeChoiceParameters.QuickChoice Then
		Context.Form.ShowChooseFromMenu(Handler, TypeChoiceParameters.ValuesForSelection);
	Else
		OpenForm(
			TypeChoiceParameters.FormPath,
			ChoiceParameters,
			Context.Form,
			,
			,
			,
			Handler,
			FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

Procedure ComposerValueCompleteChoice(RefOrListItem, Context) Export
	If TypeOf(RefOrListItem) = Type("ValueListItem") Then
		Ref = RefOrListItem.Value;
	Else
		Ref = RefOrListItem;
	EndIf;
	If Not Context.ChoiceParameters.TypeDescription.ContainsType(TypeOf(Ref)) Or Not ValueIsFilled(Ref) Then
		Return;
	EndIf;
	
	Form = Context.Form;
	
	DCItem = Form.FindUserSettingOfItem(Context.ID);
	
	If TypeOf(DCItem) = Type("DataCompositionFilterItem") Then
		DCItem.RightValue = Ref;
	Else
		DCItem.Value = Ref;
	EndIf;
	
	DCItem.Use = True; // Select a check box.
	
	RecordChangesInSubordinateItems(Form, Context.ID, DCItem);
	
	Form.UserSettingsModified = True;
EndProcedure

Procedure SelectPeriod(Form, ChoiceButtonName) Export
	ValueName = StrReplace(ChoiceButtonName, "_ChoiceButton_", "_Value_");
	ItemID = Right(ChoiceButtonName, 32);
	
	Value = Form[ValueName];
	
	Context = New Structure;
	Context.Insert("Form", Form);
	Context.Insert("ValueName", ValueName);
	Context.Insert("ItemID", ItemID);
	Handler = New NotifyDescription("SelectPeriodCompletion", ThisObject, Context);
	
	StandardProcessing = True;
	ReportsClientOverridable.OnClickPeriodSelectionButton(Form, Value, StandardProcessing, Handler);
	If Not StandardProcessing Then
		Return;
	EndIf;
	
	Dialog = New StandardPeriodEditDialog;
	Dialog.Period = Value;
	Dialog.Show(Handler);
EndProcedure

Procedure SelectPeriodCompletion(Period, Context) Export
	If TypeOf(Period) <> Type("StandardPeriod") Then
		Return;
	EndIf;
	
	Context.Form[Context.ValueName] = Period;
	
	DCItem = Context.Form.FindUserSettingOfItem(Context.ItemID);
	If TypeOf(DCItem) = Type("DataCompositionFilterItem") Then
		DCItem.RightValue = Period;
	ElsIf TypeOf(DCItem) = Type("DataCompositionSettingsParameterValue") Then
		DCItem.Value = Period;
	EndIf;
	DCItem.Use = True;
	
	Context.Form.UserSettingsModified = True;
EndProcedure

Procedure SelectPrimitiveTypeValue(Form, ValueType, TypesDetails, CurrentValue, FieldPresentation, Handler) Export
	ChoiceList = New ValueList;
	If ValueType = Type("AccountingRecordType") Then
		CommonClientServer.SupplementArray(ChoiceList, AccountingRecordType);
	ElsIf ValueType = Type("AccumulationRecordType") Then
		CommonClientServer.SupplementArray(ChoiceList, AccumulationRecordType);
	ElsIf ValueType = Type("CalculationRegisterPeriodType") Then
		CommonClientServer.SupplementArray(ChoiceList, CalculationRegisterPeriodType);
	ElsIf ValueType = Type("AccountType") Then
		CommonClientServer.SupplementArray(ChoiceList, AccountType);
	ElsIf ValueType = Type("BusinessProcessRoutePointType") Then
		CommonClientServer.SupplementArray(ChoiceList, BusinessProcessRoutePointType);
	ElsIf ValueType = Type("Number") Then
		ShowInputNumber(
			Handler,
			CurrentValue,
			FieldPresentation,
			TypesDetails.NumberQualifiers.Digits,
			TypesDetails.NumberQualifiers.FractionDigits);
		Return;
	ElsIf ValueType = Type("String") Then
		ShowInputString(
			Handler,
			CurrentValue,
			FieldPresentation,
			TypesDetails.StringQualifiers.Length,
			TypesDetails.StringQualifiers.Length = 0 Or TypesDetails.StringQualifiers.Length > 100);
		Return;
	ElsIf ValueType = Type("Date") Then
		ShowInputDate(
			Handler,
			CurrentValue,
			FieldPresentation,
			TypesDetails.DateQualifiers.DateFractions);
		Return;
	Else
		ShowInputValue(
			Handler,
			CurrentValue,
			FieldPresentation,
			TypesDetails);
		Return;
	EndIf;
	Form.ShowChooseFromMenu(Handler, ChoiceList);
EndProcedure

Procedure RecordChangesInSubordinateItems(Form, ItemID, DataCompositionSettingsOfMaster) Export
	
	// Clearing values when changing value.
	FoundItems = Form.LinksThatCanBeDisabled.FindRows(New Structure("MainIDInForm", ItemID));
	For Each Link In FoundItems Do
		If Not ValueIsFilled(Link.SubordinateIDInForm) Then
			Continue;
		EndIf;
		If Link.LinkType = "SelectionParameters" Then
			If Link.SubordinateAction = LinkedValueChangeMode.Clear Then
				ClearValueOfSubordinateObject(Form, DataCompositionSettingsOfMaster, Link.SubordinateIDInForm);
			EndIf;
		Else
			Continue;
		EndIf;
	EndDo;
	
EndProcedure

Procedure ClearValueOfSubordinateObject(Form, DataCompositionSettingsOfMaster, SubordinateObjectIDInForm)
	SubordinateObjectDCSetting = Form.FindUserSettingOfItem(SubordinateObjectIDInForm);
	SubordinateObjectAdditionally = Form.FindAdditionalItemSettings(SubordinateObjectIDInForm);
	If SubordinateObjectAdditionally = Undefined Or SubordinateObjectDCSetting = Undefined Then
		Return;
	EndIf;
	
	If DataCompositionSettingsOfMaster.Use Then
		If SubordinateObjectAdditionally.ListInput Then
			If TypeOf(SubordinateObjectDCSetting) = Type("DataCompositionSettingsParameterValue") Then
				SubordinateObjectDCSetting.Value = New ValueList;
			ElsIf TypeOf(SubordinateObjectDCSetting) = Type("DataCompositionFilterItem") Then
				SubordinateObjectDCSetting.RightValue = New ValueList;
			EndIf;
		Else
			If TypeOf(SubordinateObjectDCSetting) = Type("DataCompositionSettingsParameterValue") Then
				SubordinateObjectDCSetting.Value = Undefined;
			ElsIf TypeOf(SubordinateObjectDCSetting) = Type("DataCompositionFilterItem") Then
				SubordinateObjectDCSetting.RightValue = Undefined;
			EndIf;
		EndIf;
	EndIf;
	
	If SubordinateObjectAdditionally.QuickChoice
		AND Not SubordinateObjectAdditionally.RestrictSelectionBySpecifiedValues Then
		SubordinateObjectAdditionally.ValuesForSelectionFilled = False;
		SubordinateObjectAdditionally.ValuesForSelection.Clear();
	EndIf;
EndProcedure

#EndRegion