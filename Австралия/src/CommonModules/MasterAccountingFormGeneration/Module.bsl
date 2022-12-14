
#Region Public

Procedure GenerateMasterTables(Form, Parameters, PagesGroupName) Export
	
	Var Recorder;
	Var Company;
	Var Period;
	Var ChartOfAccounts;
	Var TypeOfAccounting;
	
	DeleteAttributes(Form);
	
	Parameters.Property("Recorder"			, Recorder);
	Parameters.Property("Company"			, Company);
	Parameters.Property("Period"			, Period);
	Parameters.Property("TypeOfAccounting"	, TypeOfAccounting);
	Parameters.Property("ChartOfAccounts"	, ChartOfAccounts);
	
	If Not ValueIsFilled(ChartOfAccounts) And Not ValueIsFilled(Recorder) Then
		
		TableParameters = New Structure;
		TableParameters.Insert("TypeOfAccounting"		, TypeOfAccounting);
		TableParameters.Insert("ChartOfAccounts"		, ChartOfAccounts);
		TableParameters.Insert("TypeOfEntries"			, Enums.ChartsOfAccountsTypesOfEntries.Simple);
		TableParameters.Insert("PagesGroupName"			, PagesGroupName);
		TableParameters.Insert("UseAnalyticalDimensions", True);
		TableParameters.Insert("UseQuantity"			, True);
		
		GenerateMasterTable(Form, TableParameters, True);
			
		Return;
		
	EndIf;
	
	Query = New Query;
	
	If ValueIsFilled(Recorder) Then
		
		Query.Text =
		"SELECT
		|	CompaniesTypesOfAccountingSliceLast.TypeOfAccounting AS TypeOfAccounting,
		|	CompaniesTypesOfAccountingSliceLast.ChartOfAccounts AS ChartOfAccounts,
		|	ChartsOfAccounts.UseQuantity AS UseQuantity,
		|	ChartsOfAccounts.UseAnalyticalDimensions AS UseAnalyticalDimensions,
		|	ChartsOfAccounts.TypeOfEntries AS TypeOfEntries
		|FROM
		|	InformationRegister.CompaniesTypesOfAccounting.SliceLast(&Period, Company = &Company) AS CompaniesTypesOfAccountingSliceLast
		|		LEFT JOIN Catalog.ChartsOfAccounts AS ChartsOfAccounts
		|		ON CompaniesTypesOfAccountingSliceLast.ChartOfAccounts = ChartsOfAccounts.Ref
		|WHERE
		|	NOT CompaniesTypesOfAccountingSliceLast.Inactive
		|	AND CompaniesTypesOfAccountingSliceLast.EntriesPostingOption = &EntriesPostingOption";
		
		Query.SetParameter("Period"					, Period);
		Query.SetParameter("Company"				, Company);
		Query.SetParameter("EntriesPostingOption"	, Enums.AccountingEntriesRegisterOptions.SourceDocuments);
		
	Else
		
		Query.Text =
		"SELECT
		|	&TypeOfAccounting AS TypeOfAccounting,
		|	ChartsOfAccounts.TypeOfEntries AS TypeOfEntries,
		|	ChartsOfAccounts.UseAnalyticalDimensions AS UseAnalyticalDimensions,
		|	ChartsOfAccounts.UseQuantity AS UseQuantity,
		|	ChartsOfAccounts.Ref AS ChartOfAccounts
		|INTO ChartsOfAccounts
		|FROM
		|	Catalog.ChartsOfAccounts AS ChartsOfAccounts
		|WHERE
		|	ChartsOfAccounts.Ref = &ChartOfAccounts
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ChartsOfAccounts.TypeOfAccounting AS TypeOfAccounting,
		|	ChartsOfAccounts.TypeOfEntries AS TypeOfEntries,
		|	ChartsOfAccounts.UseAnalyticalDimensions AS UseAnalyticalDimensions,
		|	ChartsOfAccounts.UseQuantity AS UseQuantity,
		|	ChartsOfAccounts.ChartOfAccounts AS ChartOfAccounts
		|FROM
		|	ChartsOfAccounts AS ChartsOfAccounts";
		
		Query.SetParameter("ChartOfAccounts", ChartOfAccounts);
		Query.SetParameter("TypeOfAccounting", TypeOfAccounting);
		
	EndIf;
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		
		TableParameters = New Structure;
		TableParameters.Insert("TypeOfAccounting"		, Selection.TypeOfAccounting);
		TableParameters.Insert("ChartOfAccounts"		, Selection.ChartOfAccounts);
		TableParameters.Insert("TypeOfEntries"			, Selection.TypeOfEntries);
		TableParameters.Insert("PagesGroupName"			, PagesGroupName);
		TableParameters.Insert("UseAnalyticalDimensions", Selection.UseAnalyticalDimensions);
		TableParameters.Insert("UseQuantity"			, Selection.UseQuantity);
		
		GenerateMasterTable(Form, TableParameters, True);
		
	EndDo;
	
EndProcedure

Procedure MasterTablesCommands(Form) Export
	
	Items = Form.Items;
	MasterTablesMap = Form.MasterTablesMap;
	
	For Each MasterTable In MasterTablesMap Do
		TamleItem = Items[MasterTable.TableName];
		
		CommandNameAdd		= MasterTable.TableName + "Add";
		CommandNameCopy		= MasterTable.TableName + "Copy";
		CommandNameDelete	= MasterTable.TableName + "Delete";
		GroupNameMove		= MasterTable.TableName + "Move";
		CommandNameMoveDown	= MasterTable.TableName + "MoveDown";
		CommandNameMoveUp	= MasterTable.TableName + "MoveUp";
		
		CommandBarItems = TamleItem.CommandBar.ChildItems;
		
		For Each CommandBarItem In CommandBarItems Do
			If CommandBarItem.Name = CommandNameAdd Then
				
				CommandBarItem.Representation		= ButtonRepresentation.PictureAndText;
				CommandBarItem.LocationInCommandBar = ButtonLocationInCommandBar.InCommandBarAndInAdditionalSubmenu;
				
			ElsIf CommandBarItem.Name = CommandNameCopy
				Or CommandBarItem.Name = CommandNameDelete Then
				
				CommandBarItem.Representation		= ButtonRepresentation.Picture;
				CommandBarItem.LocationInCommandBar = ButtonLocationInCommandBar.InCommandBarAndInAdditionalSubmenu;
				
			ElsIf CommandBarItem.Name = GroupNameMove Then
				
				MoveItems = CommandBarItem.ChildItems;
				
				For Each MoveItem In MoveItems Do
					If MoveItem.Name = CommandNameMoveDown Then
						MoveItem.Representation		= ButtonRepresentation.Picture;
						MoveItem.LocationInCommandBar = ButtonLocationInCommandBar.InCommandBarAndInAdditionalSubmenu;
					EndIf;
				EndDo;
				
			EndIf;
			
			If MasterTable.Compound Then
				
				For Each ButtonItem In Items[MasterTable.TableName + "CommandBar"].ChildItems Do
					
					If StrFind(ButtonItem.Name, "ExtraButton") = 0 Then
						ButtonItem.Visible = False;
					EndIf;
					
				EndDo;
				
				Items[MasterTable.TableName + "ContextMenuAdd"].Visible			= False;
				Items[MasterTable.TableName + "ContextMenuCopy"].Visible		= False;
				Items[MasterTable.TableName + "ContextMenuMoveUp"].Visible		= False;
				Items[MasterTable.TableName + "ContextMenuMoveDown"].Visible	= False;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure DeleteAttributes(Form) Export
	
	Items = Form.Items;
	
	AttributesArray = New Array;
	
	For Each Row In Form.MasterTablesMap Do
		AttributesArray.Add(Row.TableName);
		
		Form.Items.Delete(Items[Row.TableName]);
		Form.Items.Delete(Items[Row.PageName]);
	EndDo;
	
	Form.ChangeAttributes(, AttributesArray);
	
	Form.MasterTablesMap.Clear();
	
EndProcedure

#EndRegion

#Region Private

Procedure GenerateMasterTable(Form, TableParameters, ShouldAddButtons) Export
	
	Var TypeOfAccounting, ChartOfAccounts, TypeOfEntries, PagesGroupName, UseAnalyticalDimensions, UseQuantity;
	
	TypeOfAccounting		= TableParameters.TypeOfAccounting;
	ChartOfAccounts			= TableParameters.ChartOfAccounts;
	TypeOfEntries			= TableParameters.TypeOfEntries;
	PagesGroupName			= TableParameters.PagesGroupName;
	UseAnalyticalDimensions	= TableParameters.UseAnalyticalDimensions;
	UseQuantity				= TableParameters.UseQuantity;
	
	Items = Form.Items;
	
	If TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Compound Then
		CopyTable = GetCompoundTable()
	Else
		CopyTable = GetSimpleTable();
	EndIf;

	TypeOfAccountingUUID = New UUID;
	
	TypeOfAccountingUUIDString = StrReplace(String(TypeOfAccountingUUID), "-", "_");
	
	AttributesArray = New Array;
	
	TableName = "RecordSetMaster_" + TypeOfAccountingUUIDString; 
		
	NewTableAttribute = New FormAttribute(TableName, New TypeDescription("ValueTable"));
	NewTableAttribute.StoredData = True;
	
	AttributesArray.Add(NewTableAttribute);
	
	For Each Column In CopyTable.Columns Do
		
		AttributesArray.Add(New FormAttribute(Column.Name, Column.ValueType, TableName, Column.Title));
		
	EndDo;
	
	Form.ChangeAttributes(AttributesArray);
	
	PageName = "Page_" + TypeOfAccountingUUIDString;
	
	NewPage			= Items.Add(PageName, Type("FormGroup"), Items[PagesGroupName]);
	NewPage.Type	= FormGroupType.Page;
	NewPage.Title	= TypeOfAccounting.Description;
	
	NewTableItem			= Items.Add(TableName, Type("FormTable"), NewPage); 
	NewTableItem.DataPath	= TableName;
	
	NewTableItem.AutoInsertNewRow = False;
	
	NewTableItem.SetAction("Selection"			, "Attachable_RecordSetSelection");
	NewTableItem.SetAction("OnStartEdit"		, "Attachable_RecordSetOnStartEdit");
	NewTableItem.SetAction("OnEditEnd"			, "Attachable_RecordSetOnEditEnd");
	NewTableItem.SetAction("OnChange"			, "Attachable_RecordSetOnChange");
	NewTableItem.SetAction("BeforeDeleteRow"	, "Attachable_RecordSetBeforeDeleteRow");
	NewTableItem.SetAction("AfterDeleteRow"		, "Attachable_RecordSetAfterDeleteRow");
	
	If TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Compound Then
		
		NewTableItem.RowPictureDataPath	= TableName + ".RecordSetPicture";
		NewTableItem.RowsPicture		= PictureLib.DrCr;
		CreateCompoundColumnsItems(
			Form,
			CopyTable,
			TypeOfAccountingUUIDString,
			TableName,
			NewTableItem,
			UseAnalyticalDimensions,
			UseQuantity);
	Else
		
		NewTableItem.RowPictureDataPath	= TableName + ".Active";
		NewTableItem.RowsPicture		= PictureLib.ACRPlanningPeriod;
		CreateSimpleColumnsItems(
			Form,
			CopyTable,
			TypeOfAccountingUUIDString,
			TableName,
			NewTableItem,
			UseAnalyticalDimensions,
			UseQuantity);
	EndIf;
	
	If ShouldAddButtons Then
		AddCommandButtons(Form, TypeOfEntries, TableName, NewTableItem);
	EndIf;
	
	NewRow = Form.MasterTablesMap.Add();
	
	NewRow.TypeOfAccounting	= TypeOfAccounting;
	NewRow.ChartOfAccounts	= ChartOfAccounts;
	NewRow.TypeOfEntries	= TypeOfEntries;
	NewRow.TableName		= TableName;
	NewRow.PageName			= PageName;
	NewRow.Compound			= TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Compound;
	
EndProcedure

Function GetCompoundTable()
	
	CompoundTable = New ValueTable;
	MaxExtDimensions = WorkWithArbitraryParametersServerCall.MaxAnalyticalDimensionsNumber();

	CompoundTable.Columns.Add("ConnectionKey", 
		New TypeDescription("Number",,, New NumberQualifiers(10, 2)),
		NStr("en = '#'; ru = '#';pl = '#';es_ES = '#';es_CO = '#';tr = '#';it = '#';de = '#'"));
	CompoundTable.Columns.Add("LineNumber", 
		New TypeDescription("Number",,, New NumberQualifiers(10, 2)),
		NStr("en = '#'; ru = '#';pl = '#';es_ES = '#';es_CO = '#';tr = '#';it = '#';de = '#'"));
	CompoundTable.Columns.Add("NumberPresentation", 
		New TypeDescription("String"),
		NStr("en = 'Entry# / Line#'; ru = '??????????????????? / ???????????????';pl = 'Wpis nr / Wiersz nr';es_ES = 'Entrada de diario#/L??nea#';es_CO = 'Entrada de diario#/L??nea#';tr = 'Giri?? # / Sat??r #';it = 'Voce# / Riga#';de = 'Buchung Nr. / Zeile Nr. '"));
	CompoundTable.Columns.Add("EntryNumber", 
		New TypeDescription("Number",,, New NumberQualifiers(10, 2)),
		NStr("en = 'Entry#'; ru = '???????????????????';pl = 'Wpis nr';es_ES = 'Entrada de diario#';es_CO = 'Entrada de diario#';tr = 'Giri?? #';it = 'Voce#';de = 'Buchung Nr. '"));
	CompoundTable.Columns.Add("EntryLineNumber", 
		New TypeDescription("Number",,, New NumberQualifiers(10, 2)),
		NStr("en = 'Line#'; ru = '???????????????';pl = 'Wiersz nr';es_ES = 'L??nea#';es_CO = 'L??nea#';tr = 'Sat??r #';it = 'Riga#';de = 'Zeile Nr.'"));
	CompoundTable.Columns.Add("Recorder",
		Metadata.AccountingRegisters.AccountingJournalEntriesCompound.StandardAttributes.Recorder.Type,
		NStr("en = 'Recorder'; ru = '??????????????????????';pl = 'Rejestrator';es_ES = 'Registrador';es_CO = 'Registrador';tr = 'Kay??t';it = 'Documento di Rif.';de = 'Buchungsdokument'"));
	CompoundTable.Columns.Add("Active",
		New TypeDescription("Boolean"),
		NStr("en = 'Active'; ru = '??????????????';pl = 'Aktywny';es_ES = 'Activo';es_CO = 'Activo';tr = 'Aktif';it = 'Attivo';de = 'Aktiv'"));
	CompoundTable.Columns.Add("Period",
		New TypeDescription("Date",,,,, New DateQualifiers(DateFractions.DateTime)),
		NStr("en = 'Period'; ru = '????????????';pl = 'Okres';es_ES = 'Per??odo';es_CO = 'Per??odo';tr = 'D??nem';it = 'Periodo';de = 'Zeitraum'"));
	CompoundTable.Columns.Add("Company",
		New TypeDescription("CatalogRef.Companies"),
		NStr("en = 'Company'; ru = '??????????????????????';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = '???? yeri';it = 'Azienda';de = 'Firma'"));
	CompoundTable.Columns.Add("PlanningPeriod",
		New TypeDescription("CatalogRef.PlanningPeriods"),
		NStr("en = 'Planning period'; ru = '???????????? ????????????????????????';pl = 'Okres planowania';es_ES = 'Per??odo de planificaci??n';es_CO = 'Per??odo de planificaci??n';tr = 'Planlama d??nemi';it = 'Periodo di pianificazione';de = 'Planungszeitraum'"));
	
	TypeArray = New Array;
	TypeArray.Add(Type("CatalogRef.Currencies"));
	TypeArray.Add(Type("Null"));
	
	CompoundTable.Columns.Add("Currency",
		New TypeDescription(TypeArray));
	CompoundTable.Columns.Add("CurrencyDr",
		New TypeDescription(TypeArray),
		NStr("en = 'Transaction currency Dr'; ru = '???????????? ???????????????? ????';pl = 'Waluta transakcji Wn';es_ES = 'Moneda de transacci??n Dr';es_CO = 'Moneda de transacci??n Dr';tr = '????lem para birimi Bor??';it = 'Valuta della transazione deb';de = 'Transaktionsw??hrung Soll'"));
	CompoundTable.Columns.Add("CurrencyCr",
		New TypeDescription(TypeArray),
		NStr("en = 'Transaction currency Cr'; ru = '???????????? ???????????????? ????';pl = 'Transaction currency Ma';es_ES = 'Moneda de transacci??n Cr';es_CO = 'Moneda de transacci??n Cr';tr = '????lem para birimi Alacak';it = 'Valuta della transazione cred';de = 'Transaktionsw??hrung Haben'"));
	CompoundTable.Columns.Add("Status",
		New TypeDescription("EnumRef.AccountingEntriesStatus"), 
		NStr("en = 'Status'; ru = '????????????';pl = 'Status';es_ES = 'Estado';es_CO = 'Estado';tr = 'Durum';it = 'Stato';de = 'Status'"));
	CompoundTable.Columns.Add("TypeOfAccounting",
		New TypeDescription("CatalogRef.TypesOfAccounting"),
		NStr("en = 'Type of accounting'; ru = '?????? ???????????????????????????? ??????????';pl = 'Typ rachunkowo??ci';es_ES = 'Tipo de contabilidad';es_CO = 'Tipo de contabilidad';tr = 'Muhasebe t??r??';it = 'Tipo di contabilit??';de = 'Typ der Buchhaltung'"));
	CompoundTable.Columns.Add("Account",
		New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"),
		NStr("en = 'Account'; ru = '????????';pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Conto';de = 'Konto'"));
		
	ExtDimensionTypeDesctiption = Metadata.ChartsOfCharacteristicTypes.ManagerialAnalyticalDimensionTypes.Type;
	
	For Index = 1 To MaxExtDimensions Do
		
		CompoundTable.Columns.Add(MasterAccountingClientServer.GetExtDimensionFieldName(Index),
			ExtDimensionTypeDesctiption,
			MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index));
			
		CompoundTable.Columns.Add(MasterAccountingClientServer.GetExtDimensionFieldName(Index, , "Type"),
			New TypeDescription("ChartOfCharacteristicTypesRef.ManagerialAnalyticalDimensionTypes"));
			
		CompoundTable.Columns.Add(MasterAccountingClientServer.GetExtDimensionFieldName(Index, , "Enabled"),
			New TypeDescription("Boolean"));
			
		CompoundTable.Columns.Add(MasterAccountingClientServer.GetExtDimensionFieldName(Index, , "Presentation"),
			New TypeDescription("String"));
			
	EndDo;
		
	CompoundTable.Columns.Add("UseQuantity",
		New TypeDescription("Boolean"));
	CompoundTable.Columns.Add("UseCurrency",
		New TypeDescription("Boolean"));
		
	CompoundTable.Columns.Add("RecordType",
		New TypeDescription("AccountingRecordType"),
		NStr("en = 'Debit / Credit'; ru = '?????????? / ????????????';pl = 'Zobowi??zania / Nale??no??ci';es_ES = 'D??bito / Cr??dito';es_CO = 'D??bito / Cr??dito';tr = 'Bor?? / Alacak';it = 'Debito credito';de = 'Soll / Haben'"));
	
	TypeArray = New Array;
	TypeArray.Add(Type("Number"));
	TypeArray.Add(Type("Null"));
	
	CompoundTable.Columns.Add("Content",
		New TypeDescription("String"),
		NStr("en = 'Entry description'; ru = '???????????????????? ????????????????';pl = 'Opis wpisu';es_ES = 'Descripci??n de la entrada de diario';es_CO = 'Descripci??n de la entrada de diario';tr = 'Giri?? a????klamas??';it = 'Descrizione voce';de = 'Buchungsbeschreibung'"));
	CompoundTable.Columns.Add("OfflineRecord",
		New TypeDescription("Boolean",,, New NumberQualifiers(10)), 
		NStr("en = 'Offline record'; ru = '???????????? ????????????';pl = 'Zapis offline';es_ES = 'Registro fuera de l??nea';es_CO = 'Registro fuera de l??nea';tr = '??evrimd?????? kay??t';it = 'Registrazione offline';de = 'Offline-Buchung'"));
	CompoundTable.Columns.Add("TransactionTemplate",
		New TypeDescription("CatalogRef.AccountingTransactionsTemplates"),
		NStr("en = 'description'; ru = '????????????????????????';pl = 'opis';es_ES = 'descripci??n';es_CO = 'descripci??n';tr = 'tan??m';it = 'descrizione';de = 'Beschreibung'"));
	CompoundTable.Columns.Add("TransactionTemplateCode",
		New TypeDescription("String"),
		NStr("en = 'Transaction template code'; ru = '?????? ?????????????? ????????????????';pl = 'Kod szablonu transakcji';es_ES = 'C??digo de plantilla de transacci??n';es_CO = 'C??digo de plantilla de transacci??n';tr = '????lem ??ablon kodu';it = 'Codice modello transazione';de = 'Code der Transaktionsvorlage'"));
	CompoundTable.Columns.Add("TransactionTemplateLineNumber",
		New TypeDescription("Number",,, New NumberQualifiers(10)),
		NStr("en = 'line #'; ru = '??? ????????????';pl = 'Wiersz nr';es_ES = 'l??nea #';es_CO = 'l??nea #';tr = 'sat??r #';it = 'riga #';de = 'Zeile Nr.'"));
	CompoundTable.Columns.Add("RecordSetPicture",
		New TypeDescription("Number",,, New NumberQualifiers(10)));
		
	CompoundTable.Columns.Add("Amount", 
		New TypeDescription("Number",,, New NumberQualifiers(15, 2)));
	CompoundTable.Columns.Add("AmountDr", 
		New TypeDescription("Number",,, New NumberQualifiers(15, 2)),
		NStr("en = 'Amount Dr'; ru = '?????????? ????';pl = 'Warto???? Wn';es_ES = 'Importe Dr';es_CO = 'Importe Dr';tr = 'Tutar Bor??';it = 'Importo Deb';de = 'Betrag Soll'"));
	CompoundTable.Columns.Add("AmountCr", 
		New TypeDescription("Number",,, New NumberQualifiers(15, 2)),
		NStr("en = 'Amount Cr'; ru = '?????????? ????';pl = 'Warto???? Ma';es_ES = 'Importe Cr';es_CO = 'Importe Cr';tr = 'Tutar Alacak';it = 'Importo Cred';de = 'Betrag Haben'"));

	CompoundTable.Columns.Add("AmountCur",
		New TypeDescription("Number",,, New NumberQualifiers(15, 2)));
	CompoundTable.Columns.Add("AmountCurDr",
		New TypeDescription("Number",,, New NumberQualifiers(15, 2)),
		NStr("en = 'Amount Dr (Transaction currency)'; ru = '?????????? ???? (???????????? ????????????????)';pl = 'Warto???? Wn (Waluta transakcji)';es_ES = 'Importe D??bito (moneda de transacci??n)';es_CO = 'Importe D??bito (moneda de transacci??n)';tr = 'Tutar Bor?? (????lem para birimi)';it = 'Importo Deb (Valuta transazione)';de = 'Betrag Soll (Transaktionsw??hrung)'"));
	CompoundTable.Columns.Add("AmountCurCr",
		New TypeDescription("Number",,, New NumberQualifiers(15, 2)),
		NStr("en = 'Amount Cr (Transaction currency)'; ru = '?????????? ???? (???????????? ????????????????)';pl = 'Warto???? Ma (Waluta transakcji)';es_ES = 'Importe Cr??dito (moneda de transacci??n)';es_CO = 'Importe Cr??dito (moneda de transacci??n)';tr = 'Tutar Alacak (????lem para birimi)';it = 'Importo cred (Valuta transazione )';de = 'Betrag Haben (Transaktionsw??hrung)'"));
		
	CompoundTable.Columns.Add("Quantity", 
		New TypeDescription(TypeArray,,, New NumberQualifiers(15, 3)));
	CompoundTable.Columns.Add("QuantityDr", 
		New TypeDescription(TypeArray,,, New NumberQualifiers(15, 3)),
		NStr("en = 'Quantity Dr'; ru = '???????????????????? ????';pl = 'Ilo???? Wn';es_ES = 'Cantidad Dr';es_CO = 'Cantidad Dr';tr = 'Miktar Bor??';it = 'Quantit?? Deb';de = 'Menge Soll'"));
	CompoundTable.Columns.Add("QuantityCr", 
		New TypeDescription(TypeArray,,, New NumberQualifiers(15, 3)),
		NStr("en = 'Quantity Cr'; ru = '???????????????????? ????';pl = 'Ilo???? Ma';es_ES = 'Cantidad cr??dito';es_CO = 'Cantidad cr??dito';tr = 'Miktar Alacak';it = 'Quantit?? Cred';de = 'Menge Haben'"));
	
	Return CompoundTable;
	
EndFunction

Function GetSimpleTable()
	
	SimpleTable = New ValueTable;
	MaxExtDimensions = WorkWithArbitraryParametersServerCall.MaxAnalyticalDimensionsNumber();
	
	SimpleTable.Columns.Add("ConnectionKey", 
		New TypeDescription("Number",,, New NumberQualifiers(10, 2)),
		NStr("en = '#'; ru = '#';pl = '#';es_ES = '#';es_CO = '#';tr = '#';it = '#';de = '#'"));
	SimpleTable.Columns.Add("LineNumber",
		New TypeDescription("Number",,, New NumberQualifiers(10)),
		NStr("en = '#'; ru = '#';pl = '#';es_ES = '#';es_CO = '#';tr = '#';it = '#';de = '#'"));
	SimpleTable.Columns.Add("EntryNumber",
		New TypeDescription("String"));
	SimpleTable.Columns.Add("Recorder",
		Metadata.AccountingRegisters.AccountingJournalEntriesSimple.StandardAttributes.Recorder.Type,
		NStr("en = 'Recorder'; ru = '??????????????????????';pl = 'Rejestrator';es_ES = 'Registrador';es_CO = 'Registrador';tr = 'Recorder';it = 'Documento di Rif.';de = 'Buchungsdokument'"));
	SimpleTable.Columns.Add("Active",
		New TypeDescription("Boolean"),
		NStr("en = 'Active'; ru = '??????????????';pl = 'Aktywny';es_ES = 'Activo';es_CO = 'Activo';tr = 'Aktif';it = 'Attivo';de = 'Aktiv'"));
	SimpleTable.Columns.Add("Period",
		New TypeDescription("Date",,,,, New DateQualifiers(DateFractions.DateTime)),
		NStr("en = 'Period'; ru = '????????????';pl = 'Okres';es_ES = 'Per??odo';es_CO = 'Per??odo';tr = 'D??nem';it = 'Periodo';de = 'Zeitraum'"));
	SimpleTable.Columns.Add("Company",
		New TypeDescription("CatalogRef.Companies"),
		NStr("en = 'Company'; ru = '??????????????????????';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = '???? yeri';it = 'Azienda';de = 'Firma'"));
	SimpleTable.Columns.Add("PlanningPeriod",
		New TypeDescription("CatalogRef.PlanningPeriods"),
		NStr("en = 'Planning period'; ru = '???????????? ????????????????????????';pl = 'Okres planowania';es_ES = 'Per??odo de planificaci??n';es_CO = 'Per??odo de planificaci??n';tr = 'Planlama d??nemi';it = 'Periodo di pianificazione';de = 'Planungszeitraum'"));
	
	TypeArray = New Array;
	TypeArray.Add(Type("CatalogRef.Currencies"));
	TypeArray.Add(Type("Null"));

	SimpleTable.Columns.Add("CurrencyDr",
		New TypeDescription(TypeArray),
		NStr("en = 'Transaction currency Dr'; ru = '???????????? ???????????????? ????';pl = 'Waluta transakcji Wn';es_ES = 'Moneda de transacci??n Dr';es_CO = 'Moneda de transacci??n Dr';tr = '????lem para birimi Bor??';it = 'Valuta della transazione deb';de = 'Transaktionsw??hrung Soll'"));
	SimpleTable.Columns.Add("CurrencyCr",
		New TypeDescription(TypeArray),
		NStr("en = 'Transaction currency Cr'; ru = '???????????? ???????????????? ????';pl = 'Transaction currency Ma';es_ES = 'Moneda de transacci??n Cr';es_CO = 'Moneda de transacci??n Cr';tr = '????lem para birimi Alacak';it = 'Valuta della transazione cred';de = 'Transaktionsw??hrung Haben'"));
		
	SimpleTable.Columns.Add("Status",
		New TypeDescription("EnumRef.AccountingEntriesStatus"), 
		NStr("en = 'Status'; ru = '????????????';pl = 'Status';es_ES = 'Estado';es_CO = 'Estado';tr = 'Durum';it = 'Stato';de = 'Status'"));
	SimpleTable.Columns.Add("TypeOfAccounting",
		New TypeDescription("CatalogRef.TypesOfAccounting"),
		NStr("en = 'Type of accounting'; ru = '?????? ???????????????????????????? ??????????';pl = 'Typ rachunkowo??ci';es_ES = 'Tipo de contabilidad';es_CO = 'Tipo de contabilidad';tr = 'Muhasebe t??r??';it = 'Tipo di contabilit??';de = 'Typ der Buchhaltung'"));
	SimpleTable.Columns.Add("AccountDr",
		New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"),
		NStr("en = 'Account Dr'; ru = '???????? ????';pl = 'Konto Wn';es_ES = 'Cuenta Dr';es_CO = 'Cuenta Dr';tr = 'Alacak hesab??';it = 'Conto deb';de = 'Konto Soll'"));
	SimpleTable.Columns.Add("AccountCr",
		New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"),
		NStr("en = 'Account Cr'; ru = '???????? ????';pl = 'Konto Ma';es_ES = 'Cuenta Cr';es_CO = 'Cuenta Cr';tr = 'Bor?? hesab??';it = 'Conto Cred';de = 'Konto Haben'"));
		
	ExtDimensionTypeDesctiption = Metadata.ChartsOfCharacteristicTypes.ManagerialAnalyticalDimensionTypes.Type;
	
	For Index = 1 To MaxExtDimensions Do
		
		SimpleTable.Columns.Add(MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr"),
			ExtDimensionTypeDesctiption, 
			MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index, "Dr"));
			
		SimpleTable.Columns.Add(MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr"),
			ExtDimensionTypeDesctiption, 
			MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index, "Cr"));
			
		SimpleTable.Columns.Add(MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Type"),
			New TypeDescription("ChartOfCharacteristicTypesRef.ManagerialAnalyticalDimensionTypes"));
			
		SimpleTable.Columns.Add(MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Type"),
			New TypeDescription("ChartOfCharacteristicTypesRef.ManagerialAnalyticalDimensionTypes"));
			
		SimpleTable.Columns.Add(MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Enabled"),
			New TypeDescription("Boolean"));
			
		SimpleTable.Columns.Add(MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Enabled"),
			New TypeDescription("Boolean"));
			
		SimpleTable.Columns.Add(MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Presentation"),
			New TypeDescription("String"));
			
		SimpleTable.Columns.Add(MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Presentation"),
			New TypeDescription("String"));
		
	EndDo;
	
	SimpleTable.Columns.Add("UseQuantityDr",
		New TypeDescription("Boolean"));
		
	SimpleTable.Columns.Add("UseCurrencyDr",
		New TypeDescription("Boolean"));
		
	SimpleTable.Columns.Add("UseQuantityCr",
		New TypeDescription("Boolean"));
		
	SimpleTable.Columns.Add("UseCurrencyCr",
		New TypeDescription("Boolean"));
		
	SimpleTable.Columns.Add("RecordType",
		New TypeDescription("AccountingRecordType"),
		NStr("en = 'Record type'; ru = '?????? ????????????';pl = 'Rodzaj wpisu';es_ES = 'Tipo de registro';es_CO = 'Tipo de registro';tr = 'Kay??t t??r??';it = 'Tipo di registrazione';de = 'Satztyp'"));
	SimpleTable.Columns.Add("Amount",
		New TypeDescription("Number",,, New NumberQualifiers(15,2)),
		NStr("en = 'Amount'; ru = '??????????';pl = 'Warto????';es_ES = 'Importe';es_CO = 'Importe';tr = 'Tutar';it = 'Importo';de = 'Betrag'"));
	
	TypeArray = New Array;
	TypeArray.Add(Type("Number"));
	TypeArray.Add(Type("Null"));
	
	SimpleTable.Columns.Add("AmountCur",
		New TypeDescription(TypeArray,,, New NumberQualifiers(10)),
		NStr("en = 'Amount cur'; ru = '?????????? ??????';pl = 'Warto???? wal';es_ES = 'Importe actual';es_CO = 'Importe actual';tr = 'Tutar para birimi';it = 'Importo cor';de = 'Betrag W??hrung'"));
	SimpleTable.Columns.Add("Content",
		New TypeDescription("String"),
		NStr("en = 'Entry description'; ru = '???????????????????? ????????????????';pl = 'Opis wpisu';es_ES = 'Descripci??n de la entrada de diario';es_CO = 'Descripci??n de la entrada de diario';tr = 'Giri?? a????klamas??';it = 'Descrizione voce';de = 'Buchungsbeschreibung'"));
	SimpleTable.Columns.Add("OfflineRecord",
		New TypeDescription("Boolean",,, New NumberQualifiers(10)),
		NStr("en = 'Offline record'; ru = '???????????? ????????????';pl = 'Zapis offline';es_ES = 'Registro fuera de l??nea';es_CO = 'Registro fuera de l??nea';tr = '??evrimd?????? kay??t';it = 'Registrazione offline';de = 'Offline-Buchung'"));
	SimpleTable.Columns.Add("TransactionTemplate",
		New TypeDescription("CatalogRef.AccountingTransactionsTemplates"),
		NStr("en = 'description'; ru = '????????????????????????';pl = 'opis';es_ES = 'descripci??n';es_CO = 'descripci??n';tr = 'tan??m';it = 'descrizione';de = 'Beschreibung'"));
	SimpleTable.Columns.Add("TransactionTemplateCode",
		New TypeDescription("String"),
		NStr("en = 'Transaction template code'; ru = '?????? ?????????????? ????????????????';pl = 'Kod szablonu transakcji';es_ES = 'C??digo de plantilla de transacci??n';es_CO = 'C??digo de plantilla de transacci??n';tr = '????lem ??ablon kodu';it = 'Codice modello transazione';de = 'Code der Transaktionsvorlage'"));
	SimpleTable.Columns.Add("TransactionTemplateLineNumber",
		New TypeDescription("Number",,, New NumberQualifiers(10)),
		NStr("en = 'line #'; ru = '??? ????????????';pl = 'Wiersz nr';es_ES = 'l??nea #';es_CO = 'l??nea #';tr = 'sat??r #';it = 'riga #';de = 'Zeile Nr.'"));
	SimpleTable.Columns.Add("RecordSetPicture",
		New TypeDescription("Number",,, New NumberQualifiers(10)));
	SimpleTable.Columns.Add("AmountCr",
		New TypeDescription("Number",,, New NumberQualifiers(15, 2)),
		NStr("en = 'Amount Cr'; ru = '?????????? ????';pl = 'Warto???? Ma';es_ES = 'Importe Cr??dito';es_CO = 'Importe Cr??dito';tr = 'Tutar Alacak';it = 'Importo Cred';de = 'Betrag Haben'"));
	SimpleTable.Columns.Add("AmountDr",
		New TypeDescription("Number",,, New NumberQualifiers(15, 2)),
		NStr("en = 'Amount Dr'; ru = '?????????? ????';pl = 'Warto???? Wn';es_ES = 'Importe D??bito';es_CO = 'Importe D??bito';tr = 'Tutar Bor??';it = 'Importo Deb';de = 'Betrag Soll'"));
	SimpleTable.Columns.Add("AmountCurCr",
		New TypeDescription("Number",,, New NumberQualifiers(15, 2)),
		NStr("en = 'Amount Cr (Transaction currency)'; ru = '?????????? ???? (??????. ????????????????)';pl = 'Warto???? Ma (Waluta transakcji)';es_ES = 'Importe Cr??dito (moneda de transacci??n)';es_CO = 'Importe Cr??dito (moneda de transacci??n)';tr = 'Tutar Alacak (????lem para birimi)';it = 'Importo cred (Valuta transazione )';de = 'Betrag Haben (Transaktionsw??hrung)'"));
	SimpleTable.Columns.Add("AmountCurDr",
		New TypeDescription("Number",,, New NumberQualifiers(15, 2)),
		NStr("en = 'Amount Dr (Transaction currency)'; ru = '?????????? ???? (??????. ????????????????)';pl = 'Warto???? Wn (Waluta transakcji)';es_ES = 'Importe D??bito (moneda de transacci??n)';es_CO = 'Importe D??bito (moneda de transacci??n)';tr = 'Tutar Bor?? (????lem para birimi)';it = 'Importo Deb (Valuta transazione)';de = 'Betrag Soll (Transaktionsw??hrung)'"));
	SimpleTable.Columns.Add("QuantityCr",
		New TypeDescription(TypeArray,,, New NumberQualifiers(15, 3)),
		NStr("en = 'Quantity Cr'; ru = '???????????????????? ????';pl = 'Ilo???? Ma';es_ES = 'Cantidad cr??dito';es_CO = 'Cantidad cr??dito';tr = 'Miktar Alacak';it = 'Quantit?? Cred';de = 'Menge Haben'"));
	SimpleTable.Columns.Add("QuantityDr",
		New TypeDescription(TypeArray,,, New NumberQualifiers(15, 3)),
		NStr("en = 'Quantity Dr'; ru = '???????????????????? ????';pl = 'Ilo???? Wn';es_ES = 'Cantidad D??bito';es_CO = 'Cantidad D??bito';tr = 'Miktar Bor??';it = 'Quantit?? Deb';de = 'Menge Soll'"));

	Return SimpleTable;

EndFunction

Procedure CreateCompoundColumnsItems(Form, CopyTable, TypeOfAccountingUUIDString, TableName, NewTableItem, UseAnalyticalDimensions, UseQuantity)
	
	MaxExtDimensions = WorkWithArbitraryParametersServerCall.MaxAnalyticalDimensionsNumber();
	
	CommonData = New Structure;
	CommonData.Insert("Form"		, Form);
	CommonData.Insert("CopyTable"	, CopyTable);
	CommonData.Insert("TableName"	, TableName);
	
	ColumnGroupPeriodLineNumber = CreateColumnGroup(
		Form,
		"GroupPeriodLineNumber_",
		TypeOfAccountingUUIDString,
		NewTableItem);
	CreateColumnItem(CommonData, "Period", ColumnGroupPeriodLineNumber);
	
	ColumnGroupLineNumber = CreateColumnGroup(
		Form,
		"GroupLineNumber_",
		TypeOfAccountingUUIDString,
		ColumnGroupPeriodLineNumber,
		ColumnsGroup.InCell);
	
	NewItem = CreateColumnItem(CommonData, "NumberPresentation", ColumnGroupLineNumber, True);
	NewItem.HorizontalAlign = ItemHorizontalLocation.Right;
	CreateColumnItem(CommonData, "LineNumber", ColumnGroupLineNumber, True, False);
	
	ColumnGroup = CreateColumnGroup(
		Form,
		"GroupCompanyPlanningPeriod_",
		TypeOfAccountingUUIDString,
		NewTableItem);
	
	ColumnGroup.Visible = False;

	CreateColumnItem(CommonData, "Company", ColumnGroup, True);
	CreateColumnItem(CommonData, "PlanningPeriod", ColumnGroup, True);
	
	ColumnGroup = CreateColumnGroup(
		Form,
		"GroupAccountRecordType_",
		TypeOfAccountingUUIDString,
		NewTableItem);
	
	NewItem = CreateColumnItem(CommonData, "RecordType", ColumnGroup);
	NewItem.SetAction("OnChange", "Attachable_RecordSetRecordTypeOnChange");
	NewItem = CreateAccountColumnItem(CommonData, "Account", ColumnGroup);
	NewItem.SetAction("OnChange", "Attachable_RecordSetMasterAccountOnChange");
	
	ColumnGroupExtDimensions = CreateColumnGroup(
		Form,
		"GroupExtDimensions_",
		TypeOfAccountingUUIDString,
		NewTableItem,
		,
		UseAnalyticalDimensions);
	ColumnGroupType = CreateColumnGroup(
		Form,
		"GroupExtDimensionsType_",
		TypeOfAccountingUUIDString,
		NewTableItem,
		,
		False);
	ColumnGroupEnabled = CreateColumnGroup(
		Form,
		"GroupExtDimensionsEnabled_",
		TypeOfAccountingUUIDString,
		NewTableItem,
		,
		False);
	ColumnGroupPresentation = CreateColumnGroup(
		Form,
		"GroupExtDimensionsPresentation_",
		TypeOfAccountingUUIDString,
		NewTableItem,
		,
		False);
	
	For Index = 1 To MaxExtDimensions Do
		
		NewItem = CreateExtDimensionColumnItem(CommonData, ColumnGroupExtDimensions, Index);
		NewItem.SetAction("StartChoice", "Attachable_RecordSetMasterExtDimensionStartChoice");
		
		FieldNameType			= MasterAccountingClientServer.GetExtDimensionFieldName(Index, , "Type");
		FieldNameEnabled		= MasterAccountingClientServer.GetExtDimensionFieldName(Index, , "Enabled");
		FieldNamePresentation	= MasterAccountingClientServer.GetExtDimensionFieldName(Index, , "Presentation");
		
		CreateColumnItem(CommonData, FieldNameType, ColumnGroupType);
		
		CreateColumnItem(CommonData, FieldNameEnabled, ColumnGroupEnabled);
		
		CreateColumnItem(CommonData, FieldNamePresentation, ColumnGroupPresentation);
		
	EndDo;
	
	ColumnGroupDrCr = CreateColumnGroup(
		Form,
		"AccountingRecordsGroupDrCr_",
		TypeOfAccountingUUIDString,
		NewTableItem,
		ColumnsGroup.Horizontal);
	
	ColumnGroupDr = CreateColumnGroup(
		Form,
		"AccountingRecordsGroupDr_",
		TypeOfAccountingUUIDString,
		ColumnGroupDrCr);
	
	NewItem = CreateColumnItem(CommonData, "CurrencyDr", ColumnGroupDr);
	NewItem = CreateColumnItem(CommonData, "AmountCurDr", ColumnGroupDr);
	NewItem = CreateColumnItem(CommonData, "QuantityDr", ColumnGroupDr, , UseQuantity);
	
	ColumnGroupCr = CreateColumnGroup(
		Form,
		"AccountingRecordsGroupCr_",
		TypeOfAccountingUUIDString,
		ColumnGroupDrCr);
	
	NewItem = CreateColumnItem(CommonData, "CurrencyCr", ColumnGroupCr);
	NewItem = CreateColumnItem(CommonData, "AmountCurCr", ColumnGroupCr);
	NewItem = CreateColumnItem(CommonData, "QuantityCr", ColumnGroupCr, , UseQuantity);
	
	NewItem = CreateColumnItem(CommonData, "AmountDr", NewTableItem);
	NewItem.SetAction("OnChange", "Attachable_RecordSetAmountDrOnChange");
	
	NewItem = CreateColumnItem(CommonData, "AmountCr", NewTableItem);
	NewItem.SetAction("OnChange", "Attachable_RecordSetAmountCrOnChange");
	
	CreateColumnItem(CommonData, "Content", NewTableItem);
	
	ColumnGroup = CreateColumnGroup(
		Form,
		"RecordSetGroupTemplate_",
		TypeOfAccountingUUIDString,
		NewTableItem,
		ColumnsGroup.InCell);
	
	CreateColumnItem(CommonData, "TransactionTemplateCode", ColumnGroup, , , "TransactionTemplate.Code");
	CreateColumnItem(CommonData, "TransactionTemplate", ColumnGroup);
	CreateColumnItem(CommonData, "TransactionTemplateLineNumber", ColumnGroup);
	
	CreateColumnItem(CommonData, "UseCurrency", NewTableItem, , False);
	CreateColumnItem(CommonData, "UseQuantity", NewTableItem, , False);
	
	For Index = 1 To MaxExtDimensions Do
		SetupExtDimensionConditionalAppearance(Form, TableName, Index);
	EndDo;
	
	SetupMiscFieldsConditionalAppearance(Form, TableName, "Dr", True);
	SetupMiscFieldsConditionalAppearance(Form, TableName, "Cr", True);
	
EndProcedure

Procedure CreateSimpleColumnsItems(Form, CopyTable, TypeOfAccountingUUIDString, TableName, NewTableItem, UseAnalyticalDimensions, UseQuantity)
	
	MaxExtDimensions = WorkWithArbitraryParametersServerCall.MaxAnalyticalDimensionsNumber();
	
	CommonData = New Structure;
	CommonData.Insert("Form"		, Form);
	CommonData.Insert("CopyTable"	, CopyTable);
	CommonData.Insert("TableName"	, TableName);
	GroupPeriodLineNumber = CreateColumnGroup(Form, "GroupPeriodLineNumber_", TypeOfAccountingUUIDString, NewTableItem);
	
	CreateColumnItem(CommonData, "Period", GroupPeriodLineNumber);
	
	GroupLineNumber = CreateColumnGroup(Form, "GroupLineNumber_", TypeOfAccountingUUIDString, GroupPeriodLineNumber, ColumnsGroup.InCell);
	CreateColumnItem(CommonData, "LineNumber", GroupLineNumber, True);
	CreateColumnItem(CommonData, "EntryNumber", GroupLineNumber, True, False);
	
	ColumnGroup = CreateColumnGroup(Form, "GroupCompanyPlanningPeriod_", TypeOfAccountingUUIDString, NewTableItem);
	
	CreateColumnItem(CommonData, "Company", ColumnGroup, , False);
	CreateColumnItem(CommonData, "PlanningPeriod", ColumnGroup, , False);
	
	NewItem = CreateAccountColumnItem(CommonData, "AccountDr", NewTableItem);
	NewItem.SetAction("OnChange", "Attachable_RecordSetMasterAccountDrOnChange");
	
	ColumnGroupExtDimensionsDr = CreateColumnGroup(Form, "GroupExtDimensionsDr_", TypeOfAccountingUUIDString, NewTableItem, , UseAnalyticalDimensions);
	ColumnGroupTypeDr = CreateColumnGroup(Form, "GroupExtDimensionsTypeDr_", TypeOfAccountingUUIDString, NewTableItem, , False);
	ColumnGroupEnabledDr = CreateColumnGroup(Form, "GroupExtDimensionsEnabledDr_", TypeOfAccountingUUIDString, NewTableItem, , False);
	ColumnGroupPresentationDr = CreateColumnGroup(Form, "GroupExtDimensionsPresentationDr_", TypeOfAccountingUUIDString, NewTableItem, , False);
	
	For Index = 1 To MaxExtDimensions Do
		
		NewItem = CreateExtDimensionColumnItem(CommonData, ColumnGroupExtDimensionsDr, Index, "Dr");
		NewItem.SetAction("StartChoice", "Attachable_RecordSetMasterSimpleExtDimensionStartChoice");
		
		CreateColumnItem(CommonData, MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Type"), ColumnGroupTypeDr);
		
		CreateColumnItem(CommonData, MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Enabled"), ColumnGroupEnabledDr);
		
		CreateColumnItem(CommonData, MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Presentation"), ColumnGroupPresentationDr);
		
	EndDo;
	
	ColumnGroup = CreateColumnGroup(Form, "RecordSetGroupCurrencyDr_", TypeOfAccountingUUIDString, NewTableItem);
	
	CreateColumnItem(CommonData, "CurrencyDr", ColumnGroup);
	CreateColumnItem(CommonData, "AmountCurDr", ColumnGroup);
	CreateColumnItem(CommonData, "QuantityDr", ColumnGroup, , UseQuantity);
	
	CreateColumnItem(CommonData, "UseCurrencyDr", NewTableItem, , False);
	CreateColumnItem(CommonData, "UseQuantityDr", NewTableItem, , False);
	
	NewItem = CreateAccountColumnItem(CommonData, "AccountCr", NewTableItem);
	NewItem.SetAction("OnChange", "Attachable_RecordSetMasterAccountCrOnChange");
	
	ColumnGroupExtDimensionsCr = CreateColumnGroup(Form, "GroupExtDimensionsCr_", TypeOfAccountingUUIDString, NewTableItem, , UseAnalyticalDimensions);
	ColumnGroupTypeCr = CreateColumnGroup(Form, "GroupExtDimensionsTypeCr_", TypeOfAccountingUUIDString, NewTableItem, , False);
	ColumnGroupEnabledCr = CreateColumnGroup(Form, "GroupExtDimensionsEnabledCr_", TypeOfAccountingUUIDString, NewTableItem, , False);
	ColumnGroupPresentationCr = CreateColumnGroup(Form, "GroupExtDimensionsPresentationCr_", TypeOfAccountingUUIDString, NewTableItem, , False);
	
	For Index = 1 To MaxExtDimensions Do
		
		NewItem = CreateExtDimensionColumnItem(CommonData, ColumnGroupExtDimensionsCr, Index, "Cr");
		NewItem.SetAction("StartChoice", "Attachable_RecordSetMasterSimpleExtDimensionStartChoice");
		
		CreateColumnItem(CommonData, MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Type"), ColumnGroupTypeCr);
			
		CreateColumnItem(CommonData, MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Enabled"), ColumnGroupEnabledCr);
			
		CreateColumnItem(CommonData, MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Presentation"), ColumnGroupPresentationCr);
			
	EndDo;
	
	ColumnGroup = CreateColumnGroup(Form, "RecordSetGroupCurrencyCr_", TypeOfAccountingUUIDString, NewTableItem);
	
	CreateColumnItem(CommonData, "CurrencyCr", ColumnGroup);
	NewItem = CreateColumnItem(CommonData, "AmountCurCr", ColumnGroup);
	CreateColumnItem(CommonData, "QuantityCr", ColumnGroup, , UseQuantity);
	
	CreateColumnItem(CommonData, "UseCurrencyCr", NewTableItem, , False);
	CreateColumnItem(CommonData, "UseQuantityCr", NewTableItem, , False);
	
	NewItem = CreateColumnItem(CommonData, "Amount", NewTableItem);
	NewItem.SetAction("OnChange", "Attachable_RecordSetAmountOnChange");
	CreateColumnItem(CommonData, "Content", NewTableItem);
	
	ColumnGroup = CreateColumnGroup(Form, "RecordSetGroupTemplate_", TypeOfAccountingUUIDString, NewTableItem, ColumnsGroup.InCell); 
	
	CreateColumnItem(CommonData, "TransactionTemplateCode", ColumnGroup, , , "TransactionTemplate.Code");
	CreateColumnItem(CommonData, "TransactionTemplate", ColumnGroup);
	CreateColumnItem(CommonData, "TransactionTemplateLineNumber", ColumnGroup);
	
	For Index = 1 To MaxExtDimensions Do
		SetupExtDimensionConditionalAppearance(Form, TableName, Index, "Dr");
		SetupExtDimensionConditionalAppearance(Form, TableName, Index, "Cr");
	EndDo;
	
	SetupMiscFieldsConditionalAppearance(Form, TableName, "Dr");
	SetupMiscFieldsConditionalAppearance(Form, TableName, "Cr");
	
EndProcedure

Function CreateColumnGroup(Form, GroupName, TypeOfAccountingUUIDString, Parent, Group = Undefined, Visible = True)
	
	Items = Form.Items;
	
	ColumnGroup = Items.Add(GroupName + TypeOfAccountingUUIDString, 
		Type("FormGroup"), 
		Parent);
		
	ColumnGroup.Type 	= FormGroupType.ColumnGroup;
	ColumnGroup.Visible = Visible;
	
	If Group = Undefined Then
		ColumnGroup.Group = ColumnsGroup.Vertical;
	Else
		ColumnGroup.Group = Group;
	EndIf;
	
	Return ColumnGroup;
	
EndFunction

Function CreateColumnItem(CommonData, ColumnName, Parent, ReadOnly = False, Visible = True, DataPath = "");
	
	TableName = CommonData.TableName;
	
	Items = CommonData.Form.Items;
	
	NewColumnItem = Items.Add(TableName + ColumnName, Type("FormField"), Parent);
	
	NewColumnItem.Type			= FormFieldType.InputField;
	NewColumnItem.ReadOnly		= ReadOnly;
	NewColumnItem.Visible		= Visible;
	NewColumnItem.ShowInHeader	= True;
	
	If ValueIsFilled(DataPath) Then
		NewColumnItem.DataPath = TableName + "." + DataPath;
	Else
		NewColumnItem.DataPath = TableName + "." + ColumnName;
	EndIf;
	
	Column = CommonData.CopyTable.Columns.Find(ColumnName);
	
	If Column <> Undefined Then
		
		NewColumnItem.Title = Column.Title;
		
		If Column.ValueType.ContainsType(Type("Null")) Then
			NewColumnItem.ChooseType = False;
			NewColumnItem.TypeRestriction = New TypeDescription(Column.ValueType, , "Null");
		EndIf;
		
		If Column.ValueType.ContainsType(Type("Number")) Then
			NewColumnItem.Width = 10;
		EndIf;
		
		If Column.ValueType.ContainsType(Type("Number")) Then
			NewColumnItem.Width = 10;
		EndIf;
		
	EndIf;
	
	Return NewColumnItem;
	
EndFunction

Function CreateExtDimensionColumnItem(CommonData, Parent, Index, Suffix = "", ReadOnly = False, Visible = True)
	
	ColumnName = MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix);
	
	NewItem = CreateColumnItem(CommonData, ColumnName, Parent, ReadOnly, Visible);
	
	NewItem.TypeLink = New TypeLink(
		StringFunctionsClientServer.SubstituteParametersToString(
			"Items.%1.CurrentData.%2",
			CommonData.TableName,
			MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix, "Type")),
		0);
	
	Return NewItem;
	
EndFunction

Function CreateAccountColumnItem(CommonData, ColumnName, Parent)
	
	Form = CommonData.Form;
	
	NewItem = CreateColumnItem(CommonData, ColumnName, Parent);
	
	If CommonClientServer.HasAttributeOrObjectProperty(Form, "Object")
		And CommonClientServer.HasAttributeOrObjectProperty(Form.Object, "ChartOfAccounts") Then
		
		ChoiceParameterLinkArray = New Array;
		ChoiceParameterLinkArray.Add(New ChoiceParameterLink("Filter.ChartOfAccounts", "Object.ChartOfAccounts", LinkedValueChangeMode.DontChange));
		ChoiceParameterLinkArray.Add(New ChoiceParameterLink("Filter.Date", "Object.Date", LinkedValueChangeMode.DontChange));
		ChoiceParameterLinkArray.Add(New ChoiceParameterLink("Filter.Company", "Object.Company", LinkedValueChangeMode.DontChange));
		
		NewItem.ChoiceParameterLinks = New FixedArray(ChoiceParameterLinkArray);
		
	ElsIf CommonClientServer.HasAttributeOrObjectProperty(Form, "ChartOfAccounts") Then
		
		ChoiceParameterLinkArray = New Array;
		ChoiceParameterLinkArray.Add(New ChoiceParameterLink("Filter.ChartOfAccounts", "ChartOfAccounts"));
		ChoiceParameterLinkArray.Add(New ChoiceParameterLink("Filter.Date", "Period"));
		ChoiceParameterLinkArray.Add(New ChoiceParameterLink("Filter.Company", "Company"));
		
		NewItem.ChoiceParameterLinks = New FixedArray(ChoiceParameterLinkArray);
		
	EndIf;
	
	Return NewItem;
	
EndFunction

Procedure SetupExtDimensionConditionalAppearance(Form, TableName, Index, Suffix = "") Export
	
	// Input hint
	ItemAppearance = Form.ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(ItemAppearance.Filter,
		TableName + "." + MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix, "Enabled"),
		True,
		DataCompositionComparisonType.Equal);
		
	WorkWithForm.AddFilterItem(ItemAppearance.Filter,
		TableName + "." + MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix, "Presentation"),
		Undefined,
		DataCompositionComparisonType.Filled);
		
	WorkWithForm.AddFilterItem(ItemAppearance.Filter,
		TableName + "." + MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix),
		Undefined,
		DataCompositionComparisonType.NotFilled);
		
	WorkWithForm.AddAppearanceField(ItemAppearance, 
		TableName + MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix));
		
	WorkWithForm.AddConditionalAppearanceItem(ItemAppearance, "TextColor", StyleColors.MinorInscriptionText);
		
	WorkWithForm.AddConditionalAppearanceItem(ItemAppearance,
		"Text",
		New DataCompositionField(TableName 
			+ "."
			+ MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix, "Presentation")));
		
	// Field availability
	ItemAppearance = Form.ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(ItemAppearance.Filter,
		TableName + "." + MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix, "Enabled"),
		False,
		DataCompositionComparisonType.Equal);
		
	WorkWithForm.AddAppearanceField(ItemAppearance, 
		TableName + MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix));
		
	WorkWithForm.AddConditionalAppearanceItem(ItemAppearance, "Enabled", False);
		
EndProcedure

Procedure SetupMiscFieldsConditionalAppearance(Form, TableName, Suffix = "", Compound = False)
	
	If Not Compound Then
	
		// Quantity
		ItemAppearance = Form.ConditionalAppearance.Items.Add();
		
		FilterItemGroup = WorkWithForm.CreateFilterItemGroup(ItemAppearance.Filter, DataCompositionFilterItemsGroupType.NotGroup);
		
		WorkWithForm.AddFilterItem(FilterItemGroup,
			TableName + ".UseQuantity" + Suffix,
			True,
			DataCompositionComparisonType.Equal);
			
		WorkWithForm.AddAppearanceField(ItemAppearance, TableName + "Quantity" + Suffix);
		WorkWithForm.AddConditionalAppearanceItem(ItemAppearance, "Enabled", False);
		
		// Currency
		ItemAppearance = Form.ConditionalAppearance.Items.Add();
		
		FilterItemGroup = WorkWithForm.CreateFilterItemGroup(ItemAppearance.Filter, DataCompositionFilterItemsGroupType.NotGroup);
		
		WorkWithForm.AddFilterItem(FilterItemGroup,
			TableName + ".UseCurrency" + Suffix,
			True,
			DataCompositionComparisonType.Equal);
			
		WorkWithForm.AddAppearanceField(ItemAppearance, TableName + "Currency" + Suffix);
		WorkWithForm.AddAppearanceField(ItemAppearance, TableName + "AmountCur" + Suffix);
		WorkWithForm.AddAppearanceField(ItemAppearance, TableName + "AmountCur" + Suffix);
		WorkWithForm.AddConditionalAppearanceItem(ItemAppearance, "Enabled", False);
	
	Else
		
		ItemAppearance = Form.ConditionalAppearance.Items.Add();
		
		FilterItemGroup = WorkWithForm.CreateFilterItemGroup(ItemAppearance.Filter, DataCompositionFilterItemsGroupType.NotGroup);
		
		WorkWithForm.AddFilterItem(FilterItemGroup,
			TableName + ".RecordType",
			?(Suffix = "Dr", AccountingRecordType.Debit, AccountingRecordType.Credit),
			DataCompositionComparisonType.Equal);
			
		WorkWithForm.AddFilterItem(FilterItemGroup,
			TableName + ".UseQuantity",
			True,
			DataCompositionComparisonType.Equal);
			
		WorkWithForm.AddAppearanceField(ItemAppearance, TableName + "Quantity" + Suffix);
		WorkWithForm.AddConditionalAppearanceItem(ItemAppearance, "Enabled", False);
		
		ItemAppearance = Form.ConditionalAppearance.Items.Add();
		
		FilterItemGroup = WorkWithForm.CreateFilterItemGroup(ItemAppearance.Filter, DataCompositionFilterItemsGroupType.NotGroup);
		
		WorkWithForm.AddFilterItem(FilterItemGroup,
			TableName + ".RecordType",
			?(Suffix = "Dr", AccountingRecordType.Debit, AccountingRecordType.Credit),
			DataCompositionComparisonType.Equal);
			
		WorkWithForm.AddFilterItem(FilterItemGroup,
			TableName + ".UseCurrency",
			True,
			DataCompositionComparisonType.Equal);
			
		WorkWithForm.AddAppearanceField(ItemAppearance, TableName + "Currency" + Suffix);
		WorkWithForm.AddAppearanceField(ItemAppearance, TableName + "AmountCur" + Suffix);
		WorkWithForm.AddConditionalAppearanceItem(ItemAppearance, "Enabled", False);
		
		ItemAppearance = Form.ConditionalAppearance.Items.Add();
		
		WorkWithForm.AddFilterItem(ItemAppearance.Filter,
			TableName + ".RecordType",
			?(Suffix = "Dr", AccountingRecordType.Credit, AccountingRecordType.Debit),
			DataCompositionComparisonType.Equal);
			
		WorkWithForm.AddAppearanceField(ItemAppearance, TableName + "Amount" + Suffix);
		WorkWithForm.AddConditionalAppearanceItem(ItemAppearance, "Enabled", False);
		
	EndIf;
	
EndProcedure

Procedure AddCommandButtons(Form, TypeOfEntries, TableName, Parent)
	
	AddSaveButton = (Form.FormName <> "Document.AccountingTransaction.Form.DocumentForm"
		And Form.FormName <> "DataProcessor.AccountingTemplatesTesting.Form.AccountingTemplateTesting");
	AddImportButton = Form.FormName = "Document.AccountingTransaction.Form.DocumentForm"
		And Form.Object.IsManual
		And AccessRight("View", Metadata.DataProcessors.DataImportFromExternalSources);
	
	Items = Form.Items;
	
	If TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Compound Then
		
		NewButton = Items.Add(TableName + "ExtraButtonAddEntry"		, Type("FormButton"), Parent.CommandBar);
		NewButton.CommandName = "AddEntry";
		NewButton.Title = NStr("en = 'Add entry'; ru = '???????????????? ????????????????';pl = 'Dodaj wpis';es_ES = 'A??adir entrada de diario';es_CO = 'A??adir entrada de diario';tr = 'Giri?? ekle';it = 'Aggiungere voce';de = 'Buchung hinzuf??gen'");
		
		NewButton = Items.Add(TableName + "ExtraButtonAddEntryLine"	, Type("FormButton"), Parent.CommandBar);
		NewButton.CommandName = "AddEntryLine";
		NewButton.Title = NStr("en = 'Add entry line'; ru = '???????????????? ???????????? ????????????????';pl = 'Dodaj wiersz wpisu';es_ES = 'A??adir l??nea de entrada de diario';es_CO = 'A??adir l??nea de entrada de diario';tr = 'Giri?? sat??r?? ekle';it = 'Aggiungere riga di voce';de = 'Buchungszeile hinzuf??gen'");
		
		NewButton = Items.Add(TableName + "ExtraButtonCopyEntriesRows"	, Type("FormButton"), Parent.CommandBar);
		NewButton.CommandName = "CopyEntriesRows";
		
		NewButton = Items.Add(TableName + "ExtraButtonDeleteEntry"	, Type("FormButton"), Parent.CommandBar);
		NewButton.CommandName = "DeleteEntry";
		NewButton.Title = NStr("en = 'Delete'; ru = '??????????????';pl = 'Usu??';es_ES = 'Borrar';es_CO = 'Borrar';tr = 'Sil';it = 'Elimina';de = 'L??schen'");
		
		NewButton = Items.Add(TableName + "ExtraButtonEntriesUp"	, Type("FormButton"), Parent.CommandBar);
		NewButton.CommandName = "EntriesUp";
		
		NewButton = Items.Add(TableName + "ExtraButtonEntriesDown"	, Type("FormButton"), Parent.CommandBar);
		NewButton.CommandName = "EntriesDown";
		
		If AddSaveButton Then
			NewButton = Items.Add(TableName + "ExtraButtonWrite"	, Type("FormButton"), Parent.CommandBar);
			NewButton.CommandName = "WriteData";
		EndIf;
		
		NewButton = Items.Add(TableName + "ContextMenuAddEntry"		, Type("FormButton"), Parent.ContextMenu);
		NewButton.CommandName = "AddEntry";
		NewButton.Title = NStr("en = 'Add entry'; ru = '???????????????? ????????????????';pl = 'Dodaj wpis';es_ES = 'A??adir entrada de diario';es_CO = 'A??adir entrada de diario';tr = 'Giri?? ekle';it = 'Aggiungere voce';de = 'Buchung hinzuf??gen'");
		
		NewButton = Items.Add(TableName + "ContextMenuAddEntryLine"	, Type("FormButton"), Parent.ContextMenu);
		NewButton.CommandName = "AddEntryLine";
		NewButton.Title = NStr("en = 'Add entry line'; ru = '???????????????? ???????????? ????????????????';pl = 'Dodaj wiersz wpisu';es_ES = 'A??adir l??nea de entrada de diario';es_CO = 'A??adir l??nea de entrada de diario';tr = 'Giri?? sat??r?? ekle';it = 'Aggiungere riga di voce';de = 'Buchungszeile hinzuf??gen'");
		
		NewButton = Items.Add(TableName + "ContextMenuCopyEntriesRows"	, Type("FormButton"), Parent.ContextMenu);
		NewButton.CommandName = "CopyEntriesRows";
		
		NewButton = Items.Add(TableName + "ContextMenuEntriesUp"	, Type("FormButton"), Parent.ContextMenu);
		NewButton.CommandName = "EntriesUp";
		
		NewButton = Items.Add(TableName + "ContextMenuEntriesDown"	, Type("FormButton"), Parent.ContextMenu);
		NewButton.CommandName = "EntriesDown";
		
		If AddSaveButton Then	
			NewButton = Items.Add(TableName + "ContextMenuWrite"	, Type("FormButton"), Parent.ContextMenu);
			NewButton.CommandName = "WriteData";
		EndIf;
		
	ElsIf AddSaveButton Then
		
		NewButton = Items.Add(TableName + "ExtraButtonWrite"		, Type("FormButton"), Parent.CommandBar);
		NewButton.CommandName = "WriteData";
		
		NewButton = Items.Add(TableName + "ContextMenuWrite"		, Type("FormButton"), Parent.ContextMenu);
		NewButton.CommandName = "WriteData";
		
	EndIf;
	
	If AddImportButton Then
		
		NewButton = Items.Add(TableName + "ExtraButtonImportDataButton", Type("FormButton"), Parent.CommandBar);
		NewButton.CommandName = "DataImportFromExternalSources";
		
	EndIf;
	
EndProcedure

#EndRegion