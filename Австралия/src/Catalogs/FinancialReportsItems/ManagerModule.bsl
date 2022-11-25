#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure SetCellText(Form, Address) Export
	Var FormAdditionalMode;
	
	SetAuxiliaryText = False;
	If Form.Parameters.Property("CheckTableType") Then
		TableType = Undefined;
		Form.Parameters.Property("TableType", TableType);
		If TableType = Enums.FinancialReportItemsTypes.TableIndicatorsInColumns
			Or TableType = Enums.FinancialReportItemsTypes.TableIndicatorsInRows Then
			SetAuxiliaryText = True;
		EndIf;
	EndIf;
	
	CurrentArea = Form.ReportPresentation.Area(Address);
	
	If Not SetAuxiliaryText Then
		Details = CurrentArea.Details;
	EndIf;

	If SetAuxiliaryText Then
		
		CurrentArea.Text = NStr("en = '<report indicator value>'; ru = '<значение индикатора отчета>';pl = '<wartość wskaźnika raportu>';es_ES = '<informe el valor del indicador>';es_CO = '<informe el valor del indicador>';tr = '<gösterge değerini raporla>';it = '<valore indicatore report>';de = '<Bericht Indikatorwert>'");
		
	ElsIf Not ValueIsFilled(Details.ReportItem)
		And Not ValueIsFilled(Details.ItemType) Then
		
		CurrentArea.Text = NStr("en = '<select cell type>'; ru = '<выберите тип клетки>';pl = '<wybierz typ komórki>';es_ES = '<seleccione el tipo de celda>';es_CO = '<seleccione el tipo de celda>';tr = '<hücre tipini seç>';it = '<selezionare tipo di cella>';de = '<Zellentyp auswählen>'");
		
	Else
		
		CurrentArea.Text = String(Details.ItemType);
		
		If Details.ItemType = ItemType("Group") Or Details.ItemType = ItemType("Dimension") Then
			
			CurrentArea.Text = "";
			
		ElsIf Details.ItemType = ItemType("GroupTotal") Then
			
			CurrentArea.Text = NStr("en = 'Total'; ru = 'Итого';pl = 'Razem';es_ES = 'Total';es_CO = 'Total';tr = 'Toplam';it = 'Totale';de = 'Gesamt'");
			
		ElsIf Details.ItemType = ItemType("EditableValue") Then
			
			CurrentArea.Text = GetFromTempStorage(Details.ReportItem).DescriptionForPrinting;
			
		ElsIf Details.ItemType = ItemType("AccountingDataIndicator")
			Or Details.ItemType = ItemType("UserDefinedFixedIndicator")
			Or Details.ItemType = ItemType("UserDefinedCalculatedIndicator") Then
			
			CurrentArea.Text = FinancialReportingServerCall.ObjectAttributeValue(Details.ReportItem, "DescriptionForPrinting");
			
		Else
			
			CurrentArea.Text = CurrentArea.Text + Chars.LF
				+ FinancialReportingServerCall.AdditionalAttributeValue(Details.ReportItem, "Formula")
				
		EndIf;
			
	EndIf;
	
EndProcedure

Function OutputTableOfComplexTableSetting(Form, CurrentTableTree) Export
	
	UnionDepth = FinancialReportingServer.CalculateLevelDepth(CurrentTableTree);
	
	If Form.IsSimpleTable Then
		FirstRow = 2;
	Else
		FirstRow = 4;
	EndIf;
	
	Form.FirstRow = FirstRow;
	Form.ReportPresentation.Area(,1,,1).ColumnWidth = 3;
	
	TableColumnsTree = FinancialReportingClientServer.ChildItem(CurrentTableTree, "ItemType", ItemType("Columns"));
	HeaderHeight = FinancialReportingServer.TreeDepth(TableColumnsTree.Rows);
	HeaderWidth = OutputTreeToIndicators(Form, FirstRow, TableColumnsTree.Rows, 0, HeaderHeight, 2 + UnionDepth);
	
	mTemplateWidth = HeaderWidth;
	mHeaderHeight = HeaderHeight;
	
	HeaderArea = Form.ReportPresentation.Area(FirstRow, 2, FirstRow + HeaderHeight, 2 + UnionDepth - 1);
	HeaderArea.Merge();
	HeaderArea.ColumnWidth = 30;
	HeaderArea.Text = "";
	ApplyFormats(HeaderArea, "TableHeader");
	
	Area = Form.ReportPresentation.Area(FirstRow, 2, FirstRow + HeaderHeight, 2 + UnionDepth -1 + HeaderWidth);
	ApplyFormats(Area, "Header");
	
	TableItems = FormDataToValue(Form.TableItems, Type("ValueTable"));
	TableItems.Indexes.Add("Row, Column");
	
	RowsNumber = 0;
	TabeRowsTree = FinancialReportingClientServer.ChildItem(CurrentTableTree, "ItemType", ItemType("Rows"));
	OutputParameters = New Structure;
	OutputParameters.Insert("TableItems",	TableItems);
	OutputParameters.Insert("ColumnsTree",	TableColumnsTree.Rows);
	OutputParameters.Insert("FirstRow",		FirstRow + HeaderHeight);
	OutputParameters.Insert("UnionDepth",	UnionDepth);
	
	OutputTreeToRows(Form, TabeRowsTree.Rows, OutputParameters, RowsNumber);
	
	mTemplateHeight = HeaderHeight + RowsNumber;
	
	Area = Form.ReportPresentation.Area(FirstRow, 2, FirstRow + HeaderHeight + RowsNumber, 2 + UnionDepth - 1 + HeaderWidth);
	ApplyFormats(Area, "Header");
	
	Return New Structure("TemplateWidth, TemplateHeight, HeaderHeight", mTemplateWidth, mTemplateHeight, mHeaderHeight);
	
EndFunction

Function FormOnCreateAtServer(Form) Export
	
	If Form.Parameters.Property("AutoTest") Then
		Return Form.FormAttributeToValue("Object");
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(Form, Form.Object);
	
	Form.ItemAddressInTempStorage = Form.Parameters.ItemAddressInTempStorage;
	Write = Not ValueIsFilled(Form.ItemAddressInTempStorage);
	Form.Items.FormWrite.Visible	= Write;
	Form.Items.FormReread.Visible	= Write;
	If Form.Items.Find("FormCopy") <> Undefined Then
		Form.Items.FormCopy.Visible = Write;
	EndIf;
	If Form.Items.Find("FormSetDeletionMark") <> Undefined Then
		Form.Items.FormSetDeletionMark.Visible = Write;
	EndIf;
	
	Form.Items.FormWriteAndClose.Visible		= Write;
	Form.Items.FormWriteAndClose.DefaultButton	= Write;
	Form.Items.FinishEditing.Visible		= Not Write;
	Form.Items.FinishEditing.DefaultButton	= Not Write;
	Form.Items.FinishEditing.Enabled		= Not Form.ReadOnly;
	If Not Write Then
		Form.Items.FormWriteAndClose.Title = NStr("en = 'Finish editing'; ru = 'Завершить редактирование';pl = 'Zakończ edycję';es_ES = 'Terminar de editar';es_CO = 'Terminar de editar';tr = 'Düzenlemeyi bitir';it = 'Terminare modifica';de = 'Bearbeitung abschließen'");
	EndIf;
	
	If Not Write Then
		
		ObjectData = GetFromTempStorage(Form.ItemAddressInTempStorage);
		ItemTables = "FormulaOperands, ItemTypeAttributes, TableItems, AdditionalFields,
					|AppearanceItems, AppearanceAppliedRows, AppearanceAppliedColumns,
					|AppearanceItemsFilterFieldsDetails, ValuesSources";
		FillPropertyValues(Form.Object, ObjectData, , ItemTables);
		TablesStructure = New Structure(ItemTables);
		
		For Each KeyAndValue In TablesStructure Do
			
			If KeyAndValue.Key = "AppearanceAppliedRows"
				Or KeyAndValue.Key = "AppearanceAppliedColumns" Then
				Form.Object[KeyAndValue.Key].Clear();
				Continue;
			EndIf;
			
			If TypeOf(ObjectData[KeyAndValue.Key]) = Type("ValueTable") Then
				Form.Object[KeyAndValue.Key].Load(ObjectData[KeyAndValue.Key]);
			EndIf;
			
		EndDo;
		
	Else
		
		ObjectData = Form.FormAttributeToValue("Object");
		
	EndIf;
	
	ItemTypeAttributes = New Structure; 
	For Each AdditionalAttribute In Form.Object.ItemTypeAttributes Do
		ItemTypeAttributes.Insert(AdditionalAttribute.Attribute.PredefinedDataName, AdditionalAttribute.Value);
	EndDo;
	FillPropertyValues(Form, ItemTypeAttributes);
	
	Attributes = Form.GetAttributes();
	HasFilterComposer = False;
	For Each Attribute In Attributes Do
		If Attribute.Name = "Composer" Then
			HasFilterComposer = True;
			Break;
		EndIf;
	EndDo;
	
	If HasFilterComposer Then
		SetFilterSettings(Form, Form.Composer, ObjectData.ItemType, ObjectData.AdditionalFilter);
	EndIf;
	
	Return ObjectData;
	
EndFunction

Procedure FormBeforeWriteAtServer(Form, Object, Cancel, AdditionalMode = Undefined) Export
	
	AdditionalAttributes = FinancialReportingServerCall.FormUsageParameters(Object.ItemType, Object, AdditionalMode).Attributes;
	Object.ItemTypeAttributes.Clear();
	
	For Each Attribute In AdditionalAttributes Do
		FinancialReportingServerCall.SetAdditionalAttributeValue(Object, Attribute.Key, Form[Attribute.Key])
	EndDo;
	
	Object.HasSettings = False;
	Form.Object.HasSettings = False;
	For Each Attribute In Form.GetAttributes() Do
		If Attribute.Name = "Composer" Then
			
			Settings = Form.Composer.GetSettings();
			For Each FilterItem In Settings.Filter.Items Do
				If FilterItem.Use Then
					Object.HasSettings = True;
					Form.Object.HasSettings = True;
					Break;
				EndIf;
			EndDo;
			Object.AdditionalFilter = New ValueStorage(Settings);
			Break;
			
		EndIf;
	EndDo;
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(Object);
	
	If ValueIsFilled(Form.ItemAddressInTempStorage) Then
		Cancel = True;
		FinancialReportingServerCall.PutItemToTempStorage(Object, Form.ItemAddressInTempStorage);
	EndIf;
	
EndProcedure

Procedure SetFilterSettings(Attributes, ComposerReceiver, ItemType, AdditionalFilter) Export
	
	#Region DefiningAvailableFields
	
	If ItemType = Enums.FinancialReportItemsTypes.Dimension
		And Attributes.DimensionType = Enums.FinancialReportDimensionTypes.AccountingRegisterDimension Then
		FilterFields = New Structure(Attributes.DimensionName);
		SettingsSchema = IndicatorFilterSchema(FilterFields);
	ElsIf ItemType = Enums.FinancialReportItemsTypes.Dimension
		And Attributes.DimensionType = Enums.FinancialReportDimensionTypes.AnalyticalDimension Then
		FilterFields = New Structure("ExtDimension1", Attributes.AnalyticalDimensionType);
		SettingsSchema = IndicatorFilterSchema(FilterFields);
	ElsIf ItemType = Enums.FinancialReportItemsTypes.AccountingDataIndicator Then
		FilterFields = New Structure("Account", Attributes.Account);
		SettingsSchema = IndicatorFilterSchema(FilterFields, Attributes.TotalsType);
	Else
		Return;
	EndIf;
	
	#EndRegion
	
	SchemaAddress = PutToTempStorage(SettingsSchema.Schema, Attributes.UUID);
	
	LoadingSettingsToComposerIsNeeded = False;
	If ComposerReceiver = Undefined Then
 		ComposerReceiver = FinancialReportingServer.SchemaComposer(SettingsSchema.Schema);
		LoadingSettingsToComposerIsNeeded = True;
	EndIf;
	
	AvailableSettingsSource = New DataCompositionAvailableSettingsSource(SchemaAddress);
	ComposerReceiver.Initialize(AvailableSettingsSource);
	
	If LoadingSettingsToComposerIsNeeded Then
		ComposerReceiver.LoadSettings(SettingsSchema.Settings);
	EndIf;
	
	If AdditionalFilter <> Undefined Then
		If TypeOf(AdditionalFilter) = Type("ValueStorage") Then
			IndicatorSettings = AdditionalFilter.Get();
		Else
			IndicatorSettings = AdditionalFilter;
		EndIf;
		If IndicatorSettings <> Undefined Then
			ComposerReceiver.LoadSettings(IndicatorSettings);
		EndIf;
	EndIf;
	
	ComposerReceiver.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	
	Dimensions = New Structure("Scenario, Company, BusinessUnit, LineOfBusiness");
	For Each Field In FilterFields Do
		If Dimensions.Property(Field.Key)
			And FinancialReportingServer.FindFilterItem(ComposerReceiver.Settings.Filter, Field.Key) = Undefined Then
			Item = FinancialReportingServer.NewFilter(ComposerReceiver.Settings.Filter, Field.Key, Undefined);
			Item.Use = False;
		EndIf;
	EndDo;
	
	ToBeDeletedList = New Array;
	FinancialReportingServer.GetCustomizableFilterItems(ComposerReceiver.Settings.Filter, ToBeDeletedList, "");
	For Each ItemToBeDeleted In ToBeDeletedList Do
		ComposerReceiver.Settings.Filter.Items.Delete(ItemToBeDeleted);
	EndDo;
	
	ComposerReceiver.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	
EndProcedure

Procedure WriteReportTypeStructure(ReportType, ReportTypeItems, DeletionMark) Export
	
	UsedReportTypeItems = New ValueList;
	WriteToStructureParameters = GetWriteToReportStructureParameters();
	WriteToStructureParameters.ReportType	= ReportType;
	WriteToStructureParameters.DeletionMark	= DeletionMark;
	FillChangedDimensionsInFillingSources(ReportTypeItems, WriteToStructureParameters.DimensionsToBeReWritten);
	
	IterateWriteReportTypeStructure(ReportTypeItems, WriteToStructureParameters, UsedReportTypeItems);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	FinancialReportsItems.Ref AS Ref,
	|	FinancialReportsItems.Description AS Description
	|FROM
	|	Catalog.FinancialReportsItems AS FinancialReportsItems
	|WHERE
	|	FinancialReportsItems.Owner = &Owner
	|	AND NOT FinancialReportsItems.Ref IN (&Refs)";
	
	Query.SetParameter("Owner", ReportType);
	Query.SetParameter("Refs", UsedReportTypeItems);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	SetPrivilegedMode(True);
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		If Object <> Undefined Then
			Try
				Object.Delete();
			Except
				LanguageCode = CommonClientServer.DefaultLanguageCode();
				LogEventName = NStr("en = 'Writing of financial report type'; ru = 'Запись типа финансового отчета';pl = 'Pisanie typu raportu finansowego';es_ES = 'Escribir el tipo de informe financiero';es_CO = 'Escribir el tipo de informe financiero';tr = 'Mali rapor türünün yazımı';it = 'Scrittura del tipo di report finanziario';de = 'Schreiben der Art des Finanzberichts'", LanguageCode);
				ErrorText = NStr(
					"en = 'Deleting financial report item %2 failed while writing finacial report type %1. Reason: %3'; ru = 'Удаление элемента финансового отчета %2 завершилось неудачей при записи типа финансового отчета %1. Причина: %3';pl = 'Usunięcie elementu raportu finansowego %2 nie powiodło się podczas pisania typu raportu finansowego %1. Powód: %3';es_ES = 'Borrar el elemento del informe financiero %2 que ha fallado al escribir el tipo de informe financiero %1. Motivo: %3';es_CO = 'Borrar el elemento del informe financiero %2 que ha fallado al escribir el tipo de informe financiero %1. Motivo: %3';tr = 'Mali rapor türünü %1yazarken mali rapor öğesini %2 silme başarısız oldu. Sebebi: %3';it = 'Eliminazione della voce del report finanziario %2 fallita durante la scrittura del tipo di report finanziario %1. Causa: %3';de = 'Das Löschen der Finanzberichtsposition %2 ist beim Schreiben des Finanzberichtstyps %1 fehlgeschlagen. Grund: %3'",
					LanguageCode);
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, ReportType, Selection.Description,
					DetailErrorDescription(ErrorInfo()));
				
				WriteLogEvent(LogEventName,
					EventLogLevel.Error,
					Metadata.Catalogs.FinancialReportsItems,
					Selection.Ref,
					ErrorText);
			EndTry;
		EndIf;
	EndDo;
	SetPrivilegedMode(False);
	
EndProcedure

Function IndicatorSchema(Indicator, Dimensions = Undefined, AnalyticalDimension = Undefined, Resource = "Amount") Export
	
	If Indicator.ItemType = Enums.FinancialReportItemsTypes.AccountingDataIndicator Then
		IndicatorSchema = AccountingDataIndicatorSchema(Indicator, Dimensions, AnalyticalDimension, Resource);
	ElsIf Indicator.ItemType = Enums.FinancialReportItemsTypes.UserDefinedCalculatedIndicator Then
		IndicatorSchema = UserDefinedCalculatedIndicatorSchema(Indicator, Dimensions);
	Else
		IndicatorSchema = UserDefinedFixedIndicatorSchema(Indicator, Dimensions);
	EndIf;
	Return IndicatorSchema;
	
EndFunction

Function ReportIntervals(ReportPeriod) Export
	
	BeginOfPeriod = BegOfMonth(ReportPeriod.BeginOfPeriod);
	EndOfPeriod = EndOfMonth(ReportPeriod.EndOfPeriod);
	Periodicity = New Array;
	PeriodsHierarchy = New Array;
	ReportIntervals = NewIntervalsTable(PeriodsHierarchy);
	
	If ReportPeriod.Property("Periodicity") And ReportPeriod.Periodicity.Count() Then
		Periodicity = New Array;
		For Each Period In ReportPeriod.Periodicity Do
			Periodicity.Add(Period.Periodicity);
		EndDo;
	Else
		NewInterval = ReportIntervals.Add();
		NewInterval.EndDate = EndOfPeriod;
		NewInterval.StartDate = BeginOfPeriod;
		Return ReportIntervals;
	EndIf;
	
	MinimalPeriodicity = FinancialReportingClientServer.MinimalPeriodicity(Periodicity);
	
	StartDate = BeginOfPeriod;
	EndDate = BeginOfPeriod;
	While EndDate < EndOfPeriod Do
		
		EndDate = NewIntervalEndDate(EndDate, MinimalPeriodicity, EndOfPeriod);
		NewInterval = ReportIntervals.Add(); 
		NewInterval.StartDate = StartDate;
		NewInterval.EndDate = EndDate;
		For Each Period In PeriodsHierarchy Do
			If ValueIsFilled(Period) Then
				NewInterval["Period" + Period] = PeriodEndDate(NewInterval.StartDate, Enums.Periodicity[Period], EndOfPeriod);
			EndIf;
		EndDo;
		EndDate = EndDate + 1;
		StartDate = EndDate;
		
	EndDo;
	
	Return ReportIntervals;
	
EndFunction

#EndRegion

#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	Var AdditionalMode;
	
	If FormType = "ListForm" Or Not Parameters.Property("ItemType") Then
		Raise NStr("en = 'Service catalog ""Financial reports items"" contents
				|is edited in the owner catalog ""Financial reports types"".'; 
				|ru = 'Содержимое справочника ""Элементы финансовой отчетности""
				|редактируется в справочнике владельца ""Типы финансовой отчетности"".';
				|pl = 'Katalog usług ""Pozycje raportów finansowych"" jest edytowany 
				|w katalogu właściciela ""Typy raportów finansowych"".';
				|es_ES = 'El contenido del catálogo de servicios ""Elementos de informes financieros""
				|se edita en el catálogo del propietario ""Tipos de informes financieros"".';
				|es_CO = 'El contenido del catálogo de servicios ""Elementos de informes financieros""
				|se edita en el catálogo del propietario ""Tipos de informes financieros"".';
				|tr = 'Servis kataloğu ""Mali rapor öğeleri"" içerikleri
				|""Mali rapor türleri"" kataloğunda düzenlenmiştir.';
				|it = 'Il contenuto del catalogo di servizio ""Elementi dei report finanziari""
				|è modificato nel catalogo proprietario ""Tipi di report finanziari"".';
				|de = 'Der Leistungskatalog ""Finanzberichte Positionen""
				|ist im Eigentümerkatalog ""Finanzberichte Typen"" inhaltlich bearbeitet.'");
		Return;
	EndIf;
	
	If FormType <> "ObjectForm" Then
		Return;
	EndIf;
	
	Parameters.Property("FormAdditionalMode", AdditionalMode);
	If Parameters.Property("ItemType") Then
		
		StandardProcessing = False;
		FormUsageParameters = FinancialReportingServerCall.FormUsageParameters(
			Parameters.ItemType, Parameters.ItemAddressInTempStorage, AdditionalMode);
		SelectedForm = FormUsageParameters.FormName;
		
	ElsIf Parameters.Property("Key") And ValueIsFilled(Parameters.Key) Then
		
		StandardProcessing = False;
		SelectedForm = FinancialReportingServerCall.FormUsageParameters(
			Parameters.Key.ItemType, Parameters.Key, AdditionalMode);
		SelectedForm = FormUsageParameters.FormName;
		
	EndIf;
	
EndProcedure

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.FinancialReportsItems);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region Private

Function IndicatorFilterSchema(DimensionsNamesStructure, TotalsType = Undefined)
	
	If TotalsType = Undefined Then
		TotalsType = PredefinedValue("Enum.TotalsTypes.Balance");
	EndIf;
	IsTurnover = StrFind(Common.EnumValueName(TotalsType), "Balance") = 0;
	
	DCSchema = FinancialReportingServer.EmptySchema();
	DataSet = FinancialReportingServer.AddEmptyDataSet(DCSchema);
	
	DimensionName = "";
	IsFinancial = False;
	For Each KeyAndValue In DimensionsNamesStructure Do
		
		DimensionName = DimensionName + ?(IsBlankString(DimensionName), "", "," + Chars.LF);
		
		If TypeOf(KeyAndValue.Value) = Type("ChartOfAccountsRef.FinancialChartOfAccounts")
			Or TypeOf(KeyAndValue.Value) = Type("ChartOfAccountsRef.PrimaryChartOfAccounts") Then
			
			Account = KeyAndValue.Value;
			If ValueIsFilled(Account) And Common.ObjectAttributeValue(Account, "Currency") Then
				DimensionName = DimensionName + "(Currency).* AS Currency";
			EndIf;
			Counter = 1;
			For Each AccountAnalyticalDimensions In Account.ExtDimensionTypes Do
				AnaliticalDimensionName = "ExtDimension" + String(Counter);
				AnaliticalDimensionTitle = AccountAnalyticalDimensions.ExtDimensionType.Description;
				SetField = FinancialReportingServer.NewSetField(DataSet, AnaliticalDimensionName, , AnaliticalDimensionTitle);
				SetField.ValueType = AccountAnalyticalDimensions.ExtDimensionType.ValueType;
				DimensionName = DimensionName + ?(IsBlankString(DimensionName), "", "," + Chars.LF);
				DimensionName = DimensionName + "("+AnaliticalDimensionName + ").* AS " + AnaliticalDimensionName;
				Counter = Counter + 1;
			EndDo;
			
			If IsTurnover Then
				DimensionName = DimensionName + ?(IsBlankString(DimensionName), "", "," + Chars.LF);
				DimensionName = DimensionName + "(CurrencyBalanced).* AS CurrencyBalanced";
				SetField = FinancialReportingServer.NewSetField(DataSet, "CurrencyBalanced", , NStr("en = 'Bal. currency'; ru = 'Валюта баланса';pl = 'Saldo waluty';es_ES = 'Moneda de saldo';es_CO = 'Moneda de saldo';tr = 'Para birimi bakiyesi';it = 'Valuta Bilan.';de = 'Bal. Währung'"));
				BalancedAccountFilter = "{(BalancedAccount).* AS BalancedAccount}";
				SetField = FinancialReportingServer.NewSetField(DataSet, "BalancedAccount", , NStr("en = 'Bal. account'; ru = 'Счет баланса';pl = 'Saldo konta';es_ES = 'Cuenta a saldo';es_CO = 'Cuenta a saldo';tr = 'Hesap bakiyesi';it = 'Importo Bilan.';de = 'Bal. Konto'"));
				For Counter = 1 To 3 Do
					AnaliticalDimensionName = "ExtDimension" + String(Counter);
					BalancedAnaliticalDimensionName = "Balanced" + AnaliticalDimensionName;
					SetField = FinancialReportingServer.NewSetField(DataSet, BalancedAnaliticalDimensionName, , "Bal. " + AnaliticalDimensionName);
					DimensionName = DimensionName + ?(IsBlankString(DimensionName), "", "," + Chars.LF);
					DimensionName = DimensionName + "(" + BalancedAnaliticalDimensionName + ").* AS " + BalancedAnaliticalDimensionName;
				EndDo;
			EndIf;
			
			If TypeOf(Account) = Type("ChartOfAccountsRef.FinancialChartOfAccounts") Then
				IsFinancial = True;
			EndIf;
			
		ElsIf TypeOf(KeyAndValue.Value) = Type("ChartOfCharacteristicTypesRef.FinancialAnalyticalDimensionTypes")
			Or TypeOf(KeyAndValue.Value) = Type("ChartOfCharacteristicTypesRef.ManagerialAnalyticalDimensionTypes") Then
			
			AnalyticalDimensionTypeFilter = "{(&AnalyticalDimensionType)}";
			Parameter = DCSchema.Parameters.Add();
			Parameter.Name = "AnalyticalDimensionType";
			Parameter.Value = KeyAndValue.Value;
			Parameter.IncludeInAvailableFields = False;
			Parameter.UseRestriction = True;
			
			FieldTitle = KeyAndValue.Value.Description;
			SetField = FinancialReportingServer.NewSetField(DataSet, KeyAndValue.Key, , FieldTitle, KeyAndValue.Value.ValueType);
			DimensionName = DimensionName + "("+KeyAndValue.Key + ").* AS " + KeyAndValue.Key;
			
			If TypeOf(KeyAndValue.Value) = Type("ChartOfCharacteristicTypesRef.FinancialAnalyticalDimensionTypes") Then
				IsFinancial = True;
			EndIf;
			
		Else
			
			Dimension = Metadata.AccountingRegisters.AccountingJournalEntries.Dimensions.Find(KeyAndValue.Key);
			Title = KeyAndValue.Key;
			If Dimension <> Undefined Then
				Title = Dimension.Synonym;
			EndIf;
			SetField = FinancialReportingServer.NewSetField(DataSet, KeyAndValue.Key, , Title);
			DimensionName = "(" + KeyAndValue.Key + ").* AS " + KeyAndValue.Key;
			
		EndIf;
	EndDo;
	DimensionName = ?(IsBlankString(DimensionName), "", "{" + DimensionName + "}");
	
	If IsTurnover Then
		QueryText = 
		"SELECT ALLOWED
		|	RegisterData.ExtDimension1 AS ExtDimension1,
		|	RegisterData.ExtDimension2 AS ExtDimension2,
		|	RegisterData.ExtDimension3 AS ExtDimension3,
		|	RegisterData.BalancedAccount AS BalancedAccount,
		|	RegisterData.BalancedExtDimension1 AS BalancedExtDimension1,
		|	RegisterData.BalancedExtDimension2 AS BalancedExtDimension2,
		|	RegisterData.BalancedExtDimension3 AS BalancedExtDimension3
		|FROM
		|	AccountingRegister.AccountingJournalEntries.Turnovers( , , , , , " + DimensionName + ", " + BalancedAccountFilter + ", ) AS RegisterData";
	Else
		QueryText = 
		"SELECT ALLOWED
		|	RegisterData.ExtDimension1 AS ExtDimension1,
		|	RegisterData.ExtDimension2 AS ExtDimension2,
		|	RegisterData.ExtDimension3 AS ExtDimension3,
		|	RegisterData.AmountBalance AS Value
		|FROM
		|	AccountingRegister.AccountingJournalEntries.Balance( , , " + AnalyticalDimensionTypeFilter + ", " + DimensionName + ") AS RegisterData";
	EndIf;
	If IsFinancial Then
		QueryText = StrReplace(QueryText, "AccountingJournalEntries", "FinancialJournalEntries");
	EndIf;
	
	DataSet.AutoFillAvailableFields = False;
	DataSet.Query = QueryText;
	Composer = FinancialReportingServer.SchemaComposer(DCSchema);
	IndicatorSchema = New Structure("Schema, Settings", DCSchema, Composer.GetSettings());
	Return IndicatorSchema;
	
EndFunction

Function ParentsContainPeriod(Val TreeRow, Periodicity)
	
	While TreeRow <> Undefined
		And TreeRow.ItemType <> Enums.FinancialReportItemsTypes.Rows
		And TreeRow.ItemType <> Enums.FinancialReportItemsTypes.Columns Do
		
		If TreeRow.ItemType = Enums.FinancialReportItemsTypes.Dimension Then
			
			DimensionType = Undefined;
			If ValueIsFilled(TreeRow.ItemStructureAddress) Then
				DimensionType = FinancialReportingServerCall.AdditionalAttributeValue(TreeRow.ItemStructureAddress, "DimensionType");
			ElsIf ValueIsFilled(TreeRow.ReportType) Then
				DimensionType = FinancialReportingServerCall.AdditionalAttributeValue(TreeRow.ReportType, "DimensionType");
			Else
				If TypeOf(TreeRow.ItemIndicatorDimensionType) = Type("EnumRef.Periodicity") Then
					DimensionType = Enums.FinancialReportDimensionTypes.Period;
				EndIf;
			EndIf;
			
			If DimensionType = Enums.FinancialReportDimensionTypes.Period Then
				If ValueIsFilled(TreeRow.ItemStructureAddress) Then
					Periodicity = FinancialReportingServerCall.AdditionalAttributeValue(TreeRow.ItemStructureAddress, "Periodicity");
				ElsIf ValueIsFilled(TreeRow.ReportType) Then
					Periodicity = FinancialReportingServerCall.AdditionalAttributeValue(TreeRow.ReportType, "Periodicity");
				Else
					Periodicity = TreeRow.ItemIndicatorDimensionType
				EndIf;
				Return True;
			EndIf;
			
		EndIf;
		
		TreeRow = TreeRow.Parent;
		
	EndDo;
	
	Return False;
	
EndFunction

Function ChildItemsContainPeriod(Val TreeRow, Periodicity)
	
	For Each ChildRow In TreeRow.Rows Do
		
		If ChildRow.ItemType = Enums.FinancialReportItemsTypes.Dimension Then
			
			DimensionType = Undefined;
			If ValueIsFilled(ChildRow.ItemStructureAddress) Then
				DimensionType = FinancialReportingServerCall.AdditionalAttributeValue(ChildRow.ItemStructureAddress, "DimensionType");
			ElsIf ValueIsFilled(ChildRow.ReportType) Then
				DimensionType = FinancialReportingServerCall.AdditionalAttributeValue(ChildRow.ReportType, "DimensionType");
			Else
				If TypeOf(ChildRow.ItemIndicatorDimensionType) = Type("EnumRef.Periodicity") Then
					DimensionType = Enums.FinancialReportDimensionTypes.Period;
				EndIf;
			EndIf;
			
			If DimensionType = Enums.FinancialReportDimensionTypes.Period Then
				If ValueIsFilled(ChildRow.ItemStructureAddress) Then
					Periodicity = FinancialReportingServerCall.AdditionalAttributeValue(ChildRow.ItemStructureAddress, "Periodicity");
				ElsIf ValueIsFilled(ChildRow.ReportType) Then
					Periodicity = FinancialReportingServerCall.AdditionalAttributeValue(ChildRow.ReportType, "Periodicity");
				Else
					Periodicity = ChildRow.ItemIndicatorDimensionType
				EndIf;
				Return True;
			EndIf;
			
		EndIf;
		
		If ChildItemsContainPeriod(ChildRow, Periodicity) Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

Function ItemExpandedByPeriod(Parameters, GroupingPeriodicity = Undefined) Export
	
	ItemsTree = GetFromTempStorage(Parameters.ReportItemsAddress);
	If ValueIsFilled(Parameters.ItemsTableAddress) Then
		ItemsTable = GetFromTempStorage(Parameters.ItemsTableAddress)
	Else
		ItemsTable = Undefined;
	EndIf;
	
	Column = Undefined; Row = Undefined;
	
	If ItemsTable = Undefined Then
		
		TreeRow = ItemsTree.Rows.Find(Parameters.EditedItemAddress, "ItemStructureAddress", True);
		RootItem = FinancialReportingClientServer.RootItem(TreeRow, Enums.FinancialReportItemsTypes.TableIndicatorsInRows);
		ChildItemsSource = Undefined;
		If RootItem <> Undefined Then
			ChildItemsSource = FinancialReportingClientServer.ChildItem(RootItem, "ItemType", Enums.FinancialReportItemsTypes.Columns);
		EndIf;
		RootItem = FinancialReportingClientServer.RootItem(TreeRow, Enums.FinancialReportItemsTypes.TableIndicatorsInColumns);
		If RootItem <> Undefined Then
			ChildItemsSource = FinancialReportingClientServer.ChildItem(RootItem, "ItemType", Enums.FinancialReportItemsTypes.Rows);
		EndIf;
		
		HasPeriod = ParentsContainPeriod(TreeRow, GroupingPeriodicity)
					Or ChildItemsContainPeriod(TreeRow, GroupingPeriodicity)
					Or ?(ChildItemsSource = Undefined, False, ChildItemsContainPeriod(ChildItemsSource, GroupingPeriodicity));
		
	Else
		
		MatrixCell = ItemsTable.Find(Parameters.EditedItemAddress, "Item");
		
		TreeRow = ItemsTree.Rows.Find(MatrixCell.Row, "ItemStructureAddress", True);
		TreeColumn = ItemsTree.Rows.Find(MatrixCell.Column, "ItemStructureAddress", True);
		
		HasPeriod = ParentsContainPeriod(TreeRow, GroupingPeriodicity)
					Or ChildItemsContainPeriod(TreeRow, GroupingPeriodicity)
					Or ParentsContainPeriod(TreeColumn, GroupingPeriodicity)
					Or ChildItemsContainPeriod(TreeColumn, GroupingPeriodicity);
		
	EndIf;
	
	Return HasPeriod;
	
EndFunction

#Region OutputConfigureCellsTree

Function OutputCells(Form, Grouping, TableItems, RowsTree, RowNumber, PreviousColumnNumber = 3, Val Depth = 0)
	Var FormAdditionalMode;
	
	ItemsCount = 0; IsReportType = False;
	If Form.Parameters.Property("FormAdditionalMode", FormAdditionalMode) Then
		IsReportType = (FormAdditionalMode = Enums.ReportItemsAdditionalModes.ReportType);
	EndIf;
	
	For Each RowsTreeRow In RowsTree Do
		
		ColumnNumber = PreviousColumnNumber + ItemsCount;
		
		ChildItemsCount = OutputCells(Form, Grouping, TableItems, RowsTreeRow.Rows, RowNumber, ColumnNumber, Depth);
		
		If ChildItemsCount Then
			ItemsCount = ItemsCount + ChildItemsCount;
			Continue; // details were set in a recursive call
		Else
			ItemsCount = ItemsCount + 1;
		EndIf;
		
		// setting area details
		Area = Form.ReportPresentation.Area(RowNumber, ColumnNumber, RowNumber, ColumnNumber);
		
		DetailsStructure = New Structure("Row, Column, ItemType, ReportItem, IsLinked");
		DetailsStructure.IsLinked = False;

		DetailsStructure.Row  = New Structure("Description, ReportItem", Grouping.DescriptionForPrinting, Grouping.ItemStructureAddress);
		DetailsStructure.Column = New Structure("Description, ReportItem", RowsTreeRow.DescriptionForPrinting, RowsTreeRow.ItemStructureAddress);
		
		IsPredefinedFormula = False;
		ItemData = GetFromTempStorage(RowsTreeRow.ItemStructureAddress);
		If ItemData.ItemType = ItemType("Group")
			Or ItemData.ItemType = ItemType("GroupTotal") Then
			FormulaItem = RowsTreeRow.ItemStructureAddress;
			IsPredefinedFormula = True;
		Else
			ItemData = GetFromTempStorage(Grouping.ItemStructureAddress);
			If ItemData.ItemType = ItemType("Group")
				Or ItemData.ItemType = ItemType("GroupTotal") Then
				FormulaItem = Grouping.ItemStructureAddress;
				IsPredefinedFormula = True;
			EndIf;
		EndIf;
		
		OutputRowsAndColumnsCrossingItem = True;
		TableType = Undefined;
		If Form.Parameters.Property("CheckTableType") Then
			Form.Parameters.Property("TableType", TableType);
			If TableType = Enums.FinancialReportItemsTypes.TableIndicatorsInColumns
				Or TableType = Enums.FinancialReportItemsTypes.TableIndicatorsInRows Then
				OutputRowsAndColumnsCrossingItem = False;
			EndIf;
		EndIf;
		
		If OutputRowsAndColumnsCrossingItem Then
			
			If Not IsPredefinedFormula Then
				
				SearchStructure = New Structure("Row, Column");
				SearchStructure.Row = Grouping.ItemStructureAddress;
				SearchStructure.Column = RowsTreeRow.ItemStructureAddress;
				
				ItemRows = TableItems.FindRows(SearchStructure);
				If ItemRows.Count() Then
					ItemRow = ItemRows[0];
					If TypeOf(ItemRow.Item) = Type("CatalogRef.FinancialReportsItems")
						And ValueIsFilled(ItemRow.Item) Then
						ItemRow.Item = FinancialReportingServerCall.PutItemToTempStorage(
							ItemRow.Item, 
							Form.MainStorageID);
					EndIf;
					ItemData = GetFromTempStorage(ItemRow.Item);
					DetailsStructure.ItemType = ItemData.ItemType;
					DetailsStructure.ReportItem = ItemRow.Item;
				EndIf;
				
			Else
				
				DetailsStructure.ItemType = ItemData.ItemType;
				DetailsStructure.ReportItem = FormulaItem;
			
			EndIf;
		
		EndIf;
		
		If IsReportType And ItemData.ItemType = ItemType("Dimension") Then
			DetailsStructure.ItemType = ItemData.ItemType;
			DetailsStructure.ReportItem = Undefined;
		EndIf;
		
		Area.Details = DetailsStructure;
		SetCellText(Form, Area.Name);
		ApplyFormats(Area, "Cell");
		
	EndDo;
	
	Return ItemsCount;
	
EndFunction

Function OutputTreeToIndicators(Form, FirstRow, Rows, Val Depth, TotalDepth, Val PreviousColumnNumber = 3)
	
	ItemsCount = 0;
	
	For Each IndicatorRow In Rows Do
		
		ColumnNumber = PreviousColumnNumber + ItemsCount;
		
		Output = True;
		If IndicatorRow.ItemType = ItemType("Group") Then
			Output = (FinancialReportingServerCall.AdditionalAttributeValue(IndicatorRow.ItemStructureAddress, "OutputItemTitle") = True);
		EndIf;
		
		NewDepth = Depth;
		If Output Then
		
			RowNumber = FirstRow + Depth;
			Area = Form.ReportPresentation.Area(RowNumber, ColumnNumber, RowNumber, ColumnNumber);
			Area.Text = IndicatorRow.DescriptionForPrinting;
			Area.Details = IndicatorRow.ItemStructureAddress;
			Area.ColumnWidth = 15;
			
			NewDepth = Depth + 1;
			
		EndIf;
		
		ChildItemsCount = OutputTreeToIndicators(Form, FirstRow, IndicatorRow.Rows, NewDepth, TotalDepth, ColumnNumber);
		
		If ChildItemsCount Then
			ItemsCount = ItemsCount + ChildItemsCount;
			Area = Form.ReportPresentation.Area(RowNumber, ColumnNumber, RowNumber, ColumnNumber + ChildItemsCount - 1);
		Else
			Area = Form.ReportPresentation.Area(RowNumber, ColumnNumber, FirstRow + TotalDepth);
			ItemsCount = ItemsCount + 1;
		EndIf;
		
		If Output Then
			
			Area.Merge();
			ApplyFormats(Area, "CellHeader");
			
		EndIf;
		
	EndDo;
	
	Return ItemsCount;
	
EndFunction

Procedure ApplyFormats(Area, Mode)
	
	ThickLine = New Line(SpreadsheetDocumentCellLineType.Solid, 2);
	ThinLine = New Line(SpreadsheetDocumentCellLineType.Solid, 1);
	
	Area.TextPlacement = SpreadsheetDocumentTextPlacementType.Wrap;
	
	If Mode = "Row" Then
		Area.HorizontalAlign = HorizontalAlign.Left;
		Area.VerticalAlign = VerticalAlign.Center;
		Area.Font = New Font(, 10, False, False);
		Area.Outline(ThickLine, ThinLine, ThinLine, ThinLine);
	ElsIf Mode = "RowMerged" Then
		Area.HorizontalAlign = HorizontalAlign.Left;
		Area.VerticalAlign = VerticalAlign.Center;
		Area.Font = New Font(, 10, False, False);
		Area.Outline(ThinLine, ThinLine, ThinLine, ThinLine);
	ElsIf Mode = "RowTotal" Then
		Area.VerticalAlign = VerticalAlign.Center;
		Area.Font = New Font(, 10, True, False);
		Area.Outline(ThickLine, ThinLine, ThinLine, ThinLine);
	ElsIf Mode = "CellHeader" Then
		Area.Outline(ThinLine, ThinLine, ThinLine, ThinLine);
		Area.Font = New Font(, 10, True, False);
		Area.VerticalAlign = VerticalAlign.Center;
		Area.BackColor = StyleColors.ReportGroup1BackColor;
	ElsIf Mode = "TableTitle" Then
		Area.Outline(ThinLine, ThinLine, ThinLine, ThinLine);
		Area.Font = New Font(, 10, True, False);
		Area.VerticalAlign = VerticalAlign.Center;
		Area.BackColor = StyleColors.ReportGroup1BackColor;
	ElsIf Mode = "Header" Then
		Area.Outline(ThickLine, ThickLine, ThickLine, ThickLine);
	ElsIf Mode = "Cell" Then
		Area.Outline(ThinLine, ThinLine, ThinLine, ThinLine);
		Area.Font = New Font(, 8);
	ElsIf Mode = "CellTotal" Then
		Area.Outline(ThinLine, ThinLine, ThinLine, ThinLine);
		Area.Font = New Font(, 10, True, False);
	EndIf;
	
EndProcedure

Function NextRowIsMergedWithCurrent(IndicatorRow)
	
	If IndicatorRow.Rows.Count() = 1
		And IndicatorRow.Rows[0].OutputWithParental Then
		
		Return True;
		
	EndIf;
	
	Return False;
	
EndFunction

Procedure OutputTreeToRows(Form, RowsTree, OutputParameters, RowsNumber, Val Depth = 0, Val ColumnNumber = 0)
	
	TableItems	= OutputParameters.TableItems;
	ColumnsTree	= OutputParameters.ColumnsTree;
	FirstRow	= OutputParameters.FirstRow;
	UnionDepth	= OutputParameters.UnionDepth;
	
	Beginning = FirstRow + RowsNumber + 1;
	
	WereItemsForOutput = False;
	For Each IndicatorRow In RowsTree Do
		
		Output = True;
		If IndicatorRow.ItemType = ItemType("Group") Then
			Output = FinancialReportingServerCall.AdditionalAttributeValue(IndicatorRow.ItemStructureAddress, "OutputItemTitle");
		EndIf;
		
		NewDepth = Depth;
		If Output Then
			WereItemsForOutput = True;
			
			If IndicatorRow.OutputWithParental = True Then
				CurrentColumnNumber = ColumnNumber + 1;
				ApplyingMode = "RowMerged";
			Else
				CurrentColumnNumber = 0;
				RowsNumber = RowsNumber + 1;
				ApplyingMode = "Row";
			EndIf;
			RowNumber = FirstRow + RowsNumber;
			
			NextRowIsMerged = NextRowIsMergedWithCurrent(IndicatorRow);
			If NextRowIsMerged Then
				ColumnEnd = 2 + CurrentColumnNumber;
			Else
				ColumnEnd = 2 + UnionDepth - 1;
			EndIf;
			
			Area = Form.ReportPresentation.Area(RowNumber, 2 + CurrentColumnNumber, RowNumber, ColumnEnd);
			Area.Merge();
			Area.Text	 = IndicatorRow.DescriptionForPrinting;
			Area.Details = IndicatorRow.ItemStructureAddress;
			
			If IndicatorRow.OutputWithParental = False Then
				Area.Indent = Depth * 2;
			EndIf;
			
			ApplyFormats(Area, ApplyingMode);
			
			If Not NextRowIsMerged Then
				OutputCells(Form, IndicatorRow, TableItems, ColumnsTree, RowNumber, 3 + UnionDepth - 1);
			EndIf;
			
			NewDepth = Depth + 1;
		EndIf;
		
		OutputTreeToRows(Form,
			IndicatorRow.Rows,
			OutputParameters,
			RowsNumber,
			NewDepth,
			CurrentColumnNumber);
		
	EndDo;
	
	Ending = FirstRow + RowsNumber;
	
	If Depth > 0 And Beginning <= Ending And WereItemsForOutput Then
	
		Form.ReportPresentation.Area(Beginning, , Ending).Group(Depth);
	
	EndIf;
	
EndProcedure

Function ItemType(ItemTypeName)
	
	Return Enums.FinancialReportItemsTypes[ItemTypeName];
	
EndFunction

#EndRegion

#Region WriteReportType

Procedure IterateWriteReportTypeStructure(ReportTypeItems, WriteToStructureParameters, UsedReportTypeItems,
											Parent = Undefined, AdditionalOrder = 0, Cache = Undefined)
	
	If Parent = Undefined Then
		Parent = Catalogs.FinancialReportsItems.EmptyRef();
		Items = ReportTypeItems.Rows[0].Rows;
	Else
		Items = ReportTypeItems.Rows;
	EndIf;
	
	For Each Item In Items Do
		
		NewRef = ApplyChangesToObject(Item, Parent, WriteToStructureParameters, AdditionalOrder, UsedReportTypeItems, Cache);
		IterateWriteReportTypeStructure(Item, WriteToStructureParameters, UsedReportTypeItems, NewRef, AdditionalOrder, Cache);
		
	EndDo;
	
EndProcedure

Function GetWriteToReportStructureParameters()
	Parameters = New Structure;
	Parameters.Insert("ReportType", Undefined);
	Parameters.Insert("DeletionMark", False);
	Parameters.Insert("DimensionsToBeReWritten", New Array);
	
	Return Parameters;
EndFunction

Procedure FillChangedDimensionsInFillingSources(Val Item, SourcesModifications, Cache = Undefined)
	
	If TypeOf(Item) = Type("ValueTree") Then
		
		Row = Item.Rows[0];
		
	Else
		
		Row = Item;
		
		If Row.ItemType = Enums.FinancialReportItemsTypes.Dimension
			And IsBlankString(Row.ItemStructureAddress)
			And ValueIsFilled(Row.ReportItem) Then
			
			SourcesFillingIsNeeded = False;
			SourcesAreModified = False;
			IsFilling = False;
			DimensionType = FinancialReportingServerCall.AdditionalAttributeValue(Row.ReportItem, "DimensionType");
			
			If DimensionType = Enums.FinancialReportDimensionTypes.Analytics
				Or DimensionType = Enums.FinancialReportDimensionTypes.RegisterDimension Then
				SourcesFillingIsNeeded = True;
			EndIf;
			
			If DimensionType = Enums.FinancialReportDimensionTypes.FixedAnalytics Then
				If FinancialReportingServerCall.AdditionalAttributeValue(Row.ReportItem, "AllowEditing") = True Then
					SourcesFillingIsNeeded = True;
					IsFilling = True;
				EndIf;
			EndIf;
			
			If SourcesFillingIsNeeded Then
				AvailableItemsList = FinancialReportingServer.ItemValuesSources(Cache, Row, IsFilling);
				SavedSources = New Array;
				For Each SourceRow In AvailableItemsList Do
					If TypeOf(SourceRow.Item) = Type("String") Then
						SourcesAreModified = True;
						Break;
					Else
						SavedSources.Add(SourceRow.Item);
					EndIf;
				EndDo;
				If Not SourcesAreModified Then
					
					Query = New Query;
					Query.Text = 
						"SELECT TOP 1
						|	Sources.Source AS Source
						|FROM
						|	Catalog.FinancialReportsItems.ValuesSources AS Sources
						|WHERE
						|	Sources.Ref = &Dimension
						|	AND NOT Sources.Source IN (&SavedSources)";
					Query.SetParameter("Dimension", Row.ReportItem);
					Query.SetParameter("SavedSources", SavedSources);
					SourcesAreModified = Not Query.Execute().IsEmpty();
					
				EndIf;
			EndIf;
			If SourcesAreModified Then
				If SourcesModifications.Find(Row.ReportItem) = Undefined Then
					SourcesModifications.Add(Row.ReportItem);
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	TreeRows = Row.Rows;
	For Each TreeRow In TreeRows Do
		FillChangedDimensionsInFillingSources(TreeRow, SourcesModifications, Cache);
	EndDo;
	
EndProcedure

Function GetItemObject(ItemRef, ObjectData)
	
	If ValueIsFilled(ItemRef) Then
		ItemObject = ItemRef.GetObject();
	EndIf;
	
	If ItemObject = Undefined Then
		ItemObject = Catalogs.FinancialReportsItems.CreateItem();
		If ValueIsFilled(ItemRef) Then
			ItemObject.SetNewObjectRef(ItemRef);
		ElsIf ValueIsFilled(ObjectData.Ref) Then
			ItemObject.SetNewObjectRef(ObjectData.Ref);
		EndIf;
	EndIf;
	
	Return ItemObject;
	
EndFunction

Procedure FillObjectByTempStorageData(Object, ObjectData, Code, Owner, Parent)
	
	Object.Code = Code;
	Object.Owner = Owner;
	Object.Parent = Parent;
	
	If ObjectData.Property("Parent") Then
		Suffix = ", Parent";
	EndIf;
	
	FillPropertyValues(Object, ObjectData, , 
		"Code, Owner" + Suffix + ", ItemTypeAttributes, FormulaOperands, TableItems,
		|AdditionalFields, AppearanceItems, AppearanceAppliedRows, AppearanceAppliedColumns, AppearanceItemsFilterFieldsDetails, ValuesSources");
		
	Object.ItemTypeAttributes.Load(ObjectData.ItemTypeAttributes);
	Object.FormulaOperands.Load(ObjectData.FormulaOperands);
	Object.TableItems.Load(ObjectData.TableItems);
	Object.AdditionalFields.Load(ObjectData.AdditionalFields);
	Object.AppearanceItems.Load(ObjectData.AppearanceItems);
	Object.AppearanceAppliedRows.Load(ObjectData.AppearanceAppliedRows);
	Object.AppearanceAppliedColumns.Load(ObjectData.AppearanceAppliedColumns);
	Object.AppearanceItemsFilterFieldsDetails.Load(ObjectData.AppearanceItemsFilterFieldsDetails);
	Object.ValuesSources.Load(ObjectData.ValuesSources);
	
	If Object.ItemType = PredefinedValue("Enum.FinancialReportItemsTypes.TableCell") Then
		
		ItemRef = FinancialReportingServerCall.AdditionalAttributeValue(Object, "CellRow");
		If TypeOf(ItemRef) = Type("String") Then
			ItemRef = GetFromTempStorage(ItemRef);
			If ItemRef <> Undefined Then
				ItemRef = ItemRef.Ref;
			EndIf;
			FinancialReportingServerCall.SetAdditionalAttributeValue(Object, "CellRow", ItemRef);
		EndIf;
		
		ItemRef = FinancialReportingServerCall.AdditionalAttributeValue(Object, "CellColumn");
		If TypeOf(ItemRef) = Type("String") Then
			ItemRef = GetFromTempStorage(ItemRef);
			If ItemRef <> Undefined Then
				ItemRef = ItemRef.Ref;
			EndIf;
			FinancialReportingServerCall.SetAdditionalAttributeValue(Object, "CellColumn", ItemRef);
		EndIf;
		
	EndIf;
	
EndProcedure

Function ItemFieldValueFromCache(Item, FieldName, Cache, ReportType = Undefined) Export
	
	If Cache = Undefined Then
		
		Query = New Query;
		If ReportType = Undefined Then
			Query.Text = 
			"SELECT
			|	*
			|FROM
			|	Catalog.FinancialReportsItems AS FinancialReportsItems
			|WHERE
			|	FinancialReportsItems.Owner IN
			|			(SELECT TOP 1
			|				FinancialReportsItems.Owner
			|			FROM
			|				Catalog.FinancialReportsItems AS FinancialReportsItems
			|			WHERE
			|				FinancialReportsItems.Ref = &Ref)";
			Query.SetParameter("Ref", Item);
		Else
			Query.Text = 
			"SELECT
			|	*
			|FROM
			|	Catalog.FinancialReportsItems AS FinancialReportsItems
			|WHERE
			|	FinancialReportsItems.Owner = &Owner";
			Query.SetParameter("Owner", ReportType);
		EndIf;
		Cache = Query.Execute().Unload();
		Cache.Indexes.Add("Ref");
		
	EndIf;
	
	FoundRow = Cache.Find(Item, "Ref");
	If FoundRow = Undefined Then
		Cache = Undefined;
		Return ItemFieldValueFromCache(Item, FieldName, Cache, ReportType);
	EndIf;
	Return FoundRow[FieldName];
	
EndFunction

Procedure RefreshCache(ItemRef, Cache, ItemStructure = Undefined)
	FoundRow = Cache.Find(ItemRef, "Ref");
	If FoundRow = Undefined Then
		FoundRow = Cache.Add();
		FoundRow.Ref = ItemRef;
	EndIf;
	If ItemStructure = Undefined Then
		Query = New Query;
		Query.Text = 
			"SELECT
			|	*
			|FROM
			|	Catalog.FinancialReportsItems AS FinancialReportsItems
			|WHERE
			|	FinancialReportsItems.Ref = &Ref";
		Query.SetParameter("Ref", ItemRef);
		Result = Query.Execute().Unload();
		If Result.Count() > 0 Then
			ItemStructure = Result[0];
		EndIf;
	EndIf;
	If Not ItemStructure = Undefined Then
		FillPropertyValues(FoundRow, ItemStructure);
	EndIf;
EndProcedure

Function RefreshCreateItemByTempStorageData(ItemRef, ItemStructureAddress, AdditionalOrder, ReportType, Parent, UsedReportTypeItems)
	
	If Not IsBlankString(ItemStructureAddress) Then
		ItemData = GetFromTempStorage(ItemStructureAddress);
		If ItemRef = Undefined Then
			If ValueIsFilled(ItemData.Ref) Then
				ItemRef = ItemData.Ref;
			EndIf;
		EndIf;
	Else
		ItemData = GetFromTempStorage(FinancialReportingServerCall.PutItemToTempStorage(ItemRef));
	EndIf;
	
	ItemObject = GetItemObject(ItemRef, ItemData);
	If ItemObject = Undefined Then
		Return Undefined;
	EndIf;

	If ItemObject.IsNew() And (ItemData.FormulaOperands.Count() Or ItemData.TableItems.Count()) Then
		
		ItemObject.Owner = ReportType;
		ItemObject.ItemType = ItemData.ItemType;
		ItemObject.ItemTypeAttributes.Load(ItemData.ItemTypeAttributes);
		ItemObject.Write();
		
	EndIf;
	
	For Each Operand In ItemData.FormulaOperands Do
		If ValueIsFilled(Operand.ItemStructureAddress) Then
			NewOperand = RefreshCreateItemByTempStorageData(Operand.Operand, Operand.ItemStructureAddress,
				AdditionalOrder, ReportType, ItemObject.Ref, UsedReportTypeItems);
			Operand.Operand = NewOperand;
		EndIf;
		UsedReportTypeItems.Add(Operand.Operand);
	EndDo;
	
	For Each TableItem In ItemData.TableItems Do
		
		ColumnsStructure = New Structure("Row, Column");
		
		For Each KeyAndValue In ColumnsStructure Do
			
			If TypeOf(TableItem[KeyAndValue.Key]) = Type("String") Then
				
				TableItemData = GetFromTempStorage(TableItem[KeyAndValue.Key]);
				If Not ValueIsFilled(TableItemData) Then
					TableItem[KeyAndValue.Key] = Undefined;
				Else
					TableItem[KeyAndValue.Key] = TableItemData.Ref;
				EndIf;
				
			EndIf;
			
		EndDo;
		
		If ValueIsFilled(TableItem.Row) And ValueIsFilled(TableItem.Column) Then
			
			If TypeOf(TableItem.Item) = Type("String") Then
			
				NewItem = RefreshCreateItemByTempStorageData(Undefined, TableItem.Item, AdditionalOrder,
					ReportType, ItemObject.Ref, UsedReportTypeItems);
				TableItem.Item = NewItem;
			
			EndIf;
			
		EndIf;
			
	EndDo;
	
	For Each TableItem In ItemData.AppearanceAppliedRows Do
		
		If TypeOf(TableItem.ReportType) = Type("String") Then
			
			If ValueIsFilled(TableItem.ReportType) Then
				TableItemData = GetFromTempStorage(TableItem.ReportType);
			Else
				TableItemData = Undefined;
			EndIf;
			If Not ValueIsFilled(TableItemData) Then
				TableItem.ReportType = Undefined;
			Else
				TableItem.ReportType = TableItemData.Ref;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	For Each TableItem In ItemData.AppearanceAppliedColumns Do
		
		If TypeOf(TableItem.ReportType) = Type("String") Then
			
			If ValueIsFilled(TableItem.ReportType) Then
				TableItemData = GetFromTempStorage(TableItem.ReportType);
			Else
				TableItemData = Undefined;
			EndIf;
			If Not ValueIsFilled(TableItemData) Then
				TableItem.ReportType = Undefined;
			Else
				TableItem.ReportType = TableItemData.Ref;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	For Each TableItem In ItemData.AppearanceItemsFilterFieldsDetails Do
		
		If TypeOf(TableItem.ReportType) = Type("String") Then
			
			TableItemData = GetFromTempStorage(TableItem.ReportType);
			If Not ValueIsFilled(TableItemData) Then
				TableItem.ReportType = Undefined;
			Else
				TableItem.ReportType = TableItemData.Ref;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	RowsNumber = ItemData.TableItems.Count();
	For Counter = 1 To RowsNumber Do
		
		TableItem = ItemData.TableItems[RowsNumber - Counter];
		If Not ValueIsFilled(TableItem.Row)
			Or Not ValueIsFilled(TableItem.Column)
			Or Not ValueIsFilled(TableItem.Item) Then
			
			ItemData.TableItems.Delete(TableItem);
			Continue;
			
		EndIf;
		
		UsedReportTypeItems.Add(TableItem.Row);
		UsedReportTypeItems.Add(TableItem.Column);
		UsedReportTypeItems.Add(TableItem.Item);
		Operands = TableItem.Item.FormulaOperands;
		For Each Operand In Operands Do
			UsedReportTypeItems.Add(Operand.Operand);
		EndDo;
		
	EndDo;
	
	FillObjectByTempStorageData(ItemObject, ItemData, AdditionalOrder, ReportType, Parent);
	
	ItemObject.Write();
	
	If ValueIsFilled(ItemStructureAddress) Then
		FinancialReportingServerCall.PutItemToTempStorage(ItemObject, ItemStructureAddress);
	EndIf;
	
	Return ItemObject.Ref;
	
EndFunction

Function ApplyChangesToObject(Item, Parent, WriteToStructureParameters, AdditionalOrder, UsedReportTypeItems, Cache)
	
	DeletionMark			= WriteToStructureParameters.DeletionMark;
	ReportType				= WriteToStructureParameters.ReportType;
	DimensionsToBeReWritten	= WriteToStructureParameters.DimensionsToBeReWritten;
	
	AdditionalOrder = AdditionalOrder + 1;
	
	If IsBlankString(Item.ItemStructureAddress)
		And Not Item.ReportItem.IsEmpty()
		And DimensionsToBeReWritten.Find(Item.ReportItem) = Undefined
		And ItemFieldValueFromCache(Item.ReportItem, "Code", Cache, ReportType) = AdditionalOrder
		And ItemFieldValueFromCache(Item.ReportItem, "Parent", Cache, ReportType) = Parent 
		And ItemFieldValueFromCache(Item.ReportItem, "DeletionMark", Cache, ReportType) = DeletionMark Then
		
		Operands = ItemFieldValueFromCache(Item.ReportItem, "FormulaOperands", Cache, ReportType);
		For Each Operand In Operands Do
			UsedReportTypeItems.Add(Operand.Operand);
		EndDo;
		
		TableItems = ItemFieldValueFromCache(Item.ReportItem, "TableItems", Cache, ReportType);
		For Each TableItem In TableItems Do
			UsedReportTypeItems.Add(TableItem.Row);
			UsedReportTypeItems.Add(TableItem.Column);
			UsedReportTypeItems.Add(TableItem.Item);
			Operands = ItemFieldValueFromCache(TableItem.Item, "FormulaOperands", Cache, ReportType);
			For Each Operand In Operands Do
				UsedReportTypeItems.Add(Operand.Operand);
			EndDo;
		EndDo;
		
		UsedReportTypeItems.Add(Item.ReportItem);
		
		Return Item.ReportItem;
		
	EndIf;
	
	// if new item - save data in temp storage
	ItemData = Item.ItemStructureAddress;
	
	FormStorageIsUsed = True;
	UID = New UUID;
	If Not ValueIsFilled(Item.ReportItem) 
		And Not ValueIsFilled(ItemData) Then
		If TypeOf(ReportType) = Type("CatalogRef.FinancialReportsTypes") Then
			ItemData = FinancialReportingClientServer.PutItemToTempStorage(Item, UID);
		EndIf;
		FormStorageIsUsed = False;
	EndIf;
	If Not ValueIsFilled(ItemData) And Not DimensionsToBeReWritten.Find(Item.ReportItem) = Undefined Then
		ItemData = FinancialReportingClientServer.PutItemToTempStorage(Item, UID);
		FormStorageIsUsed = False;
	EndIf;
	
	ItemStructure = Undefined;
	
	ItemRef = RefreshCreateItemByTempStorageData(Item.ReportItem, ItemData, AdditionalOrder, ReportType, Parent, UsedReportTypeItems);
	
	If TypeOf(Cache) = Type("ValueTable") Then
		RefreshCache(ItemRef, Cache, ItemStructure);
	EndIf;
	
	If ItemRef = Undefined Then
		Item.ReportItem = ItemRef;
	ElsIf Not ValueIsFilled(Item.ReportItem) Then
		Item.ReportItem = ItemRef;
	EndIf;
	If Not FormStorageIsUsed Then
		DeleteFromTempStorage(ItemData);
	EndIf;
	Item.ItemStructureAddress = "";
	UsedReportTypeItems.Add(Item.ReportItem);
	
	Return ItemRef;
	
EndFunction

#EndRegion

#Region FinancialReporting

Function AccountingDataIndicatorSchema(Indicator, Dimensions = Undefined, AnalyticalDimension = Undefined, Resource = "Amount")
	
	Source = "AccountingJournalEntries";
	If TypeOf(Indicator.Account) = Type("ChartOfAccountsRef.FinancialChartOfAccounts") Then
		Source = "FinancialJournalEntries";
	EndIf;
	
	ResourceSuffix = Common.EnumValueName(Indicator.TotalsType);
	
	IsBalance = StrFind(ResourceSuffix, "Balance") > 0;
	
	If IsBalance Then
		OpeningResourceName = Resource + "Opening" + ResourceSuffix;
		ClosingResourceName = Resource + "Closing" + ResourceSuffix;
		DCSchema = GetTemplate("AccountingDataIndicatorBalance");
		QueryText = DCSchema.DataSets.IndicatorValues.Query;
		QueryText = StrReplace(QueryText, "AmountOpeningBalance", OpeningResourceName);
		QueryText = StrReplace(QueryText, "AmountClosingBalance", ClosingResourceName);
		If Indicator.OpeningBalance Then
			QueryText = StrReplace(QueryText, "BalanceField", "temp");
			QueryText = StrReplace(QueryText, "Value", "BalanceField");
			QueryText = StrReplace(QueryText, "temp", "Value");
		EndIf;
	Else
		ResourceName = Resource + ResourceSuffix;
		DCSchema = GetTemplate("AccountingDataIndicatorTurnover");
		QueryText = DCSchema.DataSets.IndicatorValues.Query;
		QueryText = StrReplace(QueryText, "AmountTurnover", ResourceName);
	EndIf;
	
	AddDimensionsFields(QueryText, Dimensions);
	
	QueryText = StrReplace(QueryText, "AccountingJournalEntries", Source);
	DCSchema.DataSets.IndicatorValues.Query = QueryText;
	
	AddDimensionsFields(DCSchema.DefaultSettings, Dimensions);
	If AnalyticalDimension <> Undefined Then
		FinancialReportingServer.SetCompositionParameter(DCSchema.DefaultSettings, "TurnoverAnalyticalDimensionType", AnalyticalDimension.Type);
		If AnalyticalDimension.HasSettings Then
			AnalyticalDimensionFilterSettings = AnalyticalDimension.Filter.Get();
			FinancialReportingServer.CopyFilter(AnalyticalDimensionFilterSettings.Filter, DCSchema.DefaultSettings.Filter, False);
		EndIf;
	EndIf;
	
	If IsBalance Then
		BalanceRole = FinancialReportingServer.DataSetFieldNewRole();
		BalanceRole.BalanceGroup = "Balance";
		BalanceRole.Balance = True;
		BalanceRole.AccountField = "Account";
		If Indicator.OpeningBalance Then
			BalanceRole.BalanceType = DataCompositionBalanceType.OpeningBalance;
			FinancialReportingServer.SetDataSetFieldRole(DCSchema.DataSets.IndicatorValues, "Value", BalanceRole);
			
			BalanceRole.BalanceType = DataCompositionBalanceType.ClosingBalance;
			FinancialReportingServer.SetDataSetFieldRole(DCSchema.DataSets.IndicatorValues, "BalanceField", BalanceRole);
			
		Else
			BalanceRole.BalanceType = DataCompositionBalanceType.ClosingBalance;
			FinancialReportingServer.SetDataSetFieldRole(DCSchema.DataSets.IndicatorValues, "Value", BalanceRole);
			
			BalanceRole.BalanceType = DataCompositionBalanceType.OpeningBalance;
			FinancialReportingServer.SetDataSetFieldRole(DCSchema.DataSets.IndicatorValues, "BalanceField", BalanceRole);
			
		EndIf;
	Else
		FinancialReportingServer.SetDataSetFieldRole(DCSchema.DataSets.IndicatorValues, "Value");
	EndIf;
	
	FinancialReportingServer.SetFilter(DCSchema.DefaultSettings.Filter, "Account", Indicator.Account);
	
	Composer = FinancialReportingServer.SchemaComposer(DCSchema);
	If Indicator.HasSettings Then
		IndicatorFilterSettings = Indicator.AdditionalFilter.Get();
		If IndicatorFilterSettings <> Undefined Then
			FinancialReportingServer.CopyFilter(IndicatorFilterSettings.Filter, Composer.Settings.Filter, False);
		EndIf;
	EndIf;
	
	FinancialReportingServer.SetCompositionParameter(Composer.Settings, "ReportItem",	Indicator.ReportItem);
	FinancialReportingServer.SetCompositionParameter(Composer.Settings, "ReverseSign",	Indicator.ReverseSign);
	FinancialReportingServer.SetCompositionParameter(Composer.Settings, "RowCode",		Indicator.RowCode);
	FinancialReportingServer.SetCompositionParameter(Composer.Settings, "Note",			Indicator.Note);
	
	If AnalyticalDimension <> Undefined Then
		FinancialReportingServer.SetCompositionParameter(Composer.Settings, "TurnoverAnalyticalDimensionType", AnalyticalDimension.Type);
	EndIf;
	
	IndicatorSchema = New Structure("Schema, Settings", DCSchema, Composer.GetSettings());
	Return IndicatorSchema;
	
EndFunction

Function UserDefinedFixedIndicatorSchema(Indicator, Dimensions = Undefined, Filter = Undefined)
	
	DCSchema = GetTemplate("UserDefinedFixedIndicator");
	QueryText = DCSchema.DataSets.IndicatorValues.Query;
	AddDimensionsFields(QueryText, Dimensions);
	
	DCSchema.DataSets.IndicatorValues.Query = QueryText;
	
	AddDimensionsFields(DCSchema.DefaultSettings, Dimensions);
	
	Composer = FinancialReportingServer.SchemaComposer(DCSchema);
	FinancialReportingServer.SetCompositionParameter(Composer.Settings, "Indicator", Indicator.UserDefinedFixedIndicator);
	
	IndicatorSchema = New Structure("Schema, Settings", DCSchema, Composer.GetSettings());
	Return IndicatorSchema;
	
EndFunction

Function UserDefinedCalculatedIndicatorSchema(Indicator, Dimensions = Undefined, Filter = Undefined)
	
	DCSchema = GetTemplate("UserDefinedCalculatedIndicator");
	NumberType = Common.TypeDescriptionNumber(15, 2);
	FormulaOperands = Indicator.ReportItem.FormulaOperands;
	If Indicator.IsLinked Then
		FormulaOperands = Indicator.LinkedItem.FormulaOperands;
	EndIf;
	For Each Operand In FormulaOperands Do
		NewDataSetField = FinancialReportingServer.NewSetField(DCSchema.DataSets.OperandsValues, Operand.ID, , , NumberType);
	EndDo;
	For Each Dimension In Dimensions Do
		NewDataSetField = FinancialReportingServer.NewSetField(DCSchema.DataSets.OperandsValues, Dimension.Value);
		FinancialReportingServer.NewSelectionField(DCSchema.DefaultSettings, Dimension.Value);
	EndDo;
	
	ValueField = DCSchema.CalculatedFields[0];
	If Not IsBlankString(Indicator.Formula) Then
		ValueField.Expression = "(" + Indicator.Formula + ") * CASE WHEN &ReverseSign = TRUE THEN -1 ELSE 1 END";
	EndIf;
	Composer = FinancialReportingServer.SchemaComposer(DCSchema);
	
	IndicatorSchema = New Structure("Schema, Settings", DCSchema, Composer.GetSettings());
	Return IndicatorSchema;
	
EndFunction

Procedure AddDimensionsFields(TextDataSet, Dimensions)
	
	IsQueryText = TypeOf(TextDataSet) = Type("String");
	For Each Dimension In Dimensions Do
		If IsQueryText Then
			Field = "RegisterTable." + Dimension.Value;
			TextDataSet = StrReplace(TextDataSet, "//" + Field, Field);
			If Dimension.Value = "ExtDimension1" Then
				TextDataSet = StrReplace(TextDataSet, "//&AnalyticalDimensionType", "&AnalyticalDimensionType");
			EndIf;
		Else
			FinancialReportingServer.NewSelectionField(TextDataSet, Dimension.Value, Dimension.Presentation);
			If Dimension.Filter <> Undefined Then
				FinancialReportingServer.CopyFilter(Dimension.Filter, TextDataSet.Filter, True);
			EndIf;
			If Dimension.Value = "ExtDimension1" Then
				FinancialReportingServer.NewSelectionField(TextDataSet, "AnalyticalDimensionType", "AnalyticalDimensionType");
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

#Region GettingReportIntervalsTable

Function NewIntervalEndDate(PeriodDate, Periodicity, EndOfPeriod)
	
	PeriodEndDate = PeriodDate;
	If Periodicity = Enums.Periodicity.Month Then
		PeriodEndDate = EndOfMonth(PeriodEndDate);
		
	ElsIf Periodicity = Enums.Periodicity.Quarter Then
		PeriodEndDate = EndOfQuarter(PeriodEndDate);
		
	ElsIf Periodicity = Enums.Periodicity.HalfYear Then
		PeriodEndDate = AddMonth(PeriodEndDate, 5);
		
	ElsIf Periodicity = Enums.Periodicity.Year Then
		PeriodEndDate = AddMonth(PeriodEndDate, 11);
		
	Else
		PeriodEndDate = EndOfPeriod;
		
	EndIf;
	PeriodEndDate = EndOfMonth(PeriodEndDate);
	If PeriodEndDate > EndOfPeriod Then
		PeriodEndDate = EndOfPeriod;
	EndIf;
	Return PeriodEndDate;
	
EndFunction

Function PeriodEndDate(PeriodDate, Periodicity, EndOfPeriod)
	
	PeriodEndDate = PeriodDate;
	If Periodicity = Enums.Periodicity.Month Then
		PeriodEndDate = EndOfMonth(PeriodEndDate);
		
	ElsIf Periodicity = Enums.Periodicity.Quarter Then
		PeriodEndDate = EndOfQuarter(PeriodEndDate);
		
	ElsIf Periodicity = Enums.Periodicity.HalfYear Then
		If Month(PeriodEndDate) <= 6 Then
			PeriodEndDate = Date(Year(PeriodEndDate), 6, 30, 23, 59, 59);
		Else
			PeriodEndDate = Date(Year(PeriodEndDate), 12, 31, 23, 59, 59);
		EndIf;
		
	ElsIf Periodicity = Enums.Periodicity.Year Then
		PeriodEndDate = EndOfYear(PeriodEndDate);
		
	Else
		PeriodEndDate = EndOfPeriod;
		
	EndIf;
	PeriodEndDate = EndOfMonth(PeriodEndDate);
	If PeriodEndDate > EndOfPeriod Then
		PeriodEndDate = EndOfPeriod;
	EndIf;
	Return PeriodEndDate;
	
EndFunction

Function NewIntervalsTable(PeriodsHierarchy = Undefined)
	
	Intervals = New ValueTable;
	Intervals.Columns.Add("Indicator", New TypeDescription("CatalogRef.FinancialReportsItems"));
	Intervals.Columns.Add("RowCode" , New TypeDescription("String", , New StringQualifiers(20)));
	Intervals.Columns.Add("Note", New TypeDescription("String", , New StringQualifiers(100)));
	
	DateType = New TypeDescription("Date", , , New DateQualifiers(DateFractions.DateTime));
	Intervals.Columns.Add("StartDate",		DateType);
	Intervals.Columns.Add("EndDate",		DateType);
	Intervals.Columns.Add("PeriodYear",		DateType);
	Intervals.Columns.Add("PeriodHalfYear",	DateType);
	Intervals.Columns.Add("PeriodQuarter",	DateType);
	Intervals.Columns.Add("PeriodMonth",	DateType);
	
	PeriodsHierarchy.Add("Year");
	PeriodsHierarchy.Add("HalfYear");
	PeriodsHierarchy.Add("Quarter");
	PeriodsHierarchy.Add("Month");
	
	Return Intervals;
	
EndFunction

#EndRegion

#EndRegion

#EndRegion

#EndIf