
#Region ServiceProceduresAndFunctions

// :::Common

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	ColorSuccessResult = StyleColors.SuccessResultColor;
	ColorUnmappedItems = StyleColors.UnmappedItems;
	
	//DecorationUnmatchedRowsHeaderObject
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("CreateIfNotMatched");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorSuccessResult);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("DecorationUnmatchedRowsHeaderObject");
	FieldAppearance.Use = True;
	
	ItemAppearance.Presentation = NStr("en = 'Mapped items'; ru = 'Сопоставленные элементы';pl = 'Zmapowane elementy';es_ES = 'Artículos mapeados';es_CO = 'Artículos mapeados';tr = 'Eşlenmiş öğeler';it = 'Elementi mappati';de = 'Zugeordnete Elemente'");
	
	//DecorationUnmatchedRowsHeaderObject
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("CreateIfNotMatched");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorUnmappedItems);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("DecorationUnmatchedRowsHeaderObject");
	FieldAppearance.Use = True;
	
	ItemAppearance.Presentation = NStr("en = 'Unmapped items'; ru = 'Несопоставленные элементы';pl = 'Niezmapowane elementy';es_ES = 'Artículos no mapeados';es_CO = 'Artículos no mapeados';tr = 'Eşlenmemiş öğeler';it = 'Elementi non mappati';de = 'Nicht zugeordnete Elemente'");
	
EndProcedure

&AtServer
Procedure CreateFieldsTreeAvailableForUser()
	Var FieldsTree;
	
	DataProcessors.DataImportFromExternalSources.CreateFieldsTreeAvailableForUser(FieldsTree, Parameters.DataLoadSettings);
	FieldsTreeStorageAddress = PutToTempStorage(FieldsTree, UUID);
	
	Parameters.DataLoadSettings.Insert("FieldsTreeStorageAddress", FieldsTreeStorageAddress);
	
EndProcedure

&AtServer
Procedure GenerateDataCheckingPageTitle()
	
	NormalText = NStr("en = 'If 100 blank rows are found, the cheking stops.
	                  |While checking the spreadsheet'; 
	                  |ru = 'Если найдено 100 пустых строк, обработка следующих строк не выполняется.
	                  |При проверке заполнения табличного документа';
	                  |pl = 'Jeśli zostanie znaleziono 100 pustych wierszy, przetwarzanie następnych wierszy nie będzie wykonane.
	                  |Podczas sprawdzania arkusza kalkulacyjnego';
	                  |es_ES = 'Si 100 filas en blanco no se han encontrado, la revisión se para. 
	                  |Revisando la hoja de cálculo';
	                  |es_CO = 'Si 100 filas en blanco no se han encontrado, la revisión se para. 
	                  |Revisando la hoja de cálculo';
	                  |tr = '100 boş satır bulunursa, kontrol durur.
	                  | Elektronik tabloyu kontrol ederken';
	                  |it = 'Se 100 righe vuote sono trovate, il controllo si ferma.
	                  |Durante il controllo del foglio di calcolo';
	                  |de = 'Wenn 100 leere Zeilen gefunden werden, stoppt das Cheking.
	                  |Während der Überprüfung der Kalkulationstabelle'");
	
	BoldText = NStr("en = 'the following errors found:'; ru = 'обнаружены следующие ошибки:';pl = 'znaleziono następujące błędy:';es_ES = 'los siguientes errores se han encontrado:';es_CO = 'los siguientes errores se han encontrado:';tr = 'bulunan hatalar:';it = 'i seguenti errori sono stati trovati:';de = 'die folgenden Fehler gefunden:'");
	
	Font8N = New Font(Items.PictureToolTipDataChecks.Font, , 10, False);
	Font8B = New Font(Items.PictureToolTipDataChecks.Font, , 10, True);
	
	FormattedStringArray = New Array;
	FormattedStringArray.Add(New FormattedString(NormalText,	Font8N));
	FormattedStringArray.Add(New FormattedString(BoldText, 		Font8B));
	
	Items.PictureToolTipDataChecks.Title = New FormattedString(FormattedStringArray);
	
EndProcedure

&AtClient
Procedure ProccessAdditionalAttributeChoice(AdditionalAttribute)

	If AdditionalAttribute <> Undefined Then
		If Parameters.DataLoadSettings.SelectedAdditionalAttributes.Get(AdditionalAttribute) = Undefined Then
			
			Parameters.DataLoadSettings.SelectedAdditionalAttributes.Insert(AdditionalAttribute, Parameters.DataLoadSettings.AdditionalAttributeDescription.Get(AdditionalAttribute));
			
		EndIf;
	EndIf;

EndProcedure

&AtClient
Function ReceiveTitleArea()
	
	TitleArea = Items.SpreadsheetDocument.CurrentArea;
	If TitleArea.AreaType = SpreadsheetDocumentCellAreaType.Columns Then // missed, highlighted column
		
		TitleArea = SpreadsheetDocument.Area("R1" + TitleArea.Name);
		
	EndIf;
	
	Return TitleArea;
	
EndFunction

&AtClient
Procedure SpreadsheetDocumentDetailProcessing(Item, Details, StandardProcessing)
	
	StandardProcessing = False;
	
	If Items.SpreadsheetDocument.CurrentArea.AreaType = SpreadsheetDocumentCellAreaType.Columns 
		OR Items.SpreadsheetDocument.CurrentArea.AreaType = SpreadsheetDocumentCellAreaType.Rectangle Then
		
		If TypeOf(Details) = Type("ValueList") Then
			
			NotifyDescription = New NotifyDescription("ColumnTitleDetailsDataProcessor", ThisObject);
			
			TitleArea = ReceiveTitleArea();
			
			ImportParameters = New Structure;
			ImportParameters.Insert("DataLoadSettings",		Parameters.DataLoadSettings);
			ImportParameters.Insert("FieldPresentation",	TitleArea.Text);
			ImportParameters.Insert("FieldName",			TitleArea.DetailsParameter);
			ImportParameters.Insert("ColumnTitle",			TitleArea.Comment.Text);
			ImportParameters.Insert("ColumnNumber", 		TitleArea.Right);
			
			OpenForm("DataProcessor.DataImportFromExternalSources.Form.FieldChoice", ImportParameters, ThisObject, , , , NotifyDescription);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillMatchTableFilterChoiceList(IsTabularSectionImport)
	
	If Parameters.DataLoadSettings.IsTabularSectionImport
		Or Parameters.DataLoadSettings.IsAccountingEntriesImport Then
		
		Items.FilterComparisonTable.ChoiceList.Insert(1, "FilterNoErrors",	NStr("en = 'Ready for import'; ru = 'Данные, готовые к загрузке';pl = 'Gotowy do importu';es_ES = 'Preparado para la importación';es_CO = 'Preparado para la importación';tr = 'İçe aktarma için hazır';it = 'Pronto per l''importazione';de = 'Bereit für den Import'"));
		Items.FilterComparisonTable.ChoiceList.Insert(2, "FilterErrors", 	NStr("en = 'Impossible to import'; ru = 'Данные, которые загрузить невозможно';pl = 'Nie można importować';es_ES = 'Imposible para importar';es_CO = 'Imposible para importar';tr = 'İçe aktarma imkansız';it = 'Impossibile l''importazione';de = 'Import unmöglich'"));
		
	Else
		
		Items.FilterComparisonTable.ChoiceList.Insert(1, "Mapped", NStr("en = 'Matched'; ru = 'Данные, которые удалось сопоставить';pl = 'Dopasowany';es_ES = 'Emparejado';es_CO = 'Emparejado';tr = 'Eşleşti';it = 'Abbinato';de = 'Abgestimmt'"));
		Items.FilterComparisonTable.ChoiceList.Insert(1, "WillBeCreated", NStr("en = 'Data with no match in the database'; ru = 'Данные, которым не найдено соответствие в программе';pl = 'Dane bez dopasowania w aplikacji';es_ES = 'Datos sin coincidir en la base de datos';es_CO = 'Datos sin coincidir en la base de datos';tr = 'Veritabanında eşleşme olmayan veriler';it = 'Dati non abbinati nel database';de = 'Daten ohne Übereinstimmung in der Datenbank'"));
		Items.FilterComparisonTable.ChoiceList.Insert(1, "Inconsistent", NStr("en = 'Data containing error (incomplete)'; ru = 'Данные, которые содержат ошибку (заполнены не полностью)';pl = 'Dane zawierające błąd (niekompletne)';es_ES = 'Datos que contienen un error (incompleto)';es_CO = 'Datos que contienen un error (incompleto)';tr = 'Hata içeren veriler (eksik)';it = 'Dati contenenti errori (non completi)';de = 'Daten, die Fehler enthalten (unvollständig)'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetDecorationTitleTextUnmatchedRows()
	
	If CreateIfNotMatched Then
		
		HeaderText = ?(Parameters.DataLoadSettings.IsCatalogImport OR Parameters.DataLoadSettings.IsChartOfAccountsImport,
			NStr("en = 'new items to be created:'; ru = 'будет создано новых элементов:';pl = 'nowe elementy do utworzenia:';es_ES = 'nuevos artículos para crear:';es_CO = 'nuevos artículos para crear:';tr = 'oluşturulacak yeni öğeler:';it = 'nuovi elementi saranno creati:';de = 'neue zu erstellende Elemente:'"), 
			NStr("en = 'new records to be created:'; ru = 'будет создано новых записей:';pl = 'nowe zapisy do utworzenia:';es_ES = 'nuevas grabaciones para crear:';es_CO = 'nuevas grabaciones para crear:';tr = 'oluşturulacak yeni kayıtlar:';it = 'nuove registrazioni saranno create:';de = 'neue Datensätze werden erstellt:'"));
		
	Else
		HeaderText = NStr("en = 'rows will be skipped:'; ru = 'будет пропущено строк:';pl = 'zostaną pominięte wierszy:';es_ES = 'filas se saltarán:';es_CO = 'filas se saltarán:';tr = 'atlanacak satırlar:';it = 'righe che saranno ignorate:';de = 'Zeilen werden übersprungen:'");
	EndIf;
	
	If Parameters.DataLoadSettings.IsCatalogImport Then
		
		ItemName = "DecorationUnmatchedRowsHeaderObject";
		
	ElsIf Parameters.DataLoadSettings.IsChartOfAccountsImport Then
		
		ItemName = "DecorationUnmatchedRowsHeaderObjectChA";
		
	Else
		
		ItemName = "DecorationUnmatchedRowsHeaderIR";
		
	EndIf;
	
	Items[ItemName].Title = HeaderText;
	
EndProcedure

&AtClient
Procedure SetMatchedObjectsDecorationTitleText()
	
	TitleText = ?(UpdateExisting,
		NStr("en = 'among them are matched and will be updated'; ru = 'из них сопоставлены и будут обновлены';pl = 'wśród nich są dopasowane i będą aktualizowane';es_ES = 'entre ellos están emparejados y se actualizarán';es_CO = 'entre ellos están emparejados y se actualizarán';tr = 'aralarında eşleşti ve güncellenecek';it = 'di loro sono confrontati e saranno aggiornati';de = 'unter ihnen sind abgestimmt und werden aktualisiert'"),
		NStr("en = 'among them are matched'; ru = 'из них сопоставлены';pl = 'wśród nich są dopasowane';es_ES = 'entre ellos están emparejados';es_CO = 'entre ellos están emparejados';tr = 'aralarında eşleşti';it = 'tra i quali sono abbinati';de = 'unter ihnen sind abgestimmt'"));
	
	If Parameters.DataLoadSettings.IsCatalogImport Then
		
		ItemName = "DecorationMatchedHeaderObject";
		
	ElsIf Parameters.DataLoadSettings.IsChartOfAccountsImport Then
		
		ItemName = "DecorationMatchedHeaderObjectChA";
		
	Else
		
		ItemName = "DecorationMatchedHeaderIR";
		
	EndIf;
	
	Items[ItemName].Title = TitleText;
	
EndProcedure

&AtServer
Procedure ChangeConditionalDesignText()
	
	DataImportFromExternalSourcesOverridable.ChangeConditionalDesignText(ThisObject.ConditionalAppearance, Parameters.DataLoadSettings);
	
EndProcedure

&AtServer
Function CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress)
	
	CheckResult = New Structure("JobCompleted, Value", False, Undefined);
	If TimeConsumingOperations.JobCompleted(BackgroundJobID) Then
		
		CheckResult.JobCompleted	= True;
		SpreadsheetDocument			= GetFromTempStorage(BackgroundJobStorageAddress);
		
	EndIf;
	
	Return CheckResult;
	
EndFunction

&AtClient
Procedure CheckExecution()
	
	CheckResult = CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress);
	If CheckResult.JobCompleted Then
		
		ChangeGoToNumber(+1);
		
	Else	
		
		If BackgroundJobIntervalChecks < 15 Then
			
			BackgroundJobIntervalChecks = BackgroundJobIntervalChecks + 0.7;
			
		EndIf;
		
		AttachIdleHandler("CheckExecution", BackgroundJobIntervalChecks, True);
		
	EndIf;
	
EndProcedure

// :::PageDataImport

&AtServer
Procedure ImportFileWithDataToTabularDocumentOnServer(GoToNext)
	
	Extension = CommonClientServer.ExtensionWithoutPoint(CommonClientServer.GetFileNameExtension(NameOfSelectedFile));
	
	TempFileName	= GetTempFileName(Extension);
	BinaryData = GetFromTempStorage(TemporaryStorageAddress);
	
	If BinaryData = Undefined Then
		Return;
	Else
		BinaryData.Write(TempFileName);
	EndIf;
	
	SpreadsheetDocument.Clear();
	DataMatchingTable.Clear();
	
	ServerCallParameters = New Structure;
	ServerCallParameters.Insert("TempFileName",			TempFileName);
	ServerCallParameters.Insert("Extension", 			Extension);
	ServerCallParameters.Insert("SpreadsheetDocument",	SpreadsheetDocument);
	ServerCallParameters.Insert("DataLoadSettings",		Parameters.DataLoadSettings);
	
	If Common.FileInfobase() Then
		
		DataImportFromExternalSources.ImportData(ServerCallParameters, TemporaryStorageAddress);
		SpreadsheetDocument = GetFromTempStorage(TemporaryStorageAddress);
		
	Else
		
		MethodName = "DataImportFromExternalSources.ImportData";
		Description = NStr("en = 'The ImportDataFromExternalSource subsystem: Execution of the server procedure to import data from file'; ru = 'Подсистема ImportDataFromExternalSource: Выполнение серверного метода загрузка данных из файла';pl = 'Podsystem ImportDataFromExternalSource: Wykonanie procedury serwera w celu zaimportowania danych z pliku';es_ES = 'El subsistema ImportDataFromExternalSource: Ejecución del procedimiento del servidor para importar los datos del archivo';es_CO = 'El subsistema ImportDataFromExternalSource: Ejecución del procedimiento del servidor para importar los datos del archivo';tr = 'ImportDataFromExternalSource alt sistemi: Dosyadan veri almak için sunucu prosedürünün yürütülmesi';it = 'Il sottosistema ImportDataFromExternalSource: Esecuzione della procedura server per importare i dati dal file';de = 'Das Subsystem DatenVonExternerQuelleImportieren: Ausführung der Serverprozedur zum Importieren von Daten aus einer Datei'");
		ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
		ExecutionParameters.BackgroundJobDescription = Description;
		
		BackgroundJobResult = TimeConsumingOperations.ExecuteInBackground(MethodName, ServerCallParameters, ExecutionParameters);
		
		If BackgroundJobResult.Status = "Completed" Then
			
			BackgroundJobStorageAddress = BackgroundJobResult.ResultAddress;
			SpreadsheetDocument = GetFromTempStorage(BackgroundJobStorageAddress);
			
		Else 
			
			GoToNext = False;
			BackgroundJobID  = BackgroundJobResult.JobID;
			BackgroundJobStorageAddress = BackgroundJobResult.ResultAddress;
			
		EndIf;
		
	EndIf;
	
	If ImportStartingRow > 1 Then
		DeletedArea = SpreadsheetDocument.Area(2, , ImportStartingRow);
		SpreadsheetDocument.DeleteArea(DeletedArea, SpreadsheetDocumentShiftType.Vertical);
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteDataImportAtServer(GoToNext)
	
	DataProcessors.DataImportFromExternalSources.AddMatchTableColumns(ThisObject, DataMatchingTable, Parameters.DataLoadSettings);
	If Parameters.DataLoadSettings.ManualFilling = True Then
		
		DataImportFromExternalSources.FillInDetailsInTabularDocument(SpreadsheetDocument,
			DataImportFromExternalSourcesOverridable.MaximumOfUsefulColumnsTableDocument(), Parameters.DataLoadSettings);
		CommonClientServer.SetFormItemProperty(Items, "SpreadsheetDocument", "Edit", True);
		
	Else
		
		ImportFileWithDataToTabularDocumentOnServer(GoToNext);
		
	EndIf;
	
EndProcedure

// :::PagesDataCheck

&AtServer
Procedure AddAdditionalAttributesInMatchingTable(DataLoadSettings)
	
	DataProcessors.DataImportFromExternalSources.AddAdditionalAttributes(ThisObject, Parameters.DataLoadSettings.SelectedAdditionalAttributes);
	
EndProcedure

&AtServer
Procedure CheckReceivedData(SkipPage, DenyTransitionNext)
	
	If Parameters.DataLoadSettings.Property("SelectedAdditionalAttributes")
		AND Parameters.DataLoadSettings.SelectedAdditionalAttributes.Count() > 0 Then
		
		AddAdditionalAttributesInMatchingTable(Parameters.DataLoadSettings);
		
	EndIf;
	
	DataProcessors.DataImportFromExternalSources.PreliminarilyDataProcessor(SpreadsheetDocument, DataMatchingTable, Parameters.DataLoadSettings, SpreadsheetDocumentMessages, SkipPage, DenyTransitionNext);
	
EndProcedure

// :::PageMatch

&AtServer
Procedure AddNewMatch(TableRow)
	
	If Not Parameters.DataLoadSettings.Property("Supplier") Then
		Return;
	EndIf;
	
	NewSupplierProduct = Catalogs.SuppliersProducts.CreateItem();
	NewSupplierProduct.Products		= TableRow.Products;
	NewSupplierProduct.Description	= TableRow.ProductsDescription;
	NewSupplierProduct.Owner		= Parameters.DataLoadSettings.Supplier;
	
	Try
		NewSupplierProduct.Write();
	Except
		CommonClientServer.MessageToUser(ErrorDescription());
	EndTry;
	
EndProcedure

&AtServer
Procedure CheckDataCorrectnessInTableRow(RowFormID)
	
	Var Manager;
	
	FormTableRow = DataMatchingTable.FindByID(RowFormID);
	
	AddNewMatch(FormTableRow);
	
	DataImportFromExternalSourcesOverridable.CheckDataCorrectnessInTableRow(
		FormTableRow, Parameters.DataLoadSettings.FillingObjectFullName, Parameters.DataLoadSettings);
	
EndProcedure

&AtClient
Procedure SetRowsQuantityDecorationText()
	
	TableRowCount		= DataMatchingTable.Count();
	RowsQuantityWithoutErrors	= DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", True)).Count();
	If Not Parameters.DataLoadSettings.IsTabularSectionImport
		And Not Parameters.DataLoadSettings.IsAccountingEntriesImport Then
		
		UnmatchedData = DataMatchingTable.FindRows(New Structure("_RowMatched", False)).Count();
		InconsistentData = DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", False)).Count();
		
	EndIf;
	
	NewHeader 				= "";
	
	If FilterComparisonTable = "WithoutFilter" Then 
		
		NewHeader = NStr("en = 'Total number of rows: %1'; ru = 'Всего строк в таблице: %1';pl = 'Całkowita liczba wierszy: %1';es_ES = 'Número total de filas: %1';es_CO = 'Número total de filas: %1';tr = 'Toplam satır sayısı: %1';it = 'Numero totale di righe: %1';de = 'Gesamtzahl der Zeilen: %1'");
		ParameterValue = TableRowCount;
		
	ElsIf FilterComparisonTable = "FilterNoErrors" Then 
		
		NewHeader = NStr("en = 'Rows to be imported in the database: %1'; ru = 'Строк с данными, которые возможно загрузить в приложение: %1';pl = 'Wiersze do zaimportowania do bazy danych: %1';es_ES = 'Filas para importar en la base datos: %1';es_CO = 'Filas para importar en la base datos: %1';tr = 'Veritabanında içe aktarılacak satırlar: %1';it = 'Righe da importare nel database: %1';de = 'Zeilen, die in die Datenbank importiert werden sollen: %1'");
		ParameterValue = RowsQuantityWithoutErrors;
		
	ElsIf FilterComparisonTable = "FilterErrors" Then 
		
		NewHeader = NStr("en = 'Rows containing errors: %1'; ru = 'Строки, содержащие ошибки и препятствующие загрузке данных: %1';pl = 'Wiersze zawierające błędy: %1';es_ES = 'Filas que contienen algunos errores: %1';es_CO = 'Filas que contienen algunos errores: %1';tr = 'Hata içeren satırlar: %1';it = 'Righe contenti errori: %1';de = 'Zeilen mit Fehlern: %1'");
		ParameterValue = TableRowCount - RowsQuantityWithoutErrors;
		
	ElsIf FilterComparisonTable = "Mapped" Then 
		
		If UpdateExisting Then
			
			NewHeader = NStr("en = 'Matched data will be updated: %1'; ru = 'Данные, которые соответствуют элементам программы и будут обновлены: %1';pl = 'Dopasowane dane zostaną zaktualizowane: %1';es_ES = 'Datos emparejados se actualizarán: %1';es_CO = 'Datos emparejados se actualizarán: %1';tr = 'Eşleşen veriler güncellenecek: %1';it = 'I dati abbinati saranno aggiornati: %1';de = 'Abgestimmte Daten werden aktualisiert: %1'");
			
		Else
			
			NewHeader = NStr("en = 'Data matched: %1'; ru = 'Данные, которые соответствуют элементам программы: %1';pl = 'Dane dopasowane: %1';es_ES = 'Datos emparejados: %1';es_CO = 'Datos emparejados: %1';tr = 'Eşleşen veriler:%1';it = 'Dati abbinati: %1';de = 'Daten abgestimmt: %1'");
			
		EndIf;
		
		ParameterValue = TableRowCount - UnmatchedData;
		
	ElsIf FilterComparisonTable = "WillBeCreated" Then 
		
		NewHeader = NStr("en = 'Data not mapped: %1'; ru = 'Данные, которые не удалось сопоставить: %1';pl = 'Dane nie dopasowane: %1';es_ES = 'Datos no mapeado: %1';es_CO = 'Datos no mapeado: %1';tr = 'Eşleşmeyen veriler: %1';it = 'Dati non abbinati: %1';de = 'Daten nicht zugeordnet: %1'");
		ParameterValue = UnmatchedData;
		
	ElsIf FilterComparisonTable = "Inconsistent" Then 
		
		NewHeader = NStr("en = 'Rows containing errors or incomplete: %1'; ru = 'Строки, которые содержат ошибку либо заполнены не полностью: %1';pl = 'Wiersze, zawierające błędy lub niekompletne: %1';es_ES = 'Filas que contienen errores o son incompletas: %1';es_CO = 'Filas que contienen errores o son incompletas: %1';tr = 'Hata içeren veya eksik satırlar:%1';it = 'Le righe contengono errori o sono incomplete: %1';de = 'Zeilen mit Fehlern oder unvollständig: %1'");
		ParameterValue = InconsistentData;
		
	EndIf;
	
	NewHeader = StringFunctionsClientServer.SubstituteParametersToString(NewHeader, ParameterValue);
	Items.DecorationLineCount.Title = NewHeader;
	
EndProcedure

&AtClient
Procedure SetRowsQuantityDecorationTextTS()
	
	AddPossible = DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", True)).Count();
	AddImpossible = DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", False)).Count();
	
	Items.DecorationWillBeImportedCount.Title = String(AddPossible);
	Items.DecorationWillBeSkippedCount.Title = String(AddImpossible);
	
EndProcedure

&AtClient
Procedure SetRowsFilterByFilterValue()
	
	If FilterComparisonTable = "WithoutFilter" Then
		
		Items.DataMatchingTable.RowFilter = Undefined;
		
	ElsIf FilterComparisonTable = "FilterNoErrors" Then
		
		Items.DataMatchingTable.RowFilter = New FixedStructure(ServiceFieldName, True);
		
	ElsIf FilterComparisonTable = "FilterErrors" Then
		
		Items.DataMatchingTable.RowFilter = New FixedStructure(ServiceFieldName, False);
		
	ElsIf FilterComparisonTable = "Mapped" Then
		
		Items.DataMatchingTable.RowFilter = New FixedStructure("_RowMatched", True);
		
	ElsIf FilterComparisonTable = "WillBeCreated" Then
		
		If Parameters.DataLoadSettings.IsCatalogImport OR Parameters.DataLoadSettings.IsChartOfAccountsImport Then
			
			FixedRowsFilterStructure = New FixedStructure("_ImportToApplicationPossible, _RowMatched", True, False);
			Items.DataMatchingTable.RowFilter = FixedRowsFilterStructure;
			
		ElsIf Parameters.DataLoadSettings.IsInformationRegisterImport Then
			
			FixedRowsFilterStructure = New FixedStructure("_ImportToApplicationPossible, _RowMatched", True, False);
			Items.DataMatchingTable.RowFilter = FixedRowsFilterStructure;
			
		EndIf;
		
	ElsIf FilterComparisonTable = "Inconsistent" Then
		
		Items.DataMatchingTable.RowFilter = New FixedStructure("_ImportToApplicationPossible", False);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ExportedDataComparison()
	Var Manager;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("DataLoadSettings", Parameters.DataLoadSettings);
	
	DataImportFromExternalSourcesOverridable.MatchImportedDataFromExternalSource(DataMatchingTable, Parameters.DataLoadSettings);
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Var Manager;
	
	//Conditional appearance
	SetConditionalAppearance();
	
	DataImportFromExternalSources.GetManagerByFillingObjectName(Parameters.DataLoadSettings.FillingObjectFullName, Manager);
	
	ServiceFieldName = DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible();
	
	Parameters.DataLoadSettings.Insert("UpdateExisting", False);
	
	If Parameters.DataLoadSettings.Property("CreateIfNotMatched") Then
		CreateIfNotMatched = Parameters.DataLoadSettings.CreateIfNotMatched;
	Else
		If Parameters.DataLoadSettings.IsTabularSectionImport Then
			CreateIfNotMatched = False;
			If Parameters.DataLoadSettings.FillingObjectFullName = "Document.SalesTarget.TabularSection.Inventory"
				Or Parameters.DataLoadSettings.FillingObjectFullName = "Document.RequestForQuotation.TabularSection.Suppliers" Then
				Items.CreateIfNotMatchedTS.Visible = False;
			EndIf;
		Else
			CreateIfNotMatched = True;
		EndIf;
		Parameters.DataLoadSettings.Insert("CreateIfNotMatched", CreateIfNotMatched);
	EndIf;
	
	Parameters.DataLoadSettings.Insert("ManualFilling", False);
	
	If Parameters.DataLoadSettings.IsInformationRegisterImport  
		AND Not Parameters.DataLoadSettings.Property("CommonValue") Then
		
		CommonClientServer.SetFormItemProperty(Items, "DecorationKeyValueIRHeader", "Visible", False);
		CommonClientServer.SetFormItemProperty(Items, "CommonValueIR", "Visible", False);
		CommonClientServer.SetFormItemProperty(Items, "ClearCommonValueIR", "Visible", False);
		
	EndIf;
	
	CommonClientServer.SetFormItemProperty(Items, "Group4", "Visible", Not CommonClientServer.IsWebClient());
	CommonClientServer.SetFormItemProperty(Items, "Group5", "Visible", Not CommonClientServer.IsWebClient());
	
	If Parameters.DataLoadSettings.Property("IsChartOfAccountsImport")
		And Parameters.DataLoadSettings.IsChartOfAccountsImport
		And Parameters.DataLoadSettings.FillingObjectFullName = Metadata.ChartsOfAccounts.MasterChartOfAccounts.FullName() Then
		
		IsChartOfAccountsImport = Parameters.DataLoadSettings.IsChartOfAccountsImport;
		
		CommonClientServer.SetFormItemProperty(Items,
			"DecorationChartOfAccountParentHeader",
			"Visible",
			Not IsChartOfAccountsImport);
		CommonClientServer.SetFormItemProperty(Items,
			"CommonValueChartOfAccounts",
			"Visible",
			Not IsChartOfAccountsImport);
		CommonClientServer.SetFormItemProperty(Items,
			"ClearChartOfAccountCommonValue",
			"Visible",
			Not IsChartOfAccountsImport);
		
	EndIf;
	
	CreateFieldsTreeAvailableForUser();
	
	GenerateDataCheckingPageTitle();
	
	ImportStartingRow = 1;
	
	TextDoNotImport = NStr("en = 'Do not import'; ru = 'Не загружать';pl = 'Nie importować';es_ES = 'No importar';es_CO = 'No importar';tr = 'İçe aktarma';it = 'Non importare';de = 'Nicht importieren'");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FillMatchTableFilterChoiceList(Parameters.DataLoadSettings.IsTabularSectionImport);
	
	SetDecorationTitleTextUnmatchedRows();
	SetMatchedObjectsDecorationTitleText();
	
	// Set the current table of transitions
	TableOfGoToByScript();
	
	// Position at the assistant's first step
	SetGoToNumber(1);
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

&AtClient
Procedure FilterComparisonTableOnChange(Item)
	
	SetRowsFilterByFilterValue();
	SetRowsQuantityDecorationText();
	
	CurrentItem = Items.DataMatchingTable;
	
EndProcedure

&AtClient
Procedure CreateIfNotMatchedOnChange(Item)
	
	Parameters.DataLoadSettings.Insert("CreateIfNotMatched", CreateIfNotMatched);
	
	SetDecorationTitleTextUnmatchedRows();
	
	ChangeConditionalDesignText();
	
EndProcedure

&AtClient
Procedure DataMatchingTableOnChange(Item)
	
	RowFormID = Items.DataMatchingTable.CurrentData.GetID();
	CheckDataCorrectnessInTableRow(RowFormID);
	SetRowsQuantityDecorationText();
	
EndProcedure

&AtClient
Procedure SpreadsheetDocumentOnActivate(Item)
	
	Item.Protection = Not (Item.CurrentArea.Top > 1);
	
EndProcedure

&AtClient
Procedure CreateIfNotMatchedTSOnChange(Item)
	
	Parameters.DataLoadSettings.Insert("CreateIfNotMatched", CreateIfNotMatched);
	
	For Each DataMatchingTableRow In DataMatchingTable Do
		RowFormID = DataMatchingTableRow.GetID();
		CheckDataCorrectnessInTableRow(RowFormID);
	EndDo;
	SetRowsQuantityDecorationTextTS();
	
EndProcedure

&AtClient
Procedure MappingTemplatePresentationClick(Item)
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	Filter = New Structure;
	Filter.Insert("FillingObjectFullName", Parameters.DataLoadSettings.FillingObjectFullName);
	FormParameters.Insert("Filter", Filter);
	
	NotifyDescription = New NotifyDescription("OnMappingTemplateSelect", ThisObject);
	
	OpenForm("Catalog.DataImportFromExternalSourcesMappingTemplates.ChoiceForm",
		FormParameters, ThisObject, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandNext(Command)
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure CommandBack(Command)
	
	Step = -1;
	If Items.MainPanel.CurrentPage = Items.PagePreliminarilyTS
		OR Items.MainPanel.CurrentPage = Items.PagePreliminaryCatalog
		OR Items.MainPanel.CurrentPage = Items.PagePreliminarilyInformationRegister Then
		
		Step = -2;
		
	EndIf;
	
	ChangeGoToNumber(Step);
	
EndProcedure

&AtClient
Procedure CommandDone(Command)
	
	ForceCloseForm = True;
	
	ClosingResult = New Structure;
	ClosingResult.Insert("ActionsDetails",		"ProcessPreparedData");
	ClosingResult.Insert("DataMatchingTable",	DataMatchingTable);
	ClosingResult.Insert("DataLoadSettings",	Parameters.DataLoadSettings);
	
	NotifyChoice(ClosingResult);
	Notify("ProcessPreparedData", ClosingResult);
	
EndProcedure

&AtClient
Procedure CommandCancel(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_WithoutFilter(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("WithoutFilter");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_WillBeCreated(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("WillBeCreated");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_InconsistentData(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("Inconsistent");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_FilterNoErrors(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("FilterNoErrors");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_FilterErrors(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("FilterErrors");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_Mapped(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("Mapped");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure CommonValue(Command)
	
	DataImportFromExternalSourcesClientOverridable.OnSetGeneralValue(ThisObject, Parameters.DataLoadSettings, DataMatchingTable);
	
EndProcedure

&AtClient
Procedure ClearCommonValue(Command)
	
	DataImportFromExternalSourcesClientOverridable.OnClearGeneralValue(ThisObject, Parameters.DataLoadSettings, DataMatchingTable);
	
EndProcedure

&AtClient
Procedure UpdateExistingOnChange(Item)
	
	Parameters.DataLoadSettings.Insert("UpdateExisting", UpdateExisting);
	
	SetMatchedObjectsDecorationTitleText();
	
EndProcedure

&AtClient
Procedure MappingTemplateSave(Command)
	
	If ColumnsMapped() Then
		If ValueIsFilled(MappingTemplate) Then
			SaveMappingTemplate();
		Else
			InputNewMappingTemplateDescription();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure MappingTemplateSaveAs(Command)
	
	If ColumnsMapped() Then
		InputNewMappingTemplateDescription();
	EndIf;
	
EndProcedure

#EndRegion

#Region InteractiveActionResultHandlers

&AtClient
Procedure SelectExternalFileDataProcessorEnd(PlacedFiles, AdditionalParameters) Export
	
	If PlacedFiles <> Undefined Then
		TemporaryStorageAddress	= PlacedFiles[0].Location;
		NameOfSelectedFile 		= PlacedFiles[0].Name;
		Extension 				= CommonClientServer.ExtensionWithoutPoint(CommonClientServer.GetFileNameExtension(NameOfSelectedFile));
		
		ChangeGoToNumber(+1);
	EndIf;
	
EndProcedure

&AtClient
Procedure ColumnTitleDetailsDataProcessor(Result, AdditionalParameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		
		ProccessAdditionalAttributeChoice(Result.AdditionalAttribute);
		
		TitleArea = ReceiveTitleArea();
		
		TitleArea.Text 				= Result.Presentation;
		TitleArea.DetailsParameter	= Result.Value;
		
		If Result.Property("CancelSelectionInColumn") Then
			TitleArea.Text 				= TextDoNotImport;
			TitleArea.DetailsParameter	= "";
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnMappingTemplateSelect(Result, AdditionalParameters) Export
	
	If ValueIsFilled(Result) Then
		
		MappingTemplate = Result;
		Items.MappingTemplatePresentation.Title = String(MappingTemplate);
		
		ApplySelectedMappingTemplate();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnMappingTemplateDescriptionInput(Result, AdditionalParameters) Export
	If ValueIsFilled(Result) Then
		SaveNewMappingTemplate(Result);
	EndIf;
EndProcedure

#EndRegion

#Region MappingTemplates

&AtClient
Function ColumnsMapped()
	
	MaxColumns = DataImportFromExternalSourcesOverridable.MaximumOfUsefulColumnsTableDocument();
	
	For Col = 1 To MaxColumns Do
		TitleArea = SpreadsheetDocument.Area("R1C" + Col);
		If Not IsBlankString(TitleArea.DetailsParameter) Then
			Return True;
		EndIf;
	EndDo;
	
	MessageText = NStr("en = 'Map at least one column.'; ru = 'Сопоставьте, как минимум, одну колонку.';pl = 'Mapuj przynajmniej jedną kolumnę.';es_ES = 'Mapear al menos una columna.';es_CO = 'Mapear al menos una columna.';tr = 'En az bir sütunu eşle.';it = 'Mappare almeno una colonna.';de = 'Zumindest eine Spalte zuordnen.'");
	CommonClientServer.MessageToUser(MessageText, , "SpreadsheetDocument");
	
	Return False;
	
EndFunction

&AtClient
Procedure InputNewMappingTemplateDescription()
	
	NotifyDescription = New NotifyDescription("OnMappingTemplateDescriptionInput", ThisObject);
	
	If ValueIsFilled(MappingTemplate) Then
		MTDescription = String(MappingTemplate);
	Else
		MTDescription = "";
	EndIf;
	
	TooltipText = NStr("en = 'New mapping template description'; ru = 'Наименование нового шаблона сопоставления';pl = 'Opis szablonu nowego mapowania';es_ES = 'Nueva descripción de la plantilla de mapeo';es_CO = 'Nueva descripción de la plantilla de mapeo';tr = 'Yeni eşleme şablonu açıklaması';it = 'Descrizione nuovo modello di mappatura';de = 'Neue Beschreibung der Mappingvorlagen'");
	
	ShowInputString(NotifyDescription, MTDescription, TooltipText, 100, False);
	
EndProcedure

&AtServer
Procedure SaveNewMappingTemplate(Description)
	
	MTObject = Catalogs.DataImportFromExternalSourcesMappingTemplates.CreateItem();
	MTObject.Description = Description;
	MTObject.FillingObjectFullName = Parameters.DataLoadSettings.FillingObjectFullName;
	
	If FillAndWriteMappingTemplate(MTObject) Then
		
		MappingTemplate = MTObject.Ref;
		Items.MappingTemplatePresentation.Title = Description;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SaveMappingTemplate()
	
	MTObject = MappingTemplate.GetObject();
	MTObject.Fields.Clear();
	FillAndWriteMappingTemplate(MTObject);
	
EndProcedure

&AtServer
Function FillAndWriteMappingTemplate(MTObject)
	
	MaxColumns = DataImportFromExternalSourcesOverridable.MaximumOfUsefulColumnsTableDocument();
	
	BlanksCount = 0;
	
	For Col = 1 To MaxColumns Do
		TitleArea = SpreadsheetDocument.Area("R1C" + Col);
		If Not IsBlankString(TitleArea.DetailsParameter) Then
			If BlanksCount > 0 Then
				For BlanksCounter = 1 To BlanksCount Do
					MTField = MTObject.Fields.Add();
					MTField.Name = "";
					MTField.Presentation = TextDoNotImport;
				EndDo;
				BlanksCount = 0;
			EndIf;
			MTField = MTObject.Fields.Add();
			MTField.Name = TitleArea.DetailsParameter;
			MTField.Presentation = TitleArea.Text;
		Else
			BlanksCount = BlanksCount + 1;
		EndIf;
	EndDo;
	
	Try
		MTObject.Write();
		Return True;
	Except
		CommonClientServer.MessageToUser(ErrorDescription());
		Return False;
	EndTry;
	
EndFunction

&AtServer
Procedure ApplySelectedMappingTemplate()
	
		ManualFilling = Parameters.DataLoadSettings.ManualFilling;
		If ManualFilling Then
			MaxColumns = DataImportFromExternalSourcesOverridable.MaximumOfUsefulColumnsTableDocument();
		Else
			MaxColumns = SpreadsheetDocument.TableWidth;
		EndIf;
		
		MTData = GetMappingTemplateData(MappingTemplate);
		MTDataCount = MTData.Count();
		
		FieldsTree = GetFromTempStorage(Parameters.DataLoadSettings.FieldsTreeStorageAddress);
		For Each FieldsTreeRow In FieldsTree.Rows Do
			FieldsTreeRow.ColumnNumber = 0;
			FieldsTreeRow.ColorNumber  = FieldsTreeRow.ColorNumberOriginal;
			If Not IsBlankString(FieldsTreeRow.FieldsGroupName) Then
				For Each FieldsTreeSubRow In FieldsTreeRow.Rows Do
					FieldsTreeSubRow.ColumnNumber = 0;
					FieldsTreeSubRow.ColorNumber  = FieldsTreeSubRow.ColorNumberOriginal;
				EndDo;
			EndIf;
		EndDo;
		
		For Col = 1 To Min(MaxColumns, MTDataCount) Do
			
			FieldData = MTData[Col - 1];
			
			TitleArea = SpreadsheetDocument.Area("R1C" + Col);
			
			If Not IsBlankString(FieldData.Name) Then
				FieldsTreeRow = FieldsTree.Rows.Find(FieldData.Name, "FieldName", True);
				If FieldsTreeRow = Undefined Then
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Field #%1 %2 (%3) is not valid'; ru = 'Поле №%1 %2 (%3) не допустимо';pl = 'Pole nr %1 %2 (%3) jest nieważny';es_ES = 'El campo #%1 %2 (%3) es inválido';es_CO = 'El campo #%1 %2 (%3) es inválido';tr = '#%1%2 (%3) alanı geçerli değil';it = 'Il campo #%1 %2 (%3) non è valido';de = 'Feld #%1 %2 (%3) ist ungültig'"),
						Col,
						FieldData.Presentation,
						FieldData.Name);
					TitleArea.DetailsParameter	= "";
					TitleArea.Text = "<" + NStr("en = 'not valid'; ru = 'не допустимо';pl = 'nie ważny';es_ES = 'no válido';es_CO = 'no válido';tr = 'geçerli değil';it = 'Non valido';de = 'Nicht gültig'") + ">" + FieldData.Presentation;
				Else
					FieldsTreeRow.ColumnNumber	= Col;
					FieldsTreeRow.ColorNumber	= 3;
					TitleArea.DetailsParameter	= FieldsTreeRow.FieldName;
					
					If FieldsTreeRow.Parent <> Undefined Then
						TitleArea.Text = StrTemplate("%1 (%2)", FieldsTreeRow.FieldPresentation, FieldsTreeRow.Parent.FieldPresentation);
					Else
						TitleArea.Text = FieldsTreeRow.FieldPresentation;
					EndIf;
				EndIf;
			Else
				TitleArea.DetailsParameter	= FieldData.Name;
				If IsBlankString(FieldData.Presentation) Then
					TitleArea.Text = TextDoNotImport;
				Else
					TitleArea.Text = FieldData.Presentation;
				EndIf;
			EndIf;
			
		EndDo;
		
		For Col = MTDataCount + 1 To MaxColumns Do
			
			TitleArea = SpreadsheetDocument.Area("R1C" + Col);
			TitleArea.Text 				= TextDoNotImport;
			TitleArea.DetailsParameter	= "";
			
		EndDo;
	
EndProcedure

&AtServerNoContext
Function GetMappingTemplateData(MappingTemplate)
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	MappingTemplatesFields.Name AS Name,
	|	MappingTemplatesFields.Presentation AS Presentation
	|FROM
	|	Catalog.DataImportFromExternalSourcesMappingTemplates.Fields AS MappingTemplatesFields
	|WHERE
	|	MappingTemplatesFields.Ref = &Ref";
	
	Query.SetParameter("Ref", MappingTemplate);
	
	Result = New Array;
	
	Sel = Query.Execute().Select();
	While Sel.Next() Do
		
		FieldData = New Structure("Name, Presentation");
		FillPropertyValues(FieldData, Sel);
		Result.Add(FieldData);
		
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions_SuppliedPart

&AtClient
Procedure ChangeGoToNumber(Iterator)
	
	ClearMessages();
	
	SetGoToNumber(GoToNumber + Iterator);
	
EndProcedure

&AtClient
Procedure SetGoToNumber(Val Value)
	
	IsGoNext = (Value > GoToNumber);
	
	GoToNumber = Value;
	
	If GoToNumber < 0 Then
		
		GoToNumber = 0;
		
	EndIf;
	
	GoToNumberOnChange(IsGoNext);
	
EndProcedure

&AtClient
Procedure GoToNumberOnChange(Val IsGoNext)
	
	// Executing the step change event handlers
	ExecuteGoToEventHandlers(IsGoNext);
	
	// Setting page visible
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page to display is not defined.'; ru = 'Не определена страница для отображения.';pl = 'Strona do wyświetlenia nie jest zdefiniowana.';es_ES = 'Página para visualizar no está definida.';es_CO = 'Página para visualizar no está definida.';tr = 'Gösterilecek sayfa tanımlanmamış.';it = 'La pagina da visualizzare non è definita';de = 'Die anzuzeigende Seite ist nicht definiert.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.MainPanel.CurrentPage  = Items[GoToRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[GoToRowCurrent.NavigationPageName];
	
	// Set current button by default
	ButtonNext = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandNext");
	
	If ButtonNext <> Undefined Then
		
		ButtonNext.DefaultButton = True;
		
	Else
		
		DoneButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandDone");
		
		If DoneButton <> Undefined Then
			
			DoneButton.DefaultButton = True;
			
		EndIf;
		
	EndIf;
	
	If IsGoNext AND GoToRowCurrent.LongAction Then
		
		AttachIdleHandler("ExecuteLongOperationHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
	// Transition events handlers
	If IsGoNext Then
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber - 1));
		
		If GoToRows.Count() > 0 Then
			
			GoToRow = GoToRows[0];
			
			// handler OnGoingNext
			If Not IsBlankString(GoToRow.GoNextHandlerName)
				AND Not GoToRow.LongAction Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoNextHandlerName);
				
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber - 1);
					
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	Else
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber + 1));
		
		If GoToRows.Count() > 0 Then
			
			GoToRow = GoToRows[0];
			
			// handler OnGoingBack
			If Not IsBlankString(GoToRow.GoBackHandlerName)
				AND Not GoToRow.LongAction Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoBackHandlerName);
				
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber + 1);
					
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page to display is not defined.'; ru = 'Не определена страница для отображения.';pl = 'Strona do wyświetlenia nie jest zdefiniowana.';es_ES = 'Página para visualizar no está definida.';es_CO = 'Página para visualizar no está definida.';tr = 'Gösterilecek sayfa tanımlanmamış.';it = 'La pagina da visualizzare non è definita';de = 'Die anzuzeigende Seite ist nicht definiert.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	If GoToRowCurrent.LongAction AND Not IsGoNext Then
		
		SetGoToNumber(GoToNumber - 1);
		Return;
	EndIf;
	
	// handler OnOpen
	If Not IsBlankString(GoToRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, SkipPage, IsGoNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.OnOpenHandlerName);
		
		Cancel = False;
		SkipPage = False;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf SkipPage Then
			
			If IsGoNext Then
				
				SetGoToNumber(GoToNumber + 1);
				
				Return;
				
			Else
				
				SetGoToNumber(GoToNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteLongOperationHandler()
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page to display is not defined.'; ru = 'Не определена страница для отображения.';pl = 'Strona do wyświetlenia nie jest zdefiniowana.';es_ES = 'Página para visualizar no está definida.';es_CO = 'Página para visualizar no está definida.';tr = 'Gösterilecek sayfa tanımlanmamış.';it = 'La pagina da visualizzare non è definita';de = 'Die anzuzeigende Seite ist nicht definiert.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	// handler LongOperationHandling
	If Not IsBlankString(GoToRowCurrent.LongOperationHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.LongOperationHandlerName);
		
		Cancel = False;
		GoToNext = True;
		
		Try
			A = Eval(ProcedureName);
		Except
			Cancel = True;
			Info = ErrorInfo();
			ShowErrorInfo(Info);		
		EndTry;
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf GoToNext Then
			
			SetGoToNumber(GoToNumber + 1);
			
			Return;
			
		EndIf;
		
	Else
		
		SetGoToNumber(GoToNumber + 1);
		
		Return;
		
	EndIf;
	
EndProcedure

// Adds new row to the end of current transitions table
//
// Parameters:
//
//  TransitionSequenceNumber (mandatory) - Number. Sequence number of transition that corresponds
//  to the current MainPageName transition step (mandatory) - String. Name of the MainPanel panel page that corresponds
//  to the current number of the NavigationPageName transition (mandatory) - String. Name of the NavigationPanel panel
//  page that corresponds to the current HandlerNameOnOpen transition number (optional) - String. Name of the
//  function-processor of the HandlerNameOnGoingNext assistant current page open event (optional) - String. Name of the function-processor of the HandlerNameOnGoingBack
//  transition to the next assistant page event (optional) - String. Name of the function-processor of the LongAction
//  transition to assistant previous page event (optional) - Boolean. Shows displayed long operation page.
//  True - long operation page is displayed; False - show normal page. Value by default - False.
// 
&AtClient
Procedure GoToTableNewRow(GoToNumber,
									MainPageName,
									NavigationPageName,
									DecorationPageName = "",
									OnOpenHandlerName = "",
									GoNextHandlerName = "",
									GoBackHandlerName = "",
									LongAction = False,
									LongOperationHandlerName = "")
	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber			= GoToNumber;
	NewRow.MainPageName     	= MainPageName;
	NewRow.DecorationPageName	= DecorationPageName;
	NewRow.NavigationPageName	= NavigationPageName;
	
	NewRow.GoNextHandlerName = GoNextHandlerName;
	NewRow.GoBackHandlerName = GoBackHandlerName;
	NewRow.OnOpenHandlerName = OnOpenHandlerName;
	
	NewRow.LongAction = LongAction;
	NewRow.LongOperationHandlerName = LongOperationHandlerName;
	
EndProcedure

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item In FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			
			If FormItemByCommandName <> Undefined Then
				
				Return FormItemByCommandName;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton")
			AND Find(Item.CommandName, CommandName) > 0 Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

#EndRegion

#Region ConnectedTransitionEventHandlers

&AtClient
Procedure FillTableManually()
	
	Parameters.DataLoadSettings.ManualFilling = True;
	ChangeGoToNumber(+1);
	
EndProcedure

// :::PageFileSelection

&AtClient
Function Attachable_PageFileSelection_OnOpen(Cancel, SkipPage, Val IsGoNext)
	
	If NOT IsGoNext Then
		ClearCurrentSettings();	
	EndIf;
	
EndFunction

&AtServer
Procedure ResetColumnNumbersInFieldTree()
	
	FieldTree = GetFromTempStorage(Parameters.DataLoadSettings.FieldsTreeStorageAddress);
	
	For Each FirstLevelRow In FieldTree.Rows Do
		
		FirstLevelRow.ColumnNumber	= 0;
		FirstLevelRow.ColorNumber	= FirstLevelRow.ColorNumberOriginal;
		
		For Each SecondLevelRow In FirstLevelRow.Rows Do
			SecondLevelRow.ColumnNumber	= 0;
			SecondLevelRow.ColorNumber	= SecondLevelRow.ColorNumberOriginal;
		EndDo;
		
	EndDo;
	
	PutToTempStorage(FieldTree, Parameters.DataLoadSettings.FieldsTreeStorageAddress);
	
EndProcedure

&AtServer
Procedure ClearCurrentSettings()
	
	SpreadsheetDocument.Clear();
	SpreadsheetDocumentMessages.Clear();
	
	ResetColumnNumbersInFieldTree()
	
EndProcedure

// :::PageDataImport

&AtClient
Function Attachable_PageDataImport_LongOperationProcessing(Cancel, GoToNext)
	
	GoToNext = True;
	ExecuteDataImportAtServer(GoToNext);
	If Not GoToNext Then
		
		AttachIdleHandler("CheckExecution", 0.1, True);
		
	EndIf;
	
EndFunction

// :::PagesDataCheck

&AtClient
Function Attachable_PagesReceivedData_OnOpen(Cancel, SkipPage, Val IsGoNext)
	Var Errors;
	
	If Not IsGoNext Then
		Return Undefined;
	EndIf;
	
	If SkipPage Then
		Return Undefined;
	EndIf;
	
	If ValueIsFilled(MappingTemplate) Then
		ApplySelectedMappingTemplate();
	EndIf;
	
EndFunction

&AtClient
Function Attachable_PagesDataCheck_OnOpen(Cancel, SkipPage, Val IsGoNext)
	Var Errors;
	
	If Not IsGoNext Then
		
		SkipPage = True;
		Return Undefined;
		
	EndIf;
	
	DenyTransitionNext = False;
	CheckReceivedData(SkipPage, DenyTransitionNext);
	
	If SkipPage Then
		
		Return Undefined;
		
	ElsIf DenyTransitionNext Then
		
		CommonClientServer.SetFormItemProperty(Items, "CommandNext1", "Enabled", False);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_PagesDataCheck_OnGoBack(Cancel)
	
	CommonClientServer.SetFormItemProperty(Items, "CommandNext1", "Enabled", True);
	
EndFunction

// :::PageMatch

&AtClient
Function Attachable_PageMatching_OnOpen(Cancel, SkipPage, Val IsGoNext)
	
	If IsGoNext = True Then
		
		ExportedDataComparison();
		SkipPage = True;
		
	Else
		
		SetRowsFilterByFilterValue();
		SetRowsQuantityDecorationText();
		
		CurrentItem = Items.DataMatchingTable;
		
	EndIf;
	
EndFunction

// :::ImportSettingPage

&AtClient
Function Attachable_PagePreliminarilyTS_OnOpen(Cancel, SkipPage, Val IsGoNext) Export
	
	SetRowsQuantityDecorationTextTS();
	
EndFunction

&AtClient
Function Attachable_PagePreliminaryCatalog_OnOpen(Cancel, SkipPage, Val IsGoNext) Export
	
	ReceivedData	= DataMatchingTable.Count();
	ConsistentData	= DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", True)).Count();
	DataMatched		= DataMatchingTable.FindRows(New Structure("_RowMatched", True)).Count();
	
	Items.DecorationReceivedDataCount.Title 		= ReceivedData;
	Items.DecorationMatchedCountObject.Title 		= DataMatched;
	Items.DecorationUnmatchedRowsCountObject.Title	= ConsistentData - DataMatched;
	Items.DecorationIncorrectRowsCountObjects.Title	= ReceivedData - ConsistentData;
	
EndFunction

&AtClient
Function Attachable_PagePreliminarilyIR_OnOpen(Cancel, SkipPage, Val IsGoNext) Export
	
	ReceivedData 		= DataMatchingTable.Count();
	ConsistentData	= DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", True)).Count();
	DataMatched	= DataMatchingTable.FindRows(New Structure("_RowMatched", True)).Count();
	
	Items.DecorationReceivedDataCountRS.Title	= ReceivedData;
	Items.DecorationMatchedCountIR.Title		= DataMatched;
	Items.DecorationUnmatchedRowsCountIR.Title	= ConsistentData - DataMatched;
	Items.DecorationIncorrectRowsCountIR.Title	= ReceivedData - ConsistentData;
	
EndFunction

&AtClient
Function Attachable_PagePreliminaryChartOfAccounts_OnOpen(Cancel, SkipPage, Val IsGoNext) Export
	
	ReceivedData	= DataMatchingTable.Count();
	ConsistentData	= DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", True)).Count();
	DataMatched		= DataMatchingTable.FindRows(New Structure("_RowMatched", True)).Count();
	
	Items.DecorationReceivedDataCountChA.Title			= ReceivedData;
	Items.DecorationMatchedCountObjectChA.Title			= DataMatched;
	Items.DecorationUnmatchedRowsCountObjectChA.Title	= ConsistentData - DataMatched;
	Items.DecorationIncorrectRowsCountObjectsChA.Title	= ReceivedData - ConsistentData;
	
EndFunction

#EndRegion

#Region TableOfGoToByScript

// Procedure defines scripted transitions table No1.
// To fill transitions table, use TransitionsTableNewRow()procedure
//
&AtClient
Procedure TableOfGoToByScript()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "PageFileSelection",	"NavigationPageStart", , "PageFileSelection_OnOpen");
	GoToTableNewRow(2, "PageDataImport",	"NavigationPageWait",,,,, True, "PageDataImport_LongOperationProcessing");
	GoToTableNewRow(3, "PagesReceivedData",	"NavigationPageContinuation", , "PagesReceivedData_OnOpen");
	GoToTableNewRow(4, "PagesDataCheck",	"NavigationPageContinuation", , "PagesDataCheck_OnOpen", , "PagesDataCheck_OnGoBack");
	GoToTableNewRow(5, "PageMatching",		"NavigationPageContinuation", , "PageMatching_OnOpen");
	
	If Parameters.DataLoadSettings.IsTabularSectionImport
		Or Parameters.DataLoadSettings.IsAccountingEntriesImport Then
		
		GoToTableNewRow(6, "PagePreliminarilyTS", "NavigationPageEnd", , "PagePreliminarilyTS_OnOpen");
		
	ElsIf Parameters.DataLoadSettings.IsCatalogImport Then
		
		GoToTableNewRow(6, "PagePreliminaryCatalog","NavigationPageEnd", , "PagePreliminaryCatalog_OnOpen");
		
	ElsIf Parameters.DataLoadSettings.IsInformationRegisterImport Then
		
		GoToTableNewRow(6, "PagePreliminarilyInformationRegister", "NavigationPageEnd", , "PagePreliminarilyIR_OnOpen");
		
	ElsIf Parameters.DataLoadSettings.IsChartOfAccountsImport Then
		
		GoToTableNewRow(6, "PagePreliminaryChA","NavigationPageEnd", , "PagePreliminaryChartOfAccounts_OnOpen");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Decoration3URLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	If FormattedStringURL = "ImportFromFile" Then	
		
		StandardProcessing							= False;
		Parameters.DataLoadSettings.ManualFilling	= False;
		NotifyDescription 							= New NotifyDescription("SelectExternalFileDataProcessorEnd", ThisObject);
		
		DialogParameters = New Structure;
		DialogParameters.Insert("Mode",				FileDialogMode.Open);
		Filter = NStr("en = 'External sources for importing (*.%1, *.%2, *.%3)|*.%1;*.%2;*.%3|Microsoft Excel Workbook (*.%1)|*.%1|
					|Spreadsheet document (*.%2)|*.%2|Comma Separated Values (*.%3)|*.%3'; 
					|ru = 'Внешние отчеты и обработки (*.%1, *.%2, *.%3)|*.%1;*.%2;*.%3|Книга Microsoft Excel (*.%1)|*.%1|
					|Табличный документ (*.%2)|*.%2|Текст с разделителями (*.%3)|*.%3';
					|pl = 'Zewnętrzne źródła importowania (*.%1, *.%2, *.%3)|*.%1;*.%2;*.%3|Skoroszyt Microsoft Excel Workbook (*.%1)|*.%1|
					|Dokument arkusza kalkulacyjnego (*.%2)|*.%2Wartości oddzielone przecinkami (*.%3)|*.%3';
					|es_ES = 'Fuentes externas para importar (*.%1, *.%2, *.%3)|*.%1;*.%2;*.%3|Microsoft Excel Workbook (*.%1)|*.%1|
					|Documento de la hoja de cálculo (*.%2)|*.%2|Valores Separados de Coma (*.%3)|*.%3';
					|es_CO = 'Fuentes externas para importar (*.%1, *.%2, *.%3)|*.%1;*.%2;*.%3|Microsoft Excel Workbook (*.%1)|*.%1|
					|Documento de la hoja de cálculo (*.%2)|*.%2|Valores Separados de Coma (*.%3)|*.%3';
					|tr = 'İçe aktarılacak dış kaynaklar (*.%1, *.%2, *.%3) | *.%1; *%2 .; *. %3| Microsoft Excel Çalışma Kitabı (*.%1) | *.%1 |
					| Elektronik tablo belgesi (*.%2) | *. %2| Virgülle Ayrılmış Değerler (*%3) .) | *.%3';
					|it = 'Fonti esterne per l''importazione (*.%1, *.%2, *.%3)|*.%1;*.%2;*.%3|Foglio Microsoft Excel (*.%1)|*.%1|
					|Foglio di calcolo (*.%2)|*.%2|Comma Separated Values (*.%3)|*.%3';
					|de = 'Externe Quellen für den Import (*.%1, *.%2, *.%3)|*.%1;*.%2;*.%3|Microsoft Excel-Arbeitsmappe(*.%1)|*.%1|
					|Tabellenkalkulationsdokument (*.%2)|*.%2| Komma-getrennte Werte (*.%3)|*.%3'");
		Filter = StringFunctionsClientServer.SubstituteParametersToString(Filter, "xlsx", "mxl", "csv");
		DialogParameters.Insert("Filter",			Filter);
		DialogParameters.Insert("Multiselect",		False);
		DialogParameters.Insert("Title",			NStr("en = 'Select external file'; ru = 'Выберите файл для загрузки';pl = 'Wybierz plik zewnętrzny';es_ES = 'Selecciona un archivo externo';es_CO = 'Selecciona un archivo externo';tr = 'Harici dosya seç';it = 'Selezionare i file esterni';de = 'Wählen Sie eine externe Datei'"));
		DialogParameters.Insert("CheckFileExist",	True);
		
		StandardSubsystemsClient.ShowPutFile(NotifyDescription, UUID, "", DialogParameters);
		
	ElsIf FormattedStringURL = "PasteCopiedData" Then
		
		StandardProcessing = False;
		FillTableManually();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "DataImportFromExternalSourcesClientOverridable_SetGoToNumber_6" Then
	
		SetGoToNumber(6);
	
	EndIf;
	
EndProcedure

#EndRegion
