#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Procedure sets availability of the form items.
//
&AtClient
Procedure SetEnabled()
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		
		If Not CurrentData.Property("RowGroup")
			AND ValueIsFilled(CurrentData.State)
			AND CurrentData.State = PredefinedValue("Enum.FixedAssetStatus.AcceptedForAccounting") Then
			
			Items.ListChangeParameters.Enabled = True;
			Items.ListWriteOff.Enabled = True;
			Items.ListSell.Enabled = True;
			If CurrentData.DepreciationMethod = StructureMethodsOfDepreciationCalculation.ProportionallyToProductsVolume Then
				Items.ListEnterDepreciation.Enabled = True;
			Else
				Items.ListEnterDepreciation.Enabled = False;
			EndIf;
			Items.ListAcceptForAccounting.Enabled = False;
			
		ElsIf Not CurrentData.Property("RowGroup")
			AND ValueIsFilled(CurrentData.State)
			AND CurrentData.State = PredefinedValue("Enum.FixedAssetStatus.RemoveFromAccounting") Then
			
			Items.ListChangeParameters.Enabled = False;
			Items.ListWriteOff.Enabled = False;
			Items.ListSell.Enabled = False;
			Items.ListEnterDepreciation.Enabled = False;
			Items.ListAcceptForAccounting.Enabled = False;
			
		ElsIf Not CurrentData.Property("RowGroup")
			AND ValueIsFilled(CurrentData.State)
			AND CurrentData.State = PredefinedValue("Enum.FixedAssetStatus.EmptyRef") Then
			
			Items.ListChangeParameters.Enabled = False;
			Items.ListWriteOff.Enabled = False;
			Items.ListSell.Enabled = False;
			Items.ListEnterDepreciation.Enabled = False;
			Items.ListAcceptForAccounting.Enabled = True;
			
		Else
			
			Items.ListChangeParameters.Enabled = False;
			Items.ListWriteOff.Enabled = False;
			Items.ListSell.Enabled = False;
			Items.ListEnterDepreciation.Enabled = False;
			Items.ListAcceptForAccounting.Enabled = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Function receives the period of the last depreciation calculation.
//
&AtServerNoContext
Function GetPeriodOfLastDepreciation(Val Company)
	
	Query = New Query(
	"SELECT ALLOWED TOP 1
	|	FixedAssets.Period AS Date
	|FROM
	|	AccumulationRegister.FixedAssets AS FixedAssets
	|WHERE
	|	FixedAssets.Company = &Company
	|	AND VALUETYPE(FixedAssets.Recorder) = Type(Document.FixedAssetsDepreciation)
	|
	|ORDER BY
	|	FixedAssets.Period DESC");
	
	Company = ?(GetFunctionalOption("UseSeveralCompanies"), Company, Catalogs.Companies.MainCompany);
	
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return NStr("en = 'Last Earning:'; ru = 'Последнее начисление:';pl = 'Ostatnie naliczenie wynagrodzenia:';es_ES = 'Última ganancia:';es_CO = 'Última ganancia:';tr = 'Son Tahakkuk:';it = 'Ultimo guadagno:';de = 'Letzter Bezug:'") + " " + Format(Selection.Date, "DLF=DD");
	Else
		Return "";
	EndIf;
	
EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FixedAssetsStatesStructure = New Structure;
	FixedAssetsStatesStructure.Insert("AcceptedForAccounting", Enums.FixedAssetStatus.AcceptedForAccounting);
	FixedAssetsStatesStructure.Insert("RemoveFromAccounting", Enums.FixedAssetStatus.RemoveFromAccounting);
	
	StructureMethodsOfDepreciationCalculation = New Structure;
	StructureMethodsOfDepreciationCalculation.Insert("Linear", Enums.FixedAssetDepreciationMethods.Linear);
	StructureMethodsOfDepreciationCalculation.Insert("ProportionallyToProductsVolume", Enums.FixedAssetDepreciationMethods.ProportionallyToProductsVolume);
	
	PeriodOfLastDepreciation = GetPeriodOfLastDepreciation(Company);
	
	Items.State.ChoiceList.Add(Enums.FixedAssetStatus.EmptyRef(), NStr("en = 'Not entered in the books'; ru = 'Не принят к учету';pl = 'Nie przyjęto do ewidencji';es_ES = 'No entrado en los libros';es_CO = 'No entrado en los libros';tr = 'Kitaplara girilmemiş';it = 'Non indicato nei libri';de = 'Nicht in die Bücher eingetragen'"));
	
	//Conditional appearance
	ItemAppearance = List.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("State");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Enums.FixedAssetStatus.EmptyRef();
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = 'Not entered in the books'; ru = 'Не принят к учету';pl = 'Nie przyjęto do ewidencji';es_ES = 'No entrado en los libros';es_CO = 'No entrado en los libros';tr = 'Kitaplara girilmemiş';it = 'Non indicato nei libri';de = 'Nicht in die Bücher eingetragen'"));
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("State");
	FieldAppearance.Use = True;
	
	ItemAppearance = List.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Ref.IsFolder");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", "");
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("State");
	FieldAppearance.Use = True;

	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

// Procedure - OnLoadDataFromSettingsAtServer form event handler.
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Company = Settings.Get("Company");
	State = Settings.Get("State");
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	DriveClientServer.SetListFilterItem(List, "State", State, State <> Undefined);
	
	PeriodOfLastDepreciation = GetPeriodOfLastDepreciation(Company);
	
EndProcedure

// Procedure - OnLoadDataFromSettingsAtServer form event handler.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "TextUpdatePeriodOfLastDepreciationCalculation" Then
		PeriodOfLastDepreciation = GetPeriodOfLastDepreciation(Company);
	ElsIf EventName = "FixedAssetsStatesUpdate" Then
		SetEnabled();
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - handler of clicking AcceptForAccounting button.
//
&AtClient
Procedure AcceptForAccounting(Command)
	
	ListOfParameters = New Structure("Basis", Items.List.CurrentRow);
	
	OpenForm("Document.FixedAssetRecognition.ObjectForm", ListOfParameters);
	
EndProcedure

// Procedure - handler of clicking ChangeParameters button.
//
&AtClient
Procedure ChangeParameters(Command)
	
	ListOfParameters = New Structure("Basis", Items.List.CurrentRow);
	
	OpenForm("Document.FixedAssetDepreciationChanges.ObjectForm", ListOfParameters);
	
EndProcedure

// Procedure - handler of clicking ChargeDepreciation button.
//
&AtClient
Procedure ChargeDepreciation(Command)
	
	ListOfParameters = New Structure("Basis", Company);
	
	OpenForm("Document.FixedAssetsDepreciation.ObjectForm", ListOfParameters);
	
EndProcedure

// Procedure - handler of clicking Sell button.
//
&AtClient
Procedure Sell(Command)
	
	ListOfParameters = New Structure("Basis",  Items.List.CurrentRow);
	
	OpenForm("Document.FixedAssetSale.ObjectForm", ListOfParameters);
	
EndProcedure

// Procedure - handler of clicking WriteOff button.
//
&AtClient
Procedure WriteOff(Command)
	
	ListOfParameters = New Structure("Basis",  Items.List.CurrentRow);
	
	OpenForm("Document.FixedAssetWriteOff.ObjectForm", ListOfParameters);
	
EndProcedure

// Procedure - handler of clicking EnterWorkOutput button.
//
&AtClient
Procedure EnterWorkOutput(Command)
	
	ListOfParameters = New Structure("Basis",  Items.List.CurrentRow);
	
	OpenForm("Document.FixedAssetUsage.ObjectForm", ListOfParameters);
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler OnChange of the Company input field.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
	PeriodOfLastDepreciation = GetPeriodOfLastDepreciation(Company);
	
EndProcedure

// Procedure - event handler OnChange of the State input field.
//
&AtClient
Procedure StatusOnChange(Item)
	
	SetFilter = State <> Undefined;
	Items.State.ListChoiceMode = SetFilter;
	DriveClientServer.SetListFilterItem(List, "State", State, SetFilter);
	
EndProcedure

// Procedure - event handler OnActivateRow of the List tabular section.
//
&AtClient
Procedure ListOnActivateRow(Item)
	
	SetEnabled();
	
EndProcedure

&AtClient
Procedure StateStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Items.State.ListChoiceMode = False Then
		Items.State.ListChoiceMode = True;
	EndIf;
	
EndProcedure

#EndRegion
