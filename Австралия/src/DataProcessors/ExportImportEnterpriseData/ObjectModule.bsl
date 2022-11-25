#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region Private

// Prepares the ExchangeComponents structure.
// Parameters:
//   ExchangeDirection - String - Sending or Receiving.
//   ExchangeFormatVersionOnImport - String - a format version to be used on data import.
//
// Returns:
//   Structure - exchange components.
//
Function ExchangeComponents(ExchangeDirection, ExchangeFornatVersionOnImport = "") 
	
	ExchangeComponents = DataExchangeXDTOServer.InitializeExchangeComponents(ExchangeDirection);
	CurrFormatVersion = ?(ExchangeDirection = "Sending", FormatVersion, ExchangeFornatVersionOnImport);
	If ValueIsFilled(ExchangeNode) AND ExchangeDirection = "Sending" Then
		ExchangeComponents.IsExchangeViaExchangePlan = True;
		ExchangeComponents.CorrespondentNode = ExchangeNode;
		ExchangeComponents.ObjectsRegistrationRulesTable = DataExchangeXDTOServer.ObjectsRegistrationRules(ExchangeNode);
		ExchangeComponents.ExchangePlanNodeProperties = DataExchangeXDTOServer.ExchangePlanNodeProperties(ExchangeNode);
	Else
		ExchangeComponents.IsExchangeViaExchangePlan = False;
	EndIf;
	ExchangeComponents.EventLogMessageKey = NStr("ru = 'Перенос данных через буфер обмена'; en = 'Data transfer via clipboard'; pl = 'Transfer danych przez schowek';es_ES = 'Traslado de datos a través de portapapeles';es_CO = 'Traslado de datos a través de portapapeles';tr = 'Pano üzerinden veri aktarma';it = 'Trasferimento dati tramite appunti';de = 'Datentransfer über die Zwischenablage'", CommonClientServer.DefaultLanguageCode());
	ExchangeComponents.ExchangeFormatVersion = CurrFormatVersion;
	ExchangeComponents.XMLSchema = "http://v8.1c.ru/edi/edi_stnd/EnterpriseData/" + CurrFormatVersion;
	
	ExchangeManagerInternal = False;
	If Common.DataSeparationEnabled() Then
		ExchangeManagerInternal = True;
	ElsIf ValueIsFilled(PathToExportExchangeManager)
		Or ValueIsFilled(PathToImportExchangeManager) Then
		Raise
			NStr("ru = 'Внешняя обработка отладки, загружаемая из файла на диске, не поддерживается.'; en = 'External debug data processor imported from the file on disk is not supported.'; pl = 'Zewnętrzny procesor danych importowany z pliku na dysku nie jest obsługiwany.';es_ES = 'Procesamiento externo de depuración, descargado del archivo en el disco, no se admite.';es_CO = 'Procesamiento externo de depuración, descargado del archivo en el disco, no se admite.';tr = 'Diskteki bir dosyadan yüklenen harici hata ayıklama işlemi desteklenmez.';it = 'Il debug esterno dell''elaboratore dati importato dal file su disco non è supportato.';de = 'Externe Debug-Verarbeitung, die aus der Datei auf der Festplatte geladen wird, wird nicht unterstützt.'");
	ElsIf ValueIsFilled(ExchangeNode)
		AND Common.HasObjectAttribute("ExchangeManagerPath", ExchangeNode.Metadata()) Then
		ExchangeManagerPath = Common.ObjectAttributeValue(ExchangeNode, "ExchangeManagerPath");
		If ValueIsFilled(ExchangeManagerPath) Then
			Raise
				NStr("ru = 'Внешняя обработка отладки, загружаемая из файла на диске, не поддерживается.'; en = 'External debug data processor imported from the file on disk is not supported.'; pl = 'Zewnętrzny procesor danych importowany z pliku na dysku nie jest obsługiwany.';es_ES = 'Procesamiento externo de depuración, descargado del archivo en el disco, no se admite.';es_CO = 'Procesamiento externo de depuración, descargado del archivo en el disco, no se admite.';tr = 'Diskteki bir dosyadan yüklenen harici hata ayıklama işlemi desteklenmez.';it = 'Il debug esterno dell''elaboratore dati importato dal file su disco non è supportato.';de = 'Externe Debug-Verarbeitung, die aus der Datei auf der Festplatte geladen wird, wird nicht unterstützt.'");
		Else
			ExchangeManagerInternal = True;
		EndIf;
	Else
		ExchangeManagerInternal = True;
	EndIf;
	If ExchangeManagerInternal Then
		ExchangeFormatVersions = New Map;
		DataExchangeOverridable.OnGetAvailableFormatVersions(ExchangeFormatVersions);
		ExchangeComponents.ExchangeManager = ExchangeFormatVersions.Get(CurrFormatVersion);
		If ExchangeComponents.ExchangeManager = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не поддерживается версия формата обмена: <%1>.'; en = 'Exchange format version is not supported: <%1>.'; pl = 'Nie jest obsługiwana wersja formatu wymiany: <%1>.';es_ES = 'No se admite la versión del formato de cambio: <%1>.';es_CO = 'No se admite la versión del formato de cambio: <%1>.';tr = 'Değişim format sürümü desteklenmiyor: <%1>.';it = 'La versione del formato di scambio non è supportata: <%1>.';de = 'Die Version des Austauschformats wird nicht unterstützt: <%1>.'"), CurrFormatVersion);
		EndIf;
	EndIf;
	
	DataExchangeXDTOServer.InitializeExchangeRulesTables(ExchangeComponents);
	
	If ExchangeComponents.IsExchangeViaExchangePlan Then
		DataExchangeXDTOServer.FillXDTOSettingsStructure(ExchangeComponents);
		DataExchangeXDTOServer.FillSupportedXDTODataObjects(ExchangeComponents);
	EndIf;
	
	Return ExchangeComponents;
	
EndFunction

// Exports data according to the settings.
// Parameters:
//   ParametersStructure - Structure - processing parameters.
//    * ExportLocation - Number - 0 (to a file), 1 (to a text).
//      When started from a background job, the structure contains data for filling in the object attributes.
//
// Returns:
//   String - Address in the temporary storage where the export result is placed.
Function ExportToXMLResult(ParametersStructure, AddressToPlaceResult = Undefined) Export
	
	ExportLocation = ParametersStructure.ExportLocation;
	
	If ParametersStructure.Property("IsBackgroundJob") Then
		FillPropertyValues(ThisObject, ParametersStructure);
	EndIf;
	
	ListExportAddition.Clear();
	FillListOfObjectsToImport();
	
	ExportResult = ExportDataToXML();
	
	If ExportResult.HasErrors Then
		MessageText = NStr("ru = 'В ходе выполнения операции возникли ошибки'; en = 'Errors occurred while executing operations'; pl = 'W trakcie wykonywania operacji wystąpiły błędy';es_ES = 'Al ejecutar la operación se han producido errores';es_CO = 'Al ejecutar la operación se han producido errores';tr = 'İşlemler yürütülürken hatalar oluştu';it = 'Errore durante l''esecuzione delle operazioni';de = 'Während des Vorgangs sind Fehler aufgetreten'") + ": "
			+ Chars.LF + ExportResult.ErrorText
			+ Chars.LF + NStr("ru = 'Данные могут быть выгружены не полностью.'; en = 'Data can be exported not fully.'; pl = 'Dane mogą nie być wczytane w pełni.';es_ES = 'Los datos pueden ser subidos no completamente.';es_CO = 'Los datos pueden ser subidos no completamente.';tr = 'Veriler tamamen dışa aktarılmamış olabilirler.';it = 'I dati potrebbe essere esportati non completamente.';de = 'Daten werden möglicherweise nicht vollständig exportiert.'");
		CommonClientServer.MessageToUser(MessageText);
	ElsIf Not ExportResult.HasExportedObjects Then
		MessageText = NStr("ru = 'Не найдено ни одного объекта к выгрузке.'; en = 'No object for export is found.'; pl = 'Nie znaleziono ani jednego obiektu do wczytania.';es_ES = 'No se ha encontrado ningún objeto para subir.';es_CO = 'No se ha encontrado ningún objeto para subir.';tr = 'Dışa aktarılacak hiç bir veri bulunamadı.';it = 'Non è stato trovato nessun oggetto da esportare.';de = 'Es wurden keine Objekte zum Exportieren gefunden.'");
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
	If ExportLocation = 0 Then
		// to file
		TX = New TextDocument;
		TX.SetText(ExportResult.ExportText);
		AddressOnServer = GetTempFileName("xml");
		TX.Write(AddressOnServer);
		
		If AddressToPlaceResult = Undefined Then
			StorageAddress = PutToTempStorage(New BinaryData(AddressOnServer));
		Else
			PutToTempStorage(New BinaryData(AddressOnServer), AddressToPlaceResult);
			StorageAddress = AddressToPlaceResult;
		EndIf;
		DeleteFiles(AddressOnServer);
	Else
		// to text
		If AddressToPlaceResult = Undefined Then
			StorageAddress = PutToTempStorage(ExportResult.ExportText);
		Else
			PutToTempStorage(ExportResult.ExportText, AddressToPlaceResult);
			StorageAddress = AddressToPlaceResult;
		EndIf;
	EndIf;
	
	Return StorageAddress;
	
EndFunction

// Exports objects by settings specified in the data processor attributes and returns the export result.
// 
// Returns:
//   - ExportResult - Structure - a structure with the export result.
//      * ImportText - String - an exchange message text.
//      * HasExportedObjects - Boolean - True if at least one object is exported.
//      * HasErrors - Boolean - True if errors occurred during export.
//      * ErrorText - String - an error text on import.
//      * ExportedObjects - Array - an array of exported objects by data processor settings.
//      * ExportedByRefObjects - Array - an array of exported objects by references.
//
Function ExportDataToXML()
	
	ExchangeComponents = ExchangeComponents("Sending");
	
	// Opening the exchange file.
	DataExchangeXDTOServer.OpenExportFile(ExchangeComponents);
	
	HasExportedObjects      = False;
	HasErrorsBeforeConversion = False;
	
	SetPrivilegedMode(True);
	
	Try
		ExchangeComponents.ExchangeManager.BeforeConvert(ExchangeComponents);
	Except
		HasErrorsBeforeConversion = True;
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Событие: %1.
				|Обработчик: BeforeConvert.
				|
				|Ошибка выполнения обработчика.
				|%2.'; 
				|en = 'Event: %1.
				|Handler: BeforeConvert.
				|
				|Handler execution error.
				|%2.'; 
				|pl = 'Wydarzenie: %1.
				|Procedura przetwarzania: BeforeConvert.
				|
				|Błąd wykonywania programu przetwarzania.
				|%2.';
				|es_ES = 'Evento: %1.
				|Procesador: BeforeConvert.
				|
				|Error de ejecutar el procesador.
				|%2.';
				|es_CO = 'Evento: %1.
				|Procesador: BeforeConvert.
				|
				|Error de ejecutar el procesador.
				|%2.';
				|tr = 'Olay: %1.
				|İşleyici: BeforeConvert.
				|
				|İşleyici yürütme hatası.
				|%2.';
				|it = 'Evento: %1.
				|Gestore: BeforeConvert.
				|
				|Errore esecuzione gestore.
				|%2.';
				|de = 'Veranstaltung: %1.
				|Handler: VorDerKonvertierung.
				|
				|Fehler bei der Ausführung des Handlers.
				|%2.'"),
			ExchangeComponents.ExchangeDirection,
			DetailErrorDescription(ErrorInfo()));
		DataExchangeXDTOServer.WriteToExecutionProtocol(ExchangeComponents, ErrorText);
	EndTry;
	
	If ValueIsFilled(ExchangeNode)
		AND Not HasErrorsBeforeConversion Then
		
		ExchangePlanComposition = ExchangeNode.Metadata().Content;
		
		// Inner join with the main table is required to exclude dead reference export.
		QueryText =
		"SELECT 
		|	ChangesTable.Ref
		|FROM 
		|	#FullName#.Changes AS ChangesTable
		|		INNER JOIN #FullName# AS MainTable
		|		ON MainTable.Ref = ChangesTable.Ref
		|WHERE ChangesTable.Node = &Node";
		
		Query = New Query;
		Query.SetParameter("Node", ExchangeNode);
		
		For Each CompositionItem In ExchangePlanComposition Do
			If Not Common.IsRefTypeObject(CompositionItem.Metadata) Then
				Continue;
			EndIf;
			FullObjectName = CompositionItem.Metadata.FullName();
			ProcessingRule = ExchangeComponents.DataProcessingRules.Find(CompositionItem.Metadata, "SelectionObjectMetadata");
			If ProcessingRule = Undefined Then
				Continue;
			EndIf;
			
			Query.Text = StrReplace(QueryText, "#FullName#", FullObjectName);
			
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				DataExchangeXDTOServer.ExportSelectionObject(ExchangeComponents, Selection.Ref.GetObject(), ProcessingRule);
				HasExportedObjects = HasExportedObjects Or Not ExchangeComponents.ErrorFlag;
			EndDo;
		EndDo;
	EndIf;
	
	If ListExportAddition.Count() > 0 Then
		For Each ListItem In ListExportAddition Do
			ExportRef = ListItem.Value;
			ExportRefMetadata = ExportRef.Metadata();
			ProcessingRule = ExchangeComponents.DataProcessingRules.Find(ExportRefMetadata, "SelectionObjectMetadata");
			If ProcessingRule = Undefined Then
				Continue;
			EndIf;
			If Common.IsRefTypeObject(ExportRefMetadata) Then
				ObjectForExport = ExportRef.GetObject();
			Else
				ObjectForExport = ExportRef;
			EndIf;
			DataExchangeXDTOServer.ExportSelectionObject(ExchangeComponents, ObjectForExport, ProcessingRule);
			HasExportedObjects = True;
		EndDo;
	EndIf;
	
	If Not HasErrorsBeforeConversion Then
		Try
			ExchangeComponents.ExchangeManager.AfterConvert(ExchangeComponents);
		Except
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Событие: %1.
					|Обработчик: AfterConvert.
					|
					|Ошибка выполнения обработчика.
					|%2.'; 
					|en = 'Event: %1.
					|Handler: AfterConvert.
					|
					|Error running handler.
					|%2.'; 
					|pl = 'Wydarzenie: %1.
					|Handler: AfterConvert.
					|
					|Błąd wykonania programu przetwarzania.
					|%2.';
					|es_ES = 'Evento: %1.
					|Procesador: AfterConvert.
					|
					|Error de ejecutar el procesador.
					|%2.';
					|es_CO = 'Evento: %1.
					|Procesador: AfterConvert.
					|
					|Error de ejecutar el procesador.
					|%2.';
					|tr = 'Olay: %1.
					|İşleyici: AfterConvert.
					|
					|İşleyici çalışma hatası.
					|%2.';
					|it = 'Evento: %1.
					|Gestore: AfterConvert.
					|
					|Errore avvio gestore.
					|%2.';
					|de = 'Ereignis: %1.
					|Handler: AfterConvert.
					|
					|Fehler beim Ausführen des Handlers.
					|%2.'"),
				ExchangeComponents.ExchangeDirection,
				DetailErrorDescription(ErrorInfo()));
			DataExchangeXDTOServer.WriteToExecutionProtocol(ExchangeComponents, ErrorText);
		EndTry;
	EndIf;
	
	SetPrivilegedMode(False);
	
	ExchangeComponents.ExchangeFile.WriteEndElement(); // Body
	ExchangeComponents.ExchangeFile.WriteEndElement(); // Message
	
	ExportText = ExchangeComponents.ExchangeFile.Close();
	
	ExportResult = New Structure;
	ExportResult.Insert("ExportText",              ExportText);
	ExportResult.Insert("HasExportedObjects",     HasExportedObjects);
	ExportResult.Insert("HasErrors",                 ExchangeComponents.ErrorFlag);
	ExportResult.Insert("ErrorText",                ExchangeComponents.ErrorMessageString);
	ExportResult.Insert("ExportedObjects",         ExchangeComponents.ExportedObjects);
	ExportResult.Insert("ExportedByRefObjects", ExchangeComponents.ExportedByRefObjects);
	
	Return ExportResult;
	
EndFunction

// Imports a message.
// Parameters:
//   ParametersStructure - Structure
//    * XMLText - String - a message to export (on export from the text).
//    * AddressOnServer - String - A name of temporary file with export data (on export from the file)
//   ResultAddress - String - Address of the result on start from the background job.
Procedure MessageImport(ParametersStructure, ResultAddress) Export
	
	If ParametersStructure.Property("IsBackgroundJob") Then
		FillPropertyValues(ThisObject, ParametersStructure);
	EndIf;
	
	XMLReader = New XMLReader;
	AddressOnServer = "";
	If ParametersStructure.Property("AddressOnServer") Then
		XMLReader.OpenFile(ParametersStructure.AddressOnServer);
	Else
		XMLReader.SetString(ParametersStructure.XMLText);
	EndIf;
	
	ImportResult = ImportDataFromXML(XMLReader);
	
	XMLReader.Close();
	
	If ValueIsFilled(AddressOnServer) Then
		DeleteFiles(AddressOnServer);
	EndIf;
	
	If ImportResult.HasErrors Then
		Raise ImportResult.ErrorText;
	EndIf;

EndProcedure

// Imports data from the exchange message.
//
// Parameters:
//  XMLReader	 - XMLReader - the XMLReader object initialized by the exchange message.
// 
// Returns:
//   Structure - an import result.
//    * HasErrors - Boolean - a flag showing that errors occurred while importing the exchange message.
//    * ErrorText - String - an error message text.
//    * ImportedObjects - Array - an imported objects array.
//
Function ImportDataFromXML(XMLReader)
	
	ImportResult = New Structure;
	ImportResult.Insert("HasErrors", False);
	ImportResult.Insert("ErrorText", "");
	ImportResult.Insert("ImportedObjects", New Array);
	
	XMLReader.Read(); // Message
	XMLReader.Read(); // Header
	Header = XDTOFactory.ReadXML(XMLReader, XDTOFactory.Type("http://www.1c.ru/SSL/Exchange/Message", "Header"));
	If XMLReader.NodeType <> XMLNodeType.StartElement
		Or XMLReader.LocalName <> "Body" Then
		
		ImportResult.HasErrors = True;
		ImportResult.ErrorText = NStr("ru='Ошибка чтения сообщения загрузки. Неверный формат сообщения.'; en = 'An error occurred while reading import message. Incorrect message format.'; pl = 'Błąd odczytu wiadomości do pobrania. Nieprawidłowy format wiadomości.';es_ES = 'Error de leer el mensaje de descarga. Formato de mensaje incorrecto.';es_CO = 'Error de leer el mensaje de descarga. Formato de mensaje incorrecto.';tr = 'Yükleme iletisi okuma hatası. Yanlış ileti biçimi.';it = 'Errore durante la lettura del messaggio di importazione. Formato messaggio non valido.';de = 'Fehler beim Lesen der Upload-Meldung. Das Nachrichtenformat ist falsch.'");
		
		Return ImportResult;
	EndIf;
	
	ExchangeFormat = ParseExchangeFormat(Header.Format);
	FormatVersionForImport = ExchangeFormat.Version;
	ExchangeComponents = ExchangeComponents("Get", FormatVersionForImport);
	ExchangeComponents.XMLSchema = Header.Format;
	
	XMLReader.Read(); // Body
	ExchangeComponents.Insert("ExchangeFile", XMLReader);
	
	SetPrivilegedMode(True);
	DataExchangeInternal.DisableAccessKeysUpdate(True);
	DataExchangeXDTOServer.ReadData(ExchangeComponents);
	DataExchangeInternal.DisableAccessKeysUpdate(False);
	SetPrivilegedMode(False);
	
	If ExchangeComponents.ErrorFlag Then
		ImportResult.HasErrors = True;
		ImportResult.ErrorText = ExchangeComponents.ErrorMessageString;
	EndIf;
	
	ImportResult.ImportedObjects = ExchangeComponents.ImportedObjects.UnloadColumn("ObjectRef");
	
	Return ImportResult;
	
EndFunction

// Fills the list of the metadata objects available to export according to exchange components.
Procedure FillExportRules() Export
	ExchangeComponents = ExchangeComponents("Sending");
	ExportRuleTable.Rows.Clear();
	TreeNodeCatalogs = ExportRuleTable.Rows.Add();
	TreeNodeCatalogs.IsFolder = True;
	TreeNodeCatalogs.Description = NStr("ru='Справочники'; en = 'Catalogs'; pl = 'Katalogi';es_ES = 'Catálogos';es_CO = 'Catálogos';tr = 'Ana kayıtlar';it = 'Anagrafiche';de = 'Kataloge'");
	
	TreeNodeDocuments = ExportRuleTable.Rows.Add();
	TreeNodeDocuments.IsFolder = True;
	TreeNodeDocuments.Description = NStr("ru='Документы'; en = 'Documents'; pl = 'Dokumenty';es_ES = 'Documentos';es_CO = 'Documentos';tr = 'Belgeler';it = 'Documenti';de = 'Dokumente'");

	CCTTreeNode = ExportRuleTable.Rows.Add();
	CCTTreeNode.IsFolder = True;
	CCTTreeNode.Description = NStr("ru='Планы видов характеристик'; en = 'Charts of characteristic types'; pl = 'Plany rodzajów charakterystyk';es_ES = 'Diagramas de los tipos de características';es_CO = 'Diagramas de los tipos de características';tr = 'Özellik türü listeleri';it = 'Grafici di tipi caratteristiche';de = 'Diagramme von charakteristischen Typen'");
	
	For Each DPRRow In ExchangeComponents.DataProcessingRules Do
		CurrMetadata = DPRRow.SelectionObjectMetadata;
		If CurrMetadata = Undefined Then
			Continue;
		EndIf;
		
		CurName = CurrMetadata.Name;
		CurrSynonym = CurrMetadata.Synonym;
		FullMDNameAsString = "";
		NewString = Undefined;
		If Metadata.Catalogs.Contains(CurrMetadata) Then
			NewString = TreeNodeCatalogs.Rows.Add();
			FullMDNameAsString = "Catalog." + CurName;
			Presentation = NStr("ru='Справочник %1'; en = 'Catalog %1'; pl = 'Skorowidz %1';es_ES = 'Catálogo %1';es_CO = 'Catálogo %1';tr = 'Katalog %1';it = 'Anagrafica %1';de = 'Verzeichnis %1'");
		ElsIf Metadata.Documents.Contains(CurrMetadata) Then
			NewString = TreeNodeDocuments.Rows.Add();
			FullMDNameAsString = "Document." + CurName;
			Presentation = NStr("ru='Документ %1'; en = 'Document %1'; pl = 'Dokument %1';es_ES = 'Documento %1';es_CO = 'Documento %1';tr = 'Belge %1';it = 'Documento %1';de = 'Dokument %1'");
		ElsIf  Metadata.ChartsOfCharacteristicTypes.Contains(CurrMetadata) Then
			NewString = CCTTreeNode.Rows.Add();
			FullMDNameAsString = "ChartOfCharacteristicTypes." + CurName;
			Presentation = NStr("ru='План видов характеристик %1'; en = 'The %1 chart of characteristic types'; pl = 'Plan rodzajów cech %1';es_ES = 'Plan de tipos de características %1';es_CO = 'Plan de tipos de características %1';tr = 'Özellik türü listesi %1';it = 'Grafico di tipi caratteristica ""%1""';de = 'Plan der Merkmals-Arten %1'");
		Else
			// Export of other metadata objects is not supported.
			Continue;
		EndIf;
		Presentation = StrReplace(Presentation, "%1", CurrSynonym);
		NewString.IsFolder = False;
		NewString.Description = CurrSynonym;
		NewString.FullMetadataName = FullMDNameAsString;
		NewString.Presentation = Presentation;
		StructureFilter = New Structure("FullMetadataName", FullMDNameAsString);
		FilterSettings = AdditionalRegistration.FindRows(StructureFilter);
		NewString.FilterPresentation = "";
		If FilterSettings.Count() > 0 Then
			NewString.Enable = True;
			For Each CurSetting In FilterSettings Do
				If ValueIsFilled(CurSetting.FilterString) Then
					NewString.FilterPresentation = NewString.FilterPresentation + ", "+ TrimAll(CurSetting.FilterString);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	// Removing extra branches.
	If TreeNodeCatalogs.Rows.Count() = 0 Then
		ExportRuleTable.Rows.Delete(TreeNodeCatalogs);
	EndIf;
	If TreeNodeDocuments.Rows.Count() = 0 Then
		ExportRuleTable.Rows.Delete(TreeNodeDocuments);
	EndIf;
	If CCTTreeNode.Rows.Count() = 0 Then
		ExportRuleTable.Rows.Delete(CCTTreeNode);
	EndIf;
EndProcedure

//  Returns a filters composer for a single metadata kind.
//
//  Parameters:
//      FullMetadataName  - String - a table name for filling composer settings. Perhaps there will 
//                                      be IDs for all documents or all catalogs.
//                                      or reference to the group.
//      Presentation        - String - object presentation in the filter.
//      Filter - DataCompositionFilter - a composition filter for filling.
//      SchemaSavingAddress - String, UUID - a temporary storage address for saving the composition 
//                             schema.
//
// Returns:
//      DataCompositionSettingsComposer - an initialized composer.
//
Function SettingsComposerByTableName(FullMetadataName, Presentation = Undefined, Filter = Undefined, SchemaSavingAddress = Undefined) Export
	
	CompositionSchema = New DataCompositionSchema;
	
	Source = CompositionSchema.DataSources.Add();
	Source.Name = "Source";
	Source.DataSourceType = "local";
	
	TablesToAdd = EnlargedMetadataGroupComposition(FullMetadataName);
	
	For Each TableName In TablesToAdd Do
		AddSetToCompositionSchema(CompositionSchema, TableName, Presentation);
	EndDo;
	
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(New DataCompositionAvailableSettingsSource(
		PutToTempStorage(CompositionSchema, SchemaSavingAddress)));
	
	If Filter <> Undefined Then
		AddDataCompositionFilterValues(Composer.Settings.Filter.Items, Filter.Items);
		Composer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	EndIf;
	
	Return Composer;
EndFunction

// Returns a name array of metadata tables according to the FullMetadataName composite parameter type.
//
// Parameters:
//      String, ValueTree - metadata object name (for example Catalog.Currencies), or predefined 
//                            group name (for example AllDocuments), or value tree that describes a 
//                            group
//
// Returns:
//      Array - metadata names.
//
Function EnlargedMetadataGroupComposition(FullMetadataName) 
	MetadataBypass = False;
	CompositionTable = New Array;
	If TypeOf(FullMetadataName) <> Type("String") Then
		// Value tree with filter a group. Root - description, in rows - metadata names.
		For Each GroupString In FullMetadataName.Rows Do
			For Each GroupCompositionRow In GroupString.Rows Do
				CompositionTable.Add(GroupCompositionRow.FullMetadataName);
			EndDo;
		EndDo;
		
	ElsIf FullMetadataName = "AllDocuments" Then
		MetadataBypass = True;
		MetaObjects = Metadata.Documents;
	ElsIf FullMetadataName = "AllCatalogs" Then
		MetadataBypass = True;
		MetaObjects = Metadata.Catalogs;
	ElsIf FullMetadataName = "AllChartsOfCharacteristicTypes" Then
		MetadataBypass = True;
		MetaObjects = Metadata.ChartsOfCharacteristicTypes;
	Else
		// Single metadata table.
		CompositionTable.Add(FullMetadataName);
	EndIf;
	If MetadataBypass Then
		For Each MetaObject In MetaObjects Do
			CompositionTable.Add(MetaObject.FullName());
		EndDo;
	EndIf;
	
	Return CompositionTable;
EndFunction

// Returns period and filter details as string.
//
//  Parameters:
//      Period - StandardPeriod - period for filter details.
//      Filter - DataCompositionFilter - a data composition filter for details.
//      EmptyFilterDetails - String - the function returns this value if an empty filter is passed.
//  Returns:
//   String - filter string presentation.
Function FilterPresentation(Period, Filter, Val EmptyFilterDetails = Undefined) Export
	OurFilter = ?(TypeOf(Filter)=Type("DataCompositionSettingsComposer"), Filter.Settings.Filter, Filter);
	
	PeriodAsString = ?(ValueIsFilled(Period), String(Period), "");
	FilterString  = String(OurFilter);
	
	If IsBlankString(FilterString) Then
		If EmptyFilterDetails=Undefined Then
			FilterString = NStr("ru='Все объекты'; en = 'All objects'; pl = 'Wszystkie obiekty';es_ES = 'Todos objetos';es_CO = 'Todos objetos';tr = 'Tüm nesneler';it = 'Tutti gli oggetti';de = 'Alle Objekte'");
		Else
			FilterString = EmptyFilterDetails;
		EndIf;
	EndIf;
	
	If Not IsBlankString(PeriodAsString) Then
		FilterString =  PeriodAsString + ", " + FilterString;
	EndIf;
	
	Return FilterString;
EndFunction

// Adds a filter to the filter end with possible fields adjustment.
//
//  Parameters:
//      DestinationItems - DataCompositionFilterItemsCollection - a destination.
//      SourceItems - DataCompositionFilterItemsCollection - source.
//      FieldMap - Map - data for fields adjustment.
//                          Key - an initial path to the field data, Value - a path for the result.
//                           For example, to replace type fields.
//                          "Ref.Description" -> "ObjectRef.Description"
//                          pass New Structure("Ref", "ObjectRef").
//
Procedure AddDataCompositionFilterValues(DestinationItems, SourceItems, FieldsMap = Undefined) 
	
	For Each Item In SourceItems Do
		
		Type=TypeOf(Item);
		FilterItem = DestinationItems.Add(Type);
		FillPropertyValues(FilterItem, Item);
		If Type=Type("DataCompositionFilterItemGroup") Then
			AddDataCompositionFilterValues(FilterItem.Items, Item.Items, FieldsMap);
			
		ElsIf FieldsMap<>Undefined Then
			SourceFieldAsString = Item.LeftValue;
			For Each KeyValue In FieldsMap Do
				ControlNew     = Lower(KeyValue.Key);
				ControlLength     = 1 + StrLen(ControlNew);
				SourceControl = Lower(Left(SourceFieldAsString, ControlLength));
				If SourceControl=ControlNew Then
					FilterItem.LeftValue = New DataCompositionField(KeyValue.Value);
					Break;
				ElsIf SourceControl=ControlNew + "." Then
					FilterItem.LeftValue = New DataCompositionField(KeyValue.Value + Mid(SourceFieldAsString, ControlLength));
					Break;
				EndIf;
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Prepares a list of objects to be exported in accordance with the settings.
Procedure FillListOfObjectsToImport() 
	SetPrivilegedMode(True);
	// Objects are processed in batches.
	// Separately - objects without filter settings.
	// Separately - objects with filter settings.
	MetadataArrayWithoutFilters = New Array;
	MetadataArrayFilterByPeriod = New Array;
	For Each Row In AdditionalRegistration Do
		FullMetadataName = Row.FullMetadataName;
		If Row.Filter.Items.Count() = 0 Then
			If Row.SelectPeriod AND ValueIsFilled(AllDocumentsFilterPeriod) Then
				MetadataArrayWithoutFilters.Add(FullMetadataName);
			Else
				MetadataArrayFilterByPeriod.Add(FullMetadataName);
			EndIf;
		Else
			ArrayFilter = New Array;
			ArrayFilter.Add(FullMetadataName);
			AddListOfObjectsToExport(ArrayFilter);
		EndIf;
	EndDo;
	If MetadataArrayWithoutFilters.Count() > 0 Then
		AddListOfObjectsToExport(MetadataArrayWithoutFilters);
	EndIf;
	If MetadataArrayFilterByPeriod.Count() > 0 Then
		AddListOfObjectsToExport(MetadataArrayFilterByPeriod);
	EndIf;
EndProcedure

// Returns an extended object presentation.
// Parameters:
//  ParameterObject - Arbitrary - a string with a full metadata name or a metadata object.
// Returns:
//  String - an object presentation.
//
Function ObjectPresentation(ParameterObject) 
	
	If ParameterObject = Undefined Then
		Return "";
	EndIf;
	ObjectMetadata = ?(TypeOf(ParameterObject) = Type("String"), Metadata.FindByFullName(ParameterObject), ParameterObject);
	
	// There can be no presentation attributes, iterating through structure.
	Presentation = New Structure("ExtendedObjectPresentation, ObjectPresentation");
	FillPropertyValues(Presentation, ObjectMetadata);
	If Not IsBlankString(Presentation.ExtendedObjectPresentation) Then
		Return Presentation.ExtendedObjectPresentation;
	ElsIf Not IsBlankString(Presentation.ObjectPresentation) Then
		Return Presentation.ObjectPresentation;
	EndIf;
	
	Return ObjectMetadata.Presentation();
EndFunction

//  Sets the data sets to the schema and initializes the composer.
//  Is based on attribute values:
//    "AdditionalRegistration", "AllDocumentsFilterPeriod", "AllDocumentsFilterComposer".
//
//  Parameters:
//      MetadataNameList - Array - metadata names (trees of restriction group values, internal IDs
//                                      
//                                      of "All documents" or "All regulatory data") that serve as a basis for the composition schema.
//                                      If it is Undefined, all metadata types from node content are used.
//
//      SchemaSavingAddress - String, UUID - a temporary storage address for saving the composition 
//                             schema.
//
//  Returns:
//      Structure - the following fields:
//         * NodeContentMetadataTable - ValueTable - node content description.
//         * CompositionSchema - CompositionDataSchema - an initialized value.
//         * SettingsComposer - DataCompositionSettingsComposer - an initialized value.
//
Function InitializeComposer(MetadataNameList = Undefined, SchemaSavingAddress = Undefined)
	
	CompositionSchema = GetTemplate("DataCompositionSchema");
	DataSource = CompositionSchema.DataSources[0].Name;

	// Sets for each metadata type included in the exchange.
	SetItemsChanges = CompositionSchema.DataSets.ChangeRegistration.Items;
	While SetItemsChanges.Count() > 1 Do
		// [0] - Field details
		SetItemsChanges.Delete(SetItemsChanges[1]);
	EndDo;
	AdditionalChangeTable = AdditionalRegistration;
		
	// Additional changes
	For Each Row In AdditionalChangeTable Do
		FullMetadataName = Row.FullMetadataName;
		If MetadataNameList <> Undefined Then
			If MetadataNameList.Find(FullMetadataName) = Undefined Then
				Continue;
			EndIf;
		EndIf;
		
		TablesToAdd = EnlargedMetadataGroupComposition(FullMetadataName);
		For Each NameOfTableToAdd In TablesToAdd Do
			SetName = "Additionally_" + StrReplace(NameOfTableToAdd, ".", "_");
			Set = SetItemsChanges.Add(Type("DataCompositionSchemaDataSetQuery"));
			Set.DataSource = DataSource;
			Set.AutoFillAvailableFields = True;
			Set.Name = SetName;
			
			Set.Query = "
				|SELECT ALLOWED
				|	" + SetName + ".Ref           AS ObjectRef,
				|	TYPE(" + NameOfTableToAdd + ") AS ObjectType
				|FROM
				|	" + NameOfTableToAdd + " AS " + SetName + "
				|";
				
			// Adding additional sets to receive data of their filter tabular sections.
			AddingOptions = New Structure;
			AddingOptions.Insert("NameOfTableToAdd", NameOfTableToAdd);
			AddingOptions.Insert("CompositionSchema",       CompositionSchema);
			AddTabularSectionCompositionAdditionalSets(Row.Filter.Items, AddingOptions)
		EndDo;
	EndDo;
	
	// Common parameters
	Parameters = CompositionSchema.Parameters;
	
	SettingsComposer = New DataCompositionSettingsComposer;
	
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(
		PutToTempStorage(CompositionSchema, SchemaSavingAddress)));
	SettingsComposer.LoadSettings(CompositionSchema.DefaultSettings);
	
	If AdditionalChangeTable.Count() > 0 Then 
		
		SettingsRoot = SettingsComposer.Settings;
		
		// Adding additional data filter settings.
		FilterGroup = SettingsRoot.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		FilterGroup.Use = True;
		FilterGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
		
		FilterItems = FilterGroup.Items;
		
		For Each Row In AdditionalChangeTable Do
			FullMetadataName = Row.FullMetadataName;
			If MetadataNameList <> Undefined Then
				If MetadataNameList.Find(FullMetadataName) = Undefined Then
					Continue;
				EndIf;
			EndIf;
			If Row.Filter.Items.Count() = 0
				AND (NOT Row.SelectPeriod OR NOT ValueIsFilled(AllDocumentsFilterPeriod)) Then
				Continue;
			EndIf;
			
			TablesToAdd = EnlargedMetadataGroupComposition(FullMetadataName);
			For Each NameOfTableToAdd In TablesToAdd Do
				
				FilterGroup = FilterItems.Add(Type("DataCompositionFilterItemGroup"));
				FilterGroup.Use = True;
				
				If Row.SelectPeriod OR FullMetadataName = "AllDocuments" Then
					If ValueIsFilled(AllDocumentsFilterPeriod) Then
						StartDate = AllDocumentsFilterPeriod.StartDate;
						EndDate = AllDocumentsFilterPeriod.EndDate;
					Else
						StartDate    = Row.Period.StartDate;
						EndDate = Row.Period.EndDate;
					EndIf;
					If StartDate <> '00010101' Then
						AddFilterItem(FilterGroup.Items, "ObjectRef.Date", DataCompositionComparisonType.GreaterOrEqual, StartDate);
					EndIf;
					If EndDate <> '00010101' Then
						AddFilterItem(FilterGroup.Items, "ObjectRef.Date", DataCompositionComparisonType.LessOrEqual, EndDate);
					EndIf;
					
				EndIf;

				// Adding filter items with field replacement: Ref -> ObjectRef.
				AddingOptions = New Structure;
				AddingOptions.Insert("NameOfTableToAdd", NameOfTableToAdd);
				AddTabularSectionCompositionAdditionalFilters(
					FilterGroup.Items, Row.Filter.Items, SetItemsChanges, 
					AddingOptions);
			EndDo;
		EndDo;
		
	EndIf;
	
	Return New Structure("CompositionSchema,SettingsComposer", 
		CompositionSchema, SettingsComposer);
EndFunction

//  Adds a data set with one Reference field by the table name in the composition schema.
//
//  Parameters:
//      DataCompositionSchema - DataCompositionSchema - a schema being modified.
//      TableName:           - String - a data table name.
//      Presentation:        - String - the Reference field presentation.
//
Procedure AddSetToCompositionSchema(DataCompositionSchema, TableName, Presentation = Undefined)
	
	Set = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	Set.Query = "
		|SELECT 
		|   Ref
		|FROM 
		|   " + TableName + "
		|";
	Set.AutoFillAvailableFields = True;
	Set.DataSource = DataCompositionSchema.DataSources[0].Name;
	Set.Name = "Set" + Format(DataCompositionSchema.DataSets.Count()-1, "NZ=; NG=");
	
	Field = Set.Fields.Add(Type("DataCompositionSchemaDataSetField"));
	Field.Field = "Ref";
	Field.Title = ?(Presentation=Undefined, ObjectPresentation(TableName), Presentation);
	
EndProcedure

//  Adds a single filter item to the list
//
//  Parameters:
//      FilterItems - DataCompositionFilterItem - a reference to the object to check.
//      DataPathField - String - data path of the filter item.
//      ComparisonType - DataCompositionComparisonType - a type of comparison for item to be added.
//      Values - Arbitrary - a comparison value for item to be added.
//      Presentation    -String - optional field presentation.
//      
Procedure AddFilterItem(FilterItems, DataPathField, ComparisonType, Value, Presentation = Undefined)
	
	Item = FilterItems.Add(Type("DataCompositionFilterItem"));
	Item.Use  = True;
	Item.LeftValue  = New DataCompositionField(DataPathField);
	Item.ComparisonType   = ComparisonType;
	Item.RightValue = Value;
	
	If Presentation<>Undefined Then
		Item.Presentation = Presentation;
	EndIf;
EndProcedure

Procedure AddTabularSectionCompositionAdditionalSets(SourceItems, AddingOptions)
	
	NameOfTableToAdd = AddingOptions.NameOfTableToAdd;
	CompositionSchema       = AddingOptions.CompositionSchema;
	
	CommonSet = CompositionSchema.DataSets.ChangeRegistration;
	DataSource = CompositionSchema.DataSources[0].Name; 
	
	ObjectMetadata = Metadata.FindByFullName(NameOfTableToAdd);
	If ObjectMetadata = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru='Некорректное имя метаданных ""%1""'; en = 'Incorrect name of the ""%1"" metadata'; pl = 'Nieprawidłowa nazwa metadanych ""%1""';es_ES = 'Nombre incorrecto de metadatos ""%1""';es_CO = 'Nombre incorrecto de metadatos ""%1""';tr = '""%1"" meta verisinin adı yanlış';it = 'Nome non corretto dei metadati ""%1""';de = 'Falscher Metadatenname ""%1""'"),
				NameOfTableToAdd);
	EndIf;
		
	For Each Item In SourceItems Do
		
		If TypeOf(Item) = Type("DataCompositionFilterItemGroup") Then 
			AddTabularSectionCompositionAdditionalSets(Item.Items, AddingOptions);
			Continue;
		EndIf;
		
		// It is an item, analyzing passed data kind.
		FieldName = Item.LeftValue;
		If StrStartsWith(FieldName, "Ref.") Then
			FieldName = Mid(FieldName, 8);
		ElsIf StrStartsWith(FieldName, "ObjectRef.") Then
			FieldName = Mid(FieldName, 14);
		Else
			Continue;
		EndIf;
			
		Position = StrFind(FieldName, "."); 
		TableName   = Left(FieldName, Position - 1);
		TabularSectionMetadata = ObjectMetadata.TabularSections.Find(TableName);
			
		If Position = 0 Then
			// Filter of header attributes can be retrieved by reference.
			Continue;
		ElsIf TabularSectionMetadata = Undefined Then
			// The tabular section does not match the conditions.
			Continue;
		EndIf;
		
		// The tabular section that matches the conditions
		DataPath = Mid(FieldName, Position + 1);
		If StrStartsWith(DataPath + ".", "Ref.") Then
			// Redirecting to the parent table.
			Continue;
		EndIf;
		
		Alias = StrReplace(NameOfTableToAdd, ".", "") + TableName;
		SetName = "Additionally_" + Alias;
		Set = CommonSet.Items.Find(SetName);
		If Set <> Undefined Then
			Continue;
		EndIf;
		
		Set = CommonSet.Items.Add(Type("DataCompositionSchemaDataSetQuery"));
		Set.AutoFillAvailableFields = True;
		Set.DataSource = DataSource;
		Set.Name = SetName;
		
		AllTabularSectionFields = TabularSectionAttributesForQuery(TabularSectionMetadata, Alias);
		Set.Query = "
			|SELECT ALLOWED
			|	Ref                             AS ObjectRef,
			|	TYPE(" + NameOfTableToAdd + ") AS ObjectType
			|	" + AllTabularSectionFields.QueryFields +  "
			|FROM
			|	" + NameOfTableToAdd + "." + TableName + "
			|";
			
		For Each FieldName In AllTabularSectionFields.FieldsNames Do
			Field = Set.Fields.Find(FieldName);
			If Field = Undefined Then
				Field = Set.Fields.Add(Type("DataCompositionSchemaDataSetField"));
				Field.DataPath = FieldName;
				Field.Field        = FieldName;
			EndIf;
			Field.AttributeUseRestriction.Condition = True;
			Field.AttributeUseRestriction.Field    = True;
			Field.UseRestriction.Condition = True;
			Field.UseRestriction.Field    = True;
		EndDo;
		
	EndDo;
		
EndProcedure

Procedure AddTabularSectionCompositionAdditionalFilters(DestinationItems, SourceItems, SetItems, AddingOptions)
	
	NameOfTableToAdd = AddingOptions.NameOfTableToAdd;
	MetaObject = Metadata.FindByFullName(NameOfTableToAdd);
	
	For Each Item In SourceItems Do
		// The analysis script fragment is similar to the script fragment in the AddTabularSectionCompositionAdditionalSets procedure.
		
		Type = TypeOf(Item);
		If Type = Type("DataCompositionFilterItemGroup") Then
			// Copying filter item
			FilterItem = DestinationItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			
			AddTabularSectionCompositionAdditionalFilters(
				FilterItem.Items, Item.Items, SetItems, 
				AddingOptions);
			Continue;
		EndIf;
		
		// It is an item, analyzing passed data kind.
		FieldName = String(Item.LeftValue);
		If FieldName = "Ref" Then
			FilterItem = DestinationItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue = New DataCompositionField("ObjectRef");
			Continue;
			
		ElsIf StrStartsWith(FieldName, "Ref.") Then
			FieldName = Mid(FieldName, 8);
			
		ElsIf StrStartsWith(FieldName, "ObjectRef.") Then
			FieldName = Mid(FieldName, 14);
			
		Else
			FilterItem = DestinationItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			Continue;
			
		EndIf;
			
		Position = StrFind(FieldName, "."); 
		TableName   = Left(FieldName, Position - 1);
		MetaTabularSection = MetaObject.TabularSections.Find(TableName);
			
		If Position = 0 Then
			// Header attribute filter is retrieved by reference.
			FilterItem = DestinationItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue = New DataCompositionField("ObjectRef." + FieldName);
			Continue;
			
		ElsIf MetaTabularSection = Undefined Then
			// Specified tabular section does not match conditions. Adjusting the filter settings.
			FilterItem = DestinationItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue  = New DataCompositionField("FullMetadataName");
			FilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
			FilterItem.Use  = True;
			FilterItem.RightValue = "";
			
			Continue;
		EndIf;
		
		// Setting up filter for a tabular section
		DataPath = Mid(FieldName, Position + 1);
		If StrStartsWith(DataPath + ".", "Ref.") Then
			// Redirecting to the parent table.
			FilterItem = DestinationItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue = New DataCompositionField("ObjectRef." + Mid(DataPath, 8));
			
		ElsIf DataPath <> "LineNumber" AND DataPath <> "Ref"
			AND MetaTabularSection.Attributes.Find(DataPath) = Undefined Then
			// Tabular section is correct but an attribute does not match conditions Adjusting the filter settings.
			FilterItem = DestinationItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue  = New DataCompositionField("FullMetadataName");
			FilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
			FilterItem.Use  = True;
			FilterItem.RightValue = "";
			
		Else
			// Modifying filter item name
			FilterItem = DestinationItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			DataPath = StrReplace(NameOfTableToAdd + TableName, ".", "") + DataPath;
			FilterItem.LeftValue = New DataCompositionField(DataPath);
		EndIf;
		
	EndDo;
	
EndProcedure

Function TabularSectionAttributesForQuery(Val MetaTabularSection, Val Prefix = "")
	
	QueryFields = ", LineNumber AS " + Prefix + "LineNumber
	              |, Ref      AS " + Prefix + "Ref
	              |";
	
	FieldsNames  = New Array;
	FieldsNames.Add(Prefix + "LineNumber");
	FieldsNames.Add(Prefix + "Ref");
	
	For Each MetaAttribute In MetaTabularSection.Attributes Do
		Name       = MetaAttribute.Name;
		Alias = Prefix + Name;
		QueryFields = QueryFields + ", " + Name + " AS " + Alias + Chars.LF;
		FieldsNames.Add(Alias);
	EndDo;
	
	Return New Structure("QueryFields, FieldsNames", QueryFields, FieldsNames);
EndFunction

Function ParseExchangeFormat(Val ExchangeFormat)
	
	Result = New Structure("BasicFormat, Version");
	
	FormatItems = StrSplit(ExchangeFormat, "/");
	
	If FormatItems.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Неканоническое имя формата обмена <%1>'; en = 'Non-canonical name of the exchange format <%1>'; pl = 'Niekanoniczna nazwa formatu wymiany <%1>';es_ES = 'Nombre no canónico del formato de intercambio <%1>';es_CO = 'Nombre no canónico del formato de intercambio <%1>';tr = 'Değişim biçiminin kurallara uygun olmayan adı <%1>';it = 'Nome non canonico del formato di scambio  <%1>';de = 'Nicht-kanonischer Name des Austauschformats <%1>'"), ExchangeFormat);
	EndIf;
	
	Result.Version = FormatItems[FormatItems.UBound()];
	
	Versions = StrSplit(Result.Version, ".");
	
	If Versions.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Неканоническое представление версии формата обмена: <%1>.'; en = 'Non-canonical presentation of the exchange format version: <%1>.'; pl = 'Niekanoniczna prezentacja wersji formatu wymiany <%1>';es_ES = 'Presentación no canónica de la versión del formato de intercambio: <%1>.';es_CO = 'Presentación no canónica de la versión del formato de intercambio: <%1>.';tr = 'Değişim format sürümünün kanonik olmayan sunumu: <%1>.';it = 'Rappresentazione non canonica della versione di formato dello scambio: <%1>.';de = 'Nicht-kanonische Darstellung der Austausch-Formatversion: <%1>.'"), Result.Version);
	EndIf;
	
	FormatItems.Delete(FormatItems.UBound());
	
	Result.BasicFormat = StrConcat(FormatItems, "/");
	
	Return Result;
EndFunction

Procedure AddListOfObjectsToExport(MetadataArrayFilter)
	CompositionData = InitializeComposer(MetadataArrayFilter);
	
	// Saving filter settings
	FiltersSettings = CompositionData.SettingsComposer.GetSettings();
	
	// Applying the selected option
	CompositionData.SettingsComposer.LoadSettings(
		CompositionData.CompositionSchema.SettingVariants["UserData"].Settings);
	
	// Restoring filter settings
	AddDataCompositionFilterValues(CompositionData.SettingsComposer.Settings.Filter.Items, 
		FiltersSettings.Filter.Items);
	
	ComposerSettings = CompositionData.SettingsComposer.GetSettings();

	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(CompositionData.CompositionSchema, ComposerSettings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	
	Toller = New DataCompositionProcessor;
	Toller.Initialize(Template, , , True);
	
	Output = New DataCompositionResultValueCollectionOutputProcessor;
	Output.SetObject(New ValueTable);
	ResultCollection = Output.Output(Toller);
	For Each SpecificationRow In ResultCollection Do
		If ValueIsFilled(SpecificationRow.ObjectRef) Then
			ListExportAddition.Add(SpecificationRow.ObjectRef);
		EndIf;
	EndDo;
EndProcedure
#EndRegion
#EndIf