#Region Public

// Returns description of columns of the tabular section or value table.
//
// Parameters:
//  Table - String, ValuesTable - a table with columns. To receive a column list of the tabular 
//            section, specify its full name as a string, as in metadata, for example "Documents.ProformaInvoice.TabularSections.Goods".
//  Columns - String - a list of comma-separated extracted columns. For example, "Number, Goods, and Quantity".
// 
// Returns:
//  Array - a structure with column description for a template. See ImportDataFromFileClientServer. TemplateColumnDetails.
//
Function GenerateColumnDetails(Table, Columns = Undefined) Export
	
	DontExtractAllColumns = False;
	If Columns <> Undefined Then
		ColumnsListForExtraction = StrSplit(Columns, ",", False);
		DontExtractAllColumns = True;
	EndIf;
	
	ColumnsList = New Array;
	If TypeOf(Table) = Type("FormDataCollection") Then
		TableCopy = Table;
		InternalTable = TableCopy.Unload();
		InternalTable.Columns.Delete("SourceLineNumber");
		InternalTable.Columns.Delete("LineNumber");
	Else
		InternalTable= Table;
	EndIf;
	
	If TypeOf(InternalTable) = Type("ValueTable") Then
		For each Column In InternalTable.Columns Do
			If DontExtractAllColumns AND ColumnsListForExtraction.Find(Column.Name) = Undefined Then
				Continue;
			EndIf;
			NewColumn = ImportDataFromFileClientServer.TemplateColumnDetails(Column.Name, Column.ValueType, Column.Title, Column.Width);
			ColumnsList.Add(NewColumn);
		EndDo;
	ElsIf TypeOf(InternalTable) = Type("String") Then
		Object = Metadata.FindByFullName(InternalTable);
		For each Column In Object.Attributes Do
			If DontExtractAllColumns AND ColumnsListForExtraction.Find(Column.Name) = Undefined Then
				Continue;
			EndIf;
			NewColumn = ImportDataFromFileClientServer.TemplateColumnDetails(Column.Name, Column.Type, Column.Presentation());
			NewColumn.ToolTip = Column.ToolTip;
			NewColumn.Width = 30;
			ColumnsList.Add(NewColumn);
		EndDo;
	EndIf;
	Return ColumnsList;
EndFunction

#EndRegion

#Region Private

Procedure AddStatisticalInformation(OperationName, Value = 1, Comment = "") Export
	
	If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		ModuleMonitoringCenter = Common.CommonModule("MonitoringCenter");
		OperationName = "ImportDataFromFile." + OperationName;
		ModuleMonitoringCenter.WriteBusinessStatisticsOperation(OperationName, Value, Comment);
	EndIf;
	
EndProcedure

// Deletes a temporary file.
// If an error occurs while deleting, it is ignored, and the file will be deleted later.
//
Procedure DeleteTempFile(FullFileName) Export
	
	If IsBlankString(FullFileName) Then
		Return;
	EndIf;
		
	Try
		DeleteFiles(FullFileName)
	Except
		WriteLogEvent(EventLogEvent(), EventLogLevel.Warning,
			,, StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не удалось удалить временный файл
			|%1 по причине: %2'; 
			|en = 'Cannot delete temporary file:
			|%1. Reason: %2'; 
			|pl = 'Nie udało się usunąć plik tymczasowy
			|%1 z powodu: %2';
			|es_ES = 'No se ha podido eliminar el archivo temporal
			|%1 a causa de: %2';
			|es_CO = 'No se ha podido eliminar el archivo temporal
			|%1 a causa de: %2';
			|tr = 'Geçici dosya 
			|%1 aşağıdaki nedenle silinemedi: %2';
			|it = 'Non è possibile eliminare i file temporanei:
			|%1. Motivo: %2';
			|de = 'Die temporäre Datei
			|%1 konnte aus diesem Grund nicht gelöscht werden: %2'"), FullFileName, BriefErrorDescription(ErrorInfo())));
	EndTry
	
EndProcedure

// Event name to write to the event log.
//
Function EventLogEvent()
	
	Return NStr("ru = 'Загрузка данных из файла'; en = 'Import data from file'; pl = 'Importuj dane z pliku';es_ES = 'Importar los datos del archivo';es_CO = 'Importar los datos del archivo';tr = 'Verileri dosyadan içe aktar';it = 'Importazione dati da file';de = 'Daten aus der Datei importieren'", CommonClientServer.DefaultLanguageCode());
	
EndFunction


#EndRegion
