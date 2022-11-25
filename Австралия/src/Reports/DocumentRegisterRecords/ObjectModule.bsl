#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region GeneralPurposeProceduresAndFunctions

// The function returns non-blank document movements.
//
Function DefineIfThereAreRegisterRecordsByRegistrator() 
	
	QueryText = "";
	DocumentRegisterRecords = Document.Metadata().RegisterRecords;
	
	If DocumentRegisterRecords.Count() = 0 Then
		Return New ValueTable;
	EndIf;
	
	For Each RegisterRecord In DocumentRegisterRecords Do
		
		If RegisterRecord.FullName() <> Metadata.AccountingRegisters.AccountingJournalEntriesCompound.FullName() Then
			
			QueryText = QueryText + "
			|" + ?(QueryText = "", "", "UNION ALL ") + "
			|SELECT TOP 1 CAST(""" + RegisterRecord.FullName() 
			+  """ AS String(200)) AS Name FROM " + RegisterRecord.FullName() 
			+ " WHERE Recorder = &Recorder";
			
		Else	
		
			QueryText = QueryText + "
			|" + ?(QueryText = "", "", "UNION ALL ") + "
			|SELECT TOP 1 CAST(""" + RegisterRecord.FullName() 
			+  """ AS String(200)) AS Name FROM " + RegisterRecord.FullName() 
			+ " WHERE CASE
			|	WHEN Recorder REFS Document.AccountingTransaction
			|		THEN Recorder.BasisDocument = &Recorder
			|			ELSE Recorder = &Recorder
			|		END";
			
		EndIf;
		
	EndDo;
	
	Query = New Query(QueryText);
	Query.SetParameter("Recorder", Document);
	
	QueryTable = Query.Execute().Unload();
	QueryTable.Indexes.Add("Name");
	
	For Each TableRowMovements In QueryTable Do
		TableRowMovements.Name = Upper(TrimAll(TableRowMovements.Name));
	EndDo;
	
	Return QueryTable;
		
EndFunction

// Function returns register kind.
//
Function DefineRegisterKind(RegisterMetadata)
	
	If Metadata.AccumulationRegisters.IndexOf(RegisterMetadata) >= 0 Then
		Return "Accumulation";
		
	ElsIf Metadata.InformationRegisters.IndexOf(RegisterMetadata) >= 0 Then
		Return "Information";	
		
	ElsIf Metadata.AccountingRegisters.IndexOf(RegisterMetadata) >= 0 Then
		Return "Accounting";
		
	Else
		Return "";
			
	EndIf;
    	
EndFunction

// The procedure generates the fields list for query.
//
Procedure GenerateFieldList(MetadataResource, TableOfFields, FieldList)
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	For Each Resource In MetadataResource Do
		
		If (Resource.Type.ContainsType(Type("CatalogRef.ProductsCharacteristics")) And Not Constants.UseCharacteristics.Get())
			Or (Resource.Type.ContainsType(Type("CatalogRef.ProductsBatches")) And Not Constants.UseBatches.Get())
			Or (Resource.Type.ContainsType(Type("CatalogRef.Projects")) And Not Constants.UseProjects.Get())
			Or (Resource.Type.ContainsType(Type("ChartOfAccountsRef.PrimaryChartOfAccounts")) And Not UseDefaultTypeOfAccounting) Then
			
			Continue;
			
		EndIf;
		
		FieldList = FieldList + ", "+ Resource.Name;
		TableOfFields.Columns.Add(Resource.Name, , Resource.Synonym);
		
	EndDo;
	
	
EndProcedure

// The procedure adds period to the fields list for query.
//
Procedure AddPeriodToFieldList(TableOfFields, FieldList)
	
	FieldList = FieldList + ", Period";
	TableOfFields.Columns.Add("Period", , NStr("en = 'Period'; ru = 'Период';pl = 'Okres';es_ES = 'Período';es_CO = 'Período';tr = 'Dönem';it = 'Periodo';de = 'Zeitraum'"));
	
EndProcedure

Procedure AddAdditionalFieldsToFieldList(ObjectName, TableOfFields, FieldList)
	
	If ObjectName = "InformationRegister.AccountingEntriesData" Then
		TableOfFields.Columns.Add("Recorder");
		FieldList = FieldList + ", Recorder";
	EndIf;
	
EndProcedure

Function StructureToArray(InitStructure)
	
	ResultArray = New Array;
	For Each Item In InitStructure Do
		ResultArray.Add(New Structure("Name, Synonym", Item.Key, Item.Value));
	EndDo;
	
	Return ResultArray;
	
EndFunction

Function GetFieldData(DataArray, Index, TableOfDimensions, ResourcesTable, AttributesTable, LineNumber)
	
	ResultStructure = New Structure("Synonym, Value");
	FieldName = DataArray[Index].Name;
	If TableOfDimensions.Columns.Find(FieldName) <> Undefined Then
		ResultStructure.Value = TableOfDimensions[LineNumber-1][FieldName];
	ElsIf ResourcesTable.Columns.Find(FieldName) <> Undefined Then
		ResultStructure.Value = ResourcesTable[LineNumber-1][FieldName];
	ElsIf AttributesTable.Columns.Find(FieldName) <> Undefined Then
		ResultStructure.Value = AttributesTable[LineNumber-1][FieldName];
	EndIf;
	ResultStructure.Synonym = DataArray[Index].Synonym;
	
	Return ResultStructure;
	
EndFunction

// The procedure outputs movements by accumulation and information registers.
//
Procedure ProcessDataOutputByArray(FieldList, ResourcesTable, TableOfDimensions, AttributesTable, TableKindOfMovements = Undefined, Val RegisterName, SynonymRegister, SpreadsheetDocument)
	
	If Not ValueIsFilled(FieldList) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT " + FieldList +"
		|{SELECT " + FieldList +"} FROM " + RegisterName + " AS
		|Reg WHERE Reg.Recorder =
		|	 &ReportDocument AND Reg.Active";
		
	Query.SetParameter("ReportDocument", Document);
	
	TableQueryResult = Query.Execute().Unload();
	
	For Each ResultRow In TableQueryResult Do
		If TableKindOfMovements <> Undefined Then
			NewRow = TableKindOfMovements.Add();
			FillPropertyValues(NewRow, ResultRow);
		EndIf;
		NewRow = ResourcesTable.Add();
		FillPropertyValues(NewRow, ResultRow);
		NewRow = TableOfDimensions.Add();
		FillPropertyValues(NewRow, ResultRow);
		NewRow = AttributesTable.Add();
		FillPropertyValues(NewRow, ResultRow);
	EndDo;
	
	ResultLineCount = TableQueryResult.Count();
	
	DocStructure = Common.ObjectAttributesValues(Document, "Date, Company");
	
	If RegisterName = "InformationRegister.AccountingEntriesData" 
		And (ResultLineCount = 0 
		And Not Constants.AccountingModuleSettings.UseTemplatesIsEnabled()) Then
		
		Return;
		
	EndIf;
	
	Template = Reports.DocumentRegisterRecords.GetTemplate("Template");
	HeaderArea = Template.GetArea("ReportHeader");
	
	HeaderArea.Parameters.SynonymRegister = String(SynonymRegister);
	SpreadsheetDocument.Put(HeaderArea);
	SpreadsheetDocument.StartRowGroup();
	
	If SubordinateDocumentsStructureGrouping = Enums.SubordinateDocumentsStructureGrouping.Horizontal Then
	
		// Output in string
		
		If RegisterName = "InformationRegister.AccountingEntriesData" Then
			
			If Not Constants.AccountingModuleSettings.UseTemplatesIsEnabled() Then
				Return;
			EndIf;
			
			AreaTitleCellSingle		= Template.GetArea("CellTitle");
			AreaCellSingle	 		= Template.GetArea("Cell");
			AreaCellEmptySingle		= Template.GetArea("CellEmpty");
			AreaTitleCell	 		= Template.GetArea("CellTitleAccountingEntriesData");
			AreaCell		 		= Template.GetArea("CellAccountingEntriesData");
			AreaCellEmpty	 		= Template.GetArea("CellEmptyAccountingEntriesData");
			AreaIndent 				= Template.GetArea("Indent1");
			
			ModuleManager = Common.ObjectManagerByRef(Document);
			AccountingFieldsMap = ModuleManager.AccountingFields();
			
			For LineNumber = 1 To ResultLineCount Do
				
				If LineNumber > 1 Then
					SpreadsheetDocument.Put(AreaIndent);
				EndIf;
				
				ColumnStructure = AccountingFieldsMap[Common.EnumValueName(TableOfDimensions[LineNumber-1].EntryType)];
				
				MainDetailsArray = New Array;
				MainDetailsArray = StructureToArray(ColumnStructure.MainDetails);
				ColumnStructureMainDetailsCount = ColumnStructure.MainDetails.Count() + 2;
				
				AdditionalDetailsArray = StructureToArray(ColumnStructure.AdditionalDetails);
				ColumnStructureAdditionalDetailsCount = ColumnStructure.AdditionalDetails.Count();
				
				DebitDetailsArray = StructureToArray(ColumnStructure.DebitDetails);
				ColumnStructureDebitDetailsCount = ColumnStructure.DebitDetails.Count();
				
				CreditDetailsArray = StructureToArray(ColumnStructure.CreditDetails);
				ColumnStructureCreditDetalsCount = ColumnStructure.CreditDetails.Count();
				
				AmountsArray = StructureToArray(ColumnStructure.Amounts);
				ColumnStructureAmountsCount = ColumnStructure.Amounts.Count();
				
				MaxLength = Max(ColumnStructureMainDetailsCount, 
					ColumnStructureAdditionalDetailsCount,
					ColumnStructureDebitDetailsCount,
					ColumnStructureCreditDetalsCount,
					ColumnStructureAmountsCount);
				
				SpreadsheetDocument.Put(AreaIndent);
				AreaTitleCell.Parameters.ColumnsTitle = NStr("en = 'Main details'; ru = 'Основные данные';pl = 'Podstawowe szczegóły';es_ES = 'Detalles principales';es_CO = 'Detalles principales';tr = 'Genel bilgiler';it = 'Dettagli principali';de = 'Hauptdetails'");
				SpreadsheetDocument.Join(AreaTitleCell);
				AreaTitleCell.Parameters.ColumnsTitle = NStr("en = 'Additional details'; ru = 'Дополнительное описание';pl = 'Dodatkowe szczegóły';es_ES = 'Detalles adicionales';es_CO = 'Detalles adicionales';tr = 'Ek detaylar';it = 'Dettagli aggiuntivi';de = 'Zusätzliche Details'");
				SpreadsheetDocument.Join(AreaTitleCell);
				AreaTitleCell.Parameters.ColumnsTitle = NStr("en = 'Debit details'; ru = 'Данные по дебету';pl = 'Zobowiązania szczegóły';es_ES = 'Detalles del débito';es_CO = 'Detalles del débito';tr = 'Borç bilgileri';it = 'Dettagli debito';de = 'Soll-Details'");
				SpreadsheetDocument.Join(AreaTitleCell);
				AreaTitleCell.Parameters.ColumnsTitle = NStr("en = 'Credit details'; ru = 'Данные по кредиту';pl = 'Należności szczegóły';es_ES = 'Detalles del crédito';es_CO = 'Detalles del crédito';tr = 'Alacak bilgileri';it = 'Dettagli credito';de = 'Haben-Details'");
				SpreadsheetDocument.Join(AreaTitleCell);
				AreaTitleCell.Parameters.ColumnsTitle = NStr("en = 'Amounts'; ru = 'Суммы';pl = 'Wartości';es_ES = 'Importes';es_CO = 'Importes';tr = 'Tutarlar';it = 'Importi';de = 'Beträge'");
				SpreadsheetDocument.Join(AreaTitleCell);
				
				For Index = 1 To MaxLength Do
					
					SpreadsheetDocument.Put(AreaIndent);
					
					If Index = 1 Then
						AreaCell.Parameters.Synonym	 = NStr("en = 'Source document'; ru = 'Первичный документ';pl = 'Dokument źródłowy';es_ES = 'Documento de fuente';es_CO = 'Documento de fuente';tr = 'Kaynak belge';it = 'Documento fonte';de = 'Quelldokument'");
						AreaCell.Parameters.Value	 = Document;
						SpreadsheetDocument.Join(AreaCell);
					ElsIf Index = 2 Then
						AreaCell.Parameters.Synonym	 = NStr("en = 'Entry type'; ru = 'Тип проводки';pl = 'Typ wpisu';es_ES = 'Tipos de entrada de diario';es_CO = 'Tipos de entrada de diario';tr = 'Giriş türü';it = 'Tipo di voce';de = 'Buchungstyp'");
						AreaCell.Parameters.Value	 = TableOfDimensions[LineNumber - 1].EntryType;
						SpreadsheetDocument.Join(AreaCell);
					ElsIf Index <= ColumnStructureMainDetailsCount Then
						
						FieldData = GetFieldData(MainDetailsArray, Index - 3, TableOfDimensions, ResourcesTable, AttributesTable, LineNumber);
						AreaCell.Parameters.Fill(FieldData);
						SpreadsheetDocument.Join(AreaCell);
						
					Else
						SpreadsheetDocument.Join(AreaCellEmpty);
					EndIf;
					
					If Index <= ColumnStructureAdditionalDetailsCount Then
						
						FieldData = GetFieldData(AdditionalDetailsArray, Index - 1, TableOfDimensions, ResourcesTable, AttributesTable, LineNumber);
						AreaCell.Parameters.Fill(FieldData);
						SpreadsheetDocument.Join(AreaCell);
						
					Else
						SpreadsheetDocument.Join(AreaCellEmpty);
					EndIf;
					
					If Index <= ColumnStructureDebitDetailsCount Then
						
						FieldData = GetFieldData(DebitDetailsArray, Index - 1, TableOfDimensions, ResourcesTable, AttributesTable, LineNumber);
						AreaCell.Parameters.Fill(FieldData);
						SpreadsheetDocument.Join(AreaCell);
						
					Else
						SpreadsheetDocument.Join(AreaCellEmpty);
					EndIf;
					
					If Index <= ColumnStructureCreditDetalsCount Then
						
						FieldData = GetFieldData(CreditDetailsArray, Index - 1, TableOfDimensions, ResourcesTable, AttributesTable, LineNumber);
						AreaCell.Parameters.Fill(FieldData);
						SpreadsheetDocument.Join(AreaCell);
						
					Else
						SpreadsheetDocument.Join(AreaCellEmpty);
					EndIf;
					
					If Index <= ColumnStructureAmountsCount Then
						
						FieldData = GetFieldData(AmountsArray, Index - 1, TableOfDimensions, ResourcesTable, AttributesTable, LineNumber);
						AreaCell.Parameters.Fill(FieldData);
						SpreadsheetDocument.Join(AreaCell);
						
					Else
						SpreadsheetDocument.Join(AreaCellEmpty);
					EndIf;
					
				EndDo;
				
			EndDo;
			
		Else
			
			AreaTitleCell	 		= Template.GetArea("CellTitle");
			AreaCell		 		= Template.GetArea("Cell");
			AreaIndent 				= Template.GetArea("Indent1");
			
			SpreadsheetDocument.Put(AreaIndent);
			If TableKindOfMovements <> Undefined Then
				AreaTitleCell.Parameters.ColumnsTitle = NStr("en = 'Record type'; ru = 'Тип записи';pl = 'Rodzaj wpisu';es_ES = 'Tipo de registro';es_CO = 'Tipo de registro';tr = 'Kayıt türü';it = 'Tipo di registrazione';de = 'Satztyp'");
				SpreadsheetDocument.Join(AreaTitleCell);
			EndIf;
			For Each Column In TableOfDimensions.Columns Do
				AreaTitleCell.Parameters.ColumnsTitle = Column.Title;
				SpreadsheetDocument.Join(AreaTitleCell);
			EndDo; 
			For Each Column In ResourcesTable.Columns Do
				AreaTitleCell.Parameters.ColumnsTitle = Column.Title;
				SpreadsheetDocument.Join(AreaTitleCell);
			EndDo;
			For Each Column In AttributesTable.Columns Do
				AreaTitleCell.Parameters.ColumnsTitle = Column.Title;
				SpreadsheetDocument.Join(AreaTitleCell);
			EndDo;
			
			For LineNumber = 1 To ResultLineCount Do
				
				SpreadsheetDocument.Put(AreaIndent);
				If TableKindOfMovements <> Undefined Then
					AreaCell.Parameters.Value = TableKindOfMovements[LineNumber - 1].RecordType;
					SpreadsheetDocument.Join(AreaCell);
					If TableKindOfMovements[LineNumber-1].RecordType = AccumulationRecordType.Expense Then
						Area = SpreadsheetDocument.Area("Cell");
					Area.TextColor = StyleColors.ImportPaymentExpense;
					Else
						Area = SpreadsheetDocument.Area("Cell");
					Area.TextColor = StyleColors.ModifiedAttributeValueColor;
					EndIf;
				EndIf;
				For Each Column In TableOfDimensions.Columns Do
					Value = TableOfDimensions[LineNumber - 1][Column.Name]; 
					AreaCell.Parameters.Value = Value;
					If ValueIsFilled(Value) And TypeOf(Value) <> Type("Date") And TypeOf(Value) <> Type("Number")
						And TypeOf(Value) <> Type("Boolean") And TypeOf(Value) <> Type("String") Then
						AreaCell.Parameters.ValueDetails = Value;
					Else
						AreaCell.Parameters.ValueDetails = Undefined;				
					EndIf; 
					SpreadsheetDocument.Join(AreaCell);
				EndDo; 
				For Each Column In ResourcesTable.Columns Do
					Value = ResourcesTable[LineNumber - 1][Column.Name]; 
					AreaCell.Parameters.Value = Value;
					If ValueIsFilled(Value) And TypeOf(Value) <> Type("Date") And TypeOf(Value) <> Type("Number")
						And TypeOf(Value) <> Type("Boolean") And TypeOf(Value) <> Type("String") Then
						AreaCell.Parameters.ValueDetails = Value;
					Else
						AreaCell.Parameters.ValueDetails = Undefined;
					EndIf; 
					SpreadsheetDocument.Join(AreaCell);
				EndDo; 
				For Each Column In AttributesTable.Columns Do
					Value = AttributesTable[LineNumber - 1][Column.Name]; 
					AreaCell.Parameters.Value = Value;
					If ValueIsFilled(Value) And TypeOf(Value) <> Type("Date") And TypeOf(Value) <> Type("Number")
						And TypeOf(Value) <> Type("Boolean") And TypeOf(Value) <> Type("String") Then
						AreaCell.Parameters.ValueDetails = Value;
					Else
						AreaCell.Parameters.ValueDetails = Undefined;				
					EndIf; 
					SpreadsheetDocument.Join(AreaCell);
				EndDo; 
				
			EndDo;
			
		EndIf;
		
		
	Else
	
		// Table output
		
		If TableKindOfMovements <> Undefined Then
			HeaderArea 					= Template.GetArea("TableHeader");
			HeaderDetailsArea 				= Template.GetArea("DetailsHeader");
			AreaDetails 					= Template.GetArea("Details");
			AreaHeaderRecordKind 		= Template.GetArea("HeaderTablesRecordKind");
			HeaderAreaDetailsRecordKind 	= Template.GetArea("DetailsHeaderRecordKind");
			AreaDetailsRecordKind 		= Template.GetArea("DetailsRecordKind");
			AreaIndent 					= Template.GetArea("Indent");
		Else	
		    HeaderArea 					= Template.GetArea("TableHeader1");
			HeaderDetailsArea 				= Template.GetArea("DetailsHeader1");
			AreaDetails 					= Template.GetArea("Details1");
			AreaIndent 					= Template.GetArea("Indent2");
		EndIf;
		
			
		
		SpreadsheetDocument.Put(AreaIndent);
		
		If TableKindOfMovements <> Undefined Then
			SpreadsheetDocument.Join(AreaHeaderRecordKind);
		EndIf;
		SpreadsheetDocument.Join(HeaderArea);
	 	
		LineCountHeader = Max(ResourcesTable.Columns.Count(), TableOfDimensions.Columns.Count(), AttributesTable.Columns.Count());
		ThickLine = New Line(SpreadsheetDocumentCellLineType.Solid,2);
		ThinConnector = New Line(SpreadsheetDocumentCellLineType.Solid,1);
		
		For LineNumber = 1 To LineCountHeader Do
			
			HeaderDetailsArea.Parameters.Resources = "";
			HeaderDetailsArea.Parameters.Dimensions = "";
			HeaderDetailsArea.Parameters.Attributes = "";
			
			If ResourcesTable.Columns.Count() >= LineNumber Then
				HeaderDetailsArea.Parameters.Resources = ResourcesTable.Columns[LineNumber-1].Title;
			EndIf; 	
			If TableOfDimensions.Columns.Count() >= LineNumber Then
				HeaderDetailsArea.Parameters.Dimensions = TableOfDimensions.Columns[LineNumber-1].Title;
			EndIf; 	
			If AttributesTable.Columns.Count() >= LineNumber Then
				HeaderDetailsArea.Parameters.Attributes = AttributesTable.Columns[LineNumber-1].Title;
			EndIf;
						
			SpreadsheetDocument.Put(AreaIndent);
			If TableKindOfMovements <> Undefined Then
				SpreadsheetDocument.Join(HeaderAreaDetailsRecordKind);	
			EndIf;
			SpreadsheetDocument.Join(HeaderDetailsArea);	
						
			If LineNumber = LineCountHeader Then
			    If TableKindOfMovements <> Undefined Then
					Area = SpreadsheetDocument.Area("DetailsHeaderRecordKind");
					Area.Outline(ThickLine, , ThickLine, ThickLine);
					Area = SpreadsheetDocument.Area("DetailsHeader");
					Area.Outline(ThickLine, , ThickLine, ThickLine);
				Else	
					Area = SpreadsheetDocument.Area("DetailsHeader1");
					Area.Outline(ThickLine, , ThickLine, ThickLine);
				EndIf;
				
			EndIf; 
			
		EndDo; 
		
		For LineNumber = 1 To ResultLineCount Do
			
			FlagDisplayedRecordKind = False;
			
			For ColumnNumber = 1 To LineCountHeader Do
			
				AreaDetails.Parameters.Resources = "";
				AreaDetails.Parameters.Dimensions = "";
				AreaDetails.Parameters.Attributes = "";
				
				If ResourcesTable.Columns.Count() >= ColumnNumber Then
					ColumnName = ResourcesTable.Columns[ColumnNumber-1].Name;
					Value = ResourcesTable[LineNumber-1][ColumnName]; 
					AreaDetails.Parameters.Resources = Value;
					If ValueIsFilled(Value) And TypeOf(Value) <> Type("Date") And TypeOf(Value) <> Type("Number")
						And TypeOf(Value) <> Type("Boolean") And TypeOf(Value) <> Type("String") Then
						AreaDetails.Parameters.ResourcesDetails = Value;
					Else
						AreaDetails.Parameters.ResourcesDetails = Undefined;
					EndIf;
				EndIf; 	
				If TableOfDimensions.Columns.Count() >= ColumnNumber Then
					ColumnName = TableOfDimensions.Columns[ColumnNumber-1].Name;
					Value = TableOfDimensions[LineNumber-1][ColumnName]; 
					AreaDetails.Parameters.Dimensions = Value;
					If ValueIsFilled(Value) And TypeOf(Value) <> Type("Date") And TypeOf(Value) <> Type("Number")
						And TypeOf(Value) <> Type("Boolean") And TypeOf(Value) <> Type("String") Then
						AreaDetails.Parameters.DimensionsDetails = Value;
					Else
						AreaDetails.Parameters.DimensionsDetails = Undefined;
					EndIf;
				EndIf; 	
				If AttributesTable.Columns.Count() >= ColumnNumber Then
					ColumnName = AttributesTable.Columns[ColumnNumber-1].Name;
					Value = AttributesTable[LineNumber-1][ColumnName]; 
					AreaDetails.Parameters.Attributes = Value;
					If ValueIsFilled(Value) And TypeOf(Value) <> Type("Date") And TypeOf(Value) <> Type("Number")
						And TypeOf(Value) <> Type("Boolean") And TypeOf(Value) <> Type("String") Then
						AreaDetails.Parameters.AttributesDetails = Value;
					Else
						AreaDetails.Parameters.AttributesDetails = Undefined;
					EndIf;
				EndIf;
				
				SpreadsheetDocument.Put(AreaIndent);
				
				If TableKindOfMovements <> Undefined Then

					If FlagDisplayedRecordKind Then
						ParameterValue = "";
					Else
						ParameterValue = TableKindOfMovements[LineNumber-1]["RecordType"];
						FlagDisplayedRecordKind = True;
					EndIf;

					AreaDetailsRecordKind.Parameters.RecordType = ParameterValue;
					SpreadsheetDocument.Join(AreaDetailsRecordKind);

                    If ParameterValue = AccumulationRecordType.Expense Then
						Area = SpreadsheetDocument.Area("DetailsRecordKind");
						Area.TextColor = StyleColors.ImportPaymentExpense;
					ElsIf ParameterValue = AccumulationRecordType.Receipt Then
					    Area = SpreadsheetDocument.Area("DetailsRecordKind");
						Area.TextColor = StyleColors.ModifiedAttributeValueColor;
					EndIf;
				EndIf;
				
				SpreadsheetDocument.Join(AreaDetails);
				
                If ColumnNumber = LineCountHeader Then
				    If TableKindOfMovements <> Undefined Then
						Area = SpreadsheetDocument.Area("DetailsRecordKind");
						Area.Outline(ThinConnector, , ThinConnector, ThinConnector);
                        Area = SpreadsheetDocument.Area("Details");
						Area.Outline(ThinConnector, , ThinConnector, ThinConnector);
                    Else
                        Area = SpreadsheetDocument.Area("Details1");
						Area.Outline(ThinConnector, , ThinConnector, ThinConnector);
					EndIf;
					
				EndIf;

			EndDo;
			
		EndDo; 
		
	EndIf;	
		
	SpreadsheetDocument.EndRowGroup();
			    	
EndProcedure

// The procedure outputs movements by the accounting register.
//
Procedure DoOutputPostingJournal(RegisterName, SynonymRegister, SpreadsheetDocument)
	
	If RegisterName = Metadata.AccountingRegisters.AccountingJournalEntries.FullName() Then
		
		Template 					= Reports.DocumentRegisterRecords.GetTemplate("Template");
		TemplateAccountingRegister 	= Reports.DocumentRegisterRecords.GetTemplate("TemplateAccountingRegister");
		HeaderArea 					= Template.GetArea("ReportHeader");
		AreaHeader 					= TemplateAccountingRegister.GetArea("Header");
		AreaDetails 				= TemplateAccountingRegister.GetArea("Details");
		
		HeaderArea.Parameters.SynonymRegister = SynonymRegister;
		SpreadsheetDocument.Put(HeaderArea);
		SpreadsheetDocument.StartRowGroup();
		
		SpreadsheetDocument.Put(AreaHeader);	
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	AccountingJournalEntries.Period AS Period,
		|	AccountingJournalEntries.Recorder AS Recorder,
		|	AccountingJournalEntries.LineNumber AS LineNumber,
		|	AccountingJournalEntries.Active AS Active,
		|	AccountingJournalEntries.AccountDr AS AccountDr,
		|	AccountingJournalEntries.AccountCr AS AccountCr,
		|	AccountingJournalEntries.Company AS Company,
		|	&PlanningPeriod AS PlanningPeriod,
		|	AccountingJournalEntries.CurrencyDr AS CurrencyDr,
		|	AccountingJournalEntries.CurrencyCr AS CurrencyCr,
		|	AccountingJournalEntries.Amount AS Amount,
		|	AccountingJournalEntries.AmountCurDr AS AmountCurDr,
		|	AccountingJournalEntries.AmountCurCr AS AmountCurCr,
		|	AccountingJournalEntries.Content AS Content
		|FROM
		|	&AccountingRegister AS AccountingJournalEntries
		|WHERE
		|	AccountingJournalEntries.Recorder = &ReportDocument
		|
		|ORDER BY
		|	LineNumber";
		
		Query.Text = StrReplace(Query.Text, "&AccountingRegister", RegisterName);
		If RegisterName = "AccountingRegister.AccountingJournalEntries" Then
			Query.Text = StrReplace(Query.Text, "&PlanningPeriod", "AccountingJournalEntries.PlanningPeriod");
		Else
			Query.Text = StrReplace(Query.Text, "&PlanningPeriod", "VALUE(Catalog.PlanningPeriods.EmptyRef)");
		EndIf;
		
		Query.SetParameter("ReportDocument", Document);
		
		TableQueryResult = Query.Execute().Unload();
		For Each ResultRow In TableQueryResult Do
			
			FillPropertyValues(AreaDetails.Parameters, ResultRow);
			SpreadsheetDocument.Put(AreaDetails);
			
		EndDo;
		
		SpreadsheetDocument.EndRowGroup();
		
	ElsIf RegisterName = Metadata.AccountingRegisters.AccountingJournalEntriesSimple.FullName() Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.Period AS Period,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.Recorder AS Recorder,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.LineNumber AS LineNumber,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.Active AS Active,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.Company AS Company,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.PlanningPeriod AS PlanningPeriod,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.Status AS Status,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.Amount AS Amount,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.Content AS Content,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.OfflineRecord AS OfflineRecord,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.TransactionTemplate AS TransactionTemplate,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.TransactionTemplateLineNumber AS TransactionTemplateLineNumber,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.TypeOfAccounting AS TypeOfAccounting,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.AccountDr AS Debit,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionDr1 AS ExtDimensionDr1,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionTypeDr1 AS ExtDimensionTypeDr1,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionDr2 AS ExtDimensionDr2,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionTypeDr2 AS ExtDimensionTypeDr2,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionDr3 AS ExtDimensionDr3,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionTypeDr3 AS ExtDimensionTypeDr3,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionDr4 AS ExtDimensionDr4,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionTypeDr4 AS ExtDimensionTypeDr4,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.AccountCr AS Credit,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionCr1 AS ExtDimensionCr1,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionTypeCr1 AS ExtDimensionTypeCr1,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionCr2 AS ExtDimensionCr2,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionTypeCr2 AS ExtDimensionTypeCr2,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionCr3 AS ExtDimensionCr3,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionTypeCr3 AS ExtDimensionTypeCr3,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionCr4 AS ExtDimensionCr4,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionTypeCr4 AS ExtDimensionTypeCr4,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.CurrencyDr AS CurrencyDr,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.CurrencyCr AS CurrencyCr,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.AmountCurDr AS AmountCurDr,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.AmountCurCr AS AmountCurCr,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.QuantityDr AS QuantityDr,
		|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.QuantityCr AS QuantityCr
		|FROM
		|	AccountingRegister.AccountingJournalEntriesSimple.RecordsWithExtDimensions(, , Recorder = &Recorder, , ) AS AccountingJournalEntriesSimpleRecordsWithExtDimensions
		|TOTALS BY
		|	TypeOfAccounting";
		
		Query.SetParameter("Recorder", Document);
		
		ResultQuery = Query.Execute();
		
		SelectionTypeOfAccounting = ResultQuery.Select(QueryResultIteration.ByGroups);
		
		Template 					= Reports.DocumentRegisterRecords.GetTemplate("Template");
		TemplateAccountingRegister	= Reports.DocumentRegisterRecords.GetTemplate("TemplateAccountingRegisterMaster");
		HeaderArea					= Template.GetArea("ReportHeader");
		AreaHeader					= TemplateAccountingRegister.GetArea("HeaderSimple");
		AreaDetails					= TemplateAccountingRegister.GetArea("DetailsSimple");
			
		While SelectionTypeOfAccounting.Next() Do
			
			Selection	= SelectionTypeOfAccounting.Select();
			NoHeader	= True;
			
			While Selection.Next() Do
				
				If NoHeader Then
					
					HeaderArea.Parameters.SynonymRegister = SynonymRegister + " (" + SelectionTypeOfAccounting.TypeOfAccounting + ")";
					SpreadsheetDocument.Put(HeaderArea);
					SpreadsheetDocument.StartRowGroup();
					
					SpreadsheetDocument.Put(AreaHeader);
					
					NoHeader = False;
					
				EndIf;
				
				FillPropertyValues(AreaDetails.Parameters, Selection);
				SpreadsheetDocument.Put(AreaDetails);
				
			EndDo;
			
			If Not NoHeader Then
				SpreadsheetDocument.EndRowGroup();
			EndIf;
			
		EndDo;
		
	Else
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Period AS Period,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Recorder AS Recorder,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.LineNumber AS LineNumber,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Active AS Active,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType AS RecordType,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Account AS Account,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Company AS Company,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.PlanningPeriod AS PlanningPeriod,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Currency AS Currency,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Status AS Status,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Amount AS Amount,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.AmountCur AS AmountCur,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Content AS Content,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.OfflineRecord AS OfflineRecord,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.TransactionTemplate AS TransactionTemplate,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.TransactionTemplateLineNumber AS TransactionTemplateLineNumber,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.TypeOfAccounting AS TypeOfAccounting,
		|	CASE
		|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Credit)
		|			THEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.Amount
		|		ELSE 0
		|	END AS AmountCr,
		|	CASE
		|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Debit)
		|			THEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.Amount
		|		ELSE 0
		|	END AS AmountDr,
		|	CASE
		|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Credit)
		|			THEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.AmountCur
		|		ELSE 0
		|	END AS AmountCurCr,
		|	CASE
		|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Debit)
		|			THEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.AmountCur
		|		ELSE 0
		|	END AS AmountCurDr,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.ExtDimension1 AS ExtDimension1,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.ExtDimension2 AS ExtDimension2,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.ExtDimension3 AS ExtDimension3,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.ExtDimension4 AS ExtDimension4,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.ExtDimensionType1 AS ExtDimensionType1,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.ExtDimensionType2 AS ExtDimensionType2,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.ExtDimensionType3 AS ExtDimensionType3,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.ExtDimensionType4 AS ExtDimensionType4,
		|	CASE
		|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Credit)
		|			THEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.Quantity
		|		ELSE 0
		|	END AS QuantityCr,
		|	CASE
		|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Debit)
		|			THEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.Quantity
		|		ELSE 0
		|	END AS QuantityDr,
		|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Quantity AS Quantity
		|FROM
		|	AccountingRegister.AccountingJournalEntriesCompound.RecordsWithExtDimensions(, , Recorder = &Recorder, , ) AS AccountingJournalEntriesCompoundRecordsWithExtDimensions
		|TOTALS BY
		|	TypeOfAccounting";
		
		Query.SetParameter("Recorder",				Document);
		
		ResultQuery = Query.Execute();
		
		SelectionTypeOfAccounting = ResultQuery.Select(QueryResultIteration.ByGroups);
		
		Template 					= Reports.DocumentRegisterRecords.GetTemplate("Template");
		TemplateAccountingRegister	= Reports.DocumentRegisterRecords.GetTemplate("TemplateAccountingRegisterMaster");
		HeaderArea					= Template.GetArea("ReportHeader");
		AreaHeader					= TemplateAccountingRegister.GetArea("HeaderCompound");
		AreaDetails					= TemplateAccountingRegister.GetArea("DetailsCompound");
			
		While SelectionTypeOfAccounting.Next() Do
			
			Selection	= SelectionTypeOfAccounting.Select();
			NoHeader	= True;
			
			While Selection.Next() Do
				
				If NoHeader Then
					
					HeaderArea.Parameters.SynonymRegister = SynonymRegister + " (" + SelectionTypeOfAccounting.TypeOfAccounting + ")";
					SpreadsheetDocument.Put(HeaderArea);
					SpreadsheetDocument.StartRowGroup();
					
					SpreadsheetDocument.Put(AreaHeader);
					
					NoHeader = False;
					
				EndIf;
				
				FillPropertyValues(AreaDetails.Parameters, Selection);
				SpreadsheetDocument.Put(AreaDetails);
				
			EndDo;
			
			If Not NoHeader Then
				SpreadsheetDocument.EndRowGroup();
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// The procedure generates a report on server.
//
Function GenerateReport() Export
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	If Not ValueIsFilled(Document) Then
		CommonClientServer.MessageToUser(NStr("en = 'Document not selected.'; ru = 'Не выбран документ!';pl = 'Nie wybrano dokumentu.';es_ES = 'Documento no seleccionado.';es_CO = 'Documento no seleccionado.';tr = 'Belge seçilmedi.';it = 'Il documento non è selezionato.';de = 'Dokument nicht ausgewählt.'"));
		Return SpreadsheetDocument;
	EndIf;

	SetPrivilegedMode(True);

	Template				= Reports.DocumentRegisterRecords.GetTemplate("Template");
	DocumentRegisterRecords	= Document.Metadata().RegisterRecords;
	
	SortTableDocumentRegisterRecords = New ValueTable;
	SortTableDocumentRegisterRecords.Columns.Add("Name");
	SortTableDocumentRegisterRecords.Columns.Add("Object");
	
	EndTableDocumentRegisterRecords = New ValueTable;
	EndTableDocumentRegisterRecords.Columns.Add("Name");
	EndTableDocumentRegisterRecords.Columns.Add("Object");
	
	For Each PropertiesOfObject In DocumentRegisterRecords Do
		
		If PropertiesOfObject.Name = "AccountingEntriesData" Then
			
			NewRow = EndTableDocumentRegisterRecords.Add();
			NewRow.Name		= PropertiesOfObject.Name;
			NewRow.Object	= PropertiesOfObject;
			
		Else
			
			NewRow = SortTableDocumentRegisterRecords.Add();
			NewRow.Name		= PropertiesOfObject.Name;
			NewRow.Object	= PropertiesOfObject;
			
		EndIf;
		
	EndDo;
	
	// Title output
	HeaderArea = Template.GetArea("MainTitle");
	HeaderArea.Parameters.Document = String(Document);
	SpreadsheetDocument.Put(HeaderArea);

	// Registers search according to which there are movements
	RegisterRecordTable = DefineIfThereAreRegisterRecordsByRegistrator();
	
	AccountingRegisterMap = New Map;
	
	// Movements robin
	For Each SortPropertiesOfObject In SortTableDocumentRegisterRecords Do
		
		DoOutputRegister(SpreadsheetDocument, RegisterRecordTable, AccountingRegisterMap, SortPropertiesOfObject);
		
	EndDo;
	
	For Each RegisterItem In AccountingRegisterMap Do
		DoOutputPostingJournal(RegisterItem.Key, RegisterItem.Value, SpreadsheetDocument);
	EndDo;
	
	For Each Row In EndTableDocumentRegisterRecords Do
		
		DoOutputRegister(SpreadsheetDocument, RegisterRecordTable, AccountingRegisterMap, Row, True);
		
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction

Procedure DoOutputRegister(SpreadsheetDocument, RegisterRecordTable, AccountingRegisterMap, SortPropertiesOfObject, OutputAccountingRegister = False)
	
	PropertiesOfObject = SortPropertiesOfObject.Object;
	
	// Check whether there are movements on register
	RowInRegisterTable = RegisterRecordTable.Find(Upper(PropertiesOfObject.FullName()), "Name");
	
	If RowInRegisterTable = Undefined Then
		Return;
	EndIf;
	
	RegisterType = DefineRegisterKind(PropertiesOfObject);
	RegisterName = RegisterType + "Register." + PropertiesOfObject.Name;
	
	If RegisterType = "Information" Then
		SynonymRegister = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Information register ""%2""'; ru = 'Регистр сведений ""%2""';pl = 'Rejestr informacji ""%2""';es_ES = 'Registro de información ""%2""';es_CO = 'Registro de información ""%2""';tr = 'Bilgi kaydı ""%2""';it = 'Registro informazioni ""%2""';de = 'Informationsregister ""%2""'"),
		RegisterType,
		PropertiesOfObject.Synonym);
	ElsIf RegisterType = "Accumulation" Then
		SynonymRegister = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Accumulation register ""%2""'; ru = 'Регистр накопления ""%2""';pl = 'Rejestr akumulacji ""%2""';es_ES = 'Registro de acumulación ""%2""';es_CO = 'Registro de acumulación ""%2""';tr = 'Birikim kaydı ""%2""';it = 'Registro di accumulo ""%2""';de = 'Akkumulationsregister ""%2""'"),
		RegisterType,
		PropertiesOfObject.Synonym);
	ElsIf RegisterType = "Accounting" Then
		SynonymRegister = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Accounting register ""%2""'; ru = 'Регистр бухгалтерии ""%2""';pl = 'Rejestr rachunkowości ""%2""';es_ES = 'Registro de contabilidad ""%2""';es_CO = 'Registro de contabilidad ""%2""';tr = 'Muhasebe kaydı ""%2""';it = 'Registro contabile ""%2""';de = 'Buchhaltungsregister ""%2""'"),
		RegisterType,
		PropertiesOfObject.Synonym);
	ElsIf RegisterType = "Calculation" Then
		SynonymRegister = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Calculation register ""%2""'; ru = 'Регистр расчета ""%2""';pl = 'Rejestr kalkulacji ""%2""';es_ES = 'Registro de cálculo ""%2""';es_CO = 'Registro de cálculo ""%2""';tr = 'Hesap kaydı ""%2%2""';it = 'Registro di calcolo ""%2""';de = 'Berechnungsregister ""%2""'"),
		RegisterType,
		PropertiesOfObject.Synonym);
	EndIf;
	
	If RegisterType = "Information" OR RegisterType = "Accumulation" Then
		
		FieldList			= "";
		ResourcesTable		= New ValueTable;
		TableOfDimensions	= New ValueTable;
		AttributesTable		= New ValueTable;
		
		If RegisterType = "Information" And PropertiesOfObject.InformationRegisterPeriodicity = Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
		Else
			AddPeriodToFieldList(TableOfDimensions, FieldList);
		EndIf;
		GenerateFieldList(PropertiesOfObject.Resources,		ResourcesTable,		FieldList);
		GenerateFieldList(PropertiesOfObject.Dimensions,	TableOfDimensions,	FieldList);
		GenerateFieldList(PropertiesOfObject.Attributes,	AttributesTable,	FieldList);
		FieldList = Right(FieldList, StrLen(FieldList) - 2);
		
		AddAdditionalFieldsToFieldList(RegisterName, TableOfDimensions, FieldList); 
		
		If (RegisterType = "Accumulation") And (PropertiesOfObject.RegisterType = Metadata.ObjectProperties.AccumulationRegisterType.Balance) Then
			FieldList = FieldList + ", RecordType";
			TableKindOfMovements = New ValueTable;
			TableKindOfMovements.Columns.Add("RecordType", , NStr("en = 'Record type'; ru = 'Тип записи';pl = 'Rodzaj wpisu';es_ES = 'Tipo de registro';es_CO = 'Tipo de registro';tr = 'Kayıt türü';it = 'Tipo di registrazione';de = 'Satztyp'"));
			ProcessDataOutputByArray(FieldList, ResourcesTable, TableOfDimensions, AttributesTable, TableKindOfMovements, RegisterName, SynonymRegister, SpreadsheetDocument);
		Else
			ProcessDataOutputByArray(FieldList, ResourcesTable, TableOfDimensions, AttributesTable, , RegisterName, SynonymRegister, SpreadsheetDocument);
		EndIf; 
		
	ElsIf RegisterType = "Accounting" And OutputAccountingRegister Then
		
		DoOutputPostingJournal(RegisterName, SynonymRegister, SpreadsheetDocument);
		
	ElsIf RegisterType = "Accounting" Then
		
		AccountingRegisterMap.Insert(RegisterName, SynonymRegister);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf